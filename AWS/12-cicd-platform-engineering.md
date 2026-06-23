# 05. CI/CD Platform Engineering

> **JD line items covered**
> - Pipeline enablement frameworks and standards
> - Build, test, and deployment automation patterns
> - CI platform reliability and capacity planning

This is the doc you read **after** [11 Jenkins at scale](11-jenkins-at-scale.md) — Jenkins is the *tool*, this doc is the *platform discipline*.

---

## 1. What a CI/CD platform actually delivers

```mermaid
flowchart LR
    subgraph Inputs
      DEV[Developers]
      SRC[(Source repos)]
      STD[Platform standards<br/>shared libs, golden images]
    end
    subgraph Platform
      ENABLE[Pipeline enablement<br/>templates + libraries]
      EXEC[Execution<br/>controller + agents]
      OBS[Observability<br/>build metrics + SLOs]
      GOV[Governance<br/>SBOM + signing + policy]
    end
    subgraph Outputs
      ART[(Registry/Artifact store)]
      DEP[Deployment<br/>K8s / EC2 / Lambda]
      AUD[Audit + compliance]
    end
    DEV --> SRC --> ENABLE --> EXEC --> ART --> DEP
    STD --> ENABLE
    EXEC --> OBS
    EXEC --> GOV --> AUD
    OBS --> ENABLE
```

A platform team's job is **not** to write every team's pipelines. It is to provide:

1. **Paved roads** — shared libraries and templates that handle 80% of needs.
2. **Standards** — what "deployable" means, what must pass before prod.
3. **Operational excellence** — capacity, reliability, security of the CI fabric itself.
4. **Self-service onboarding** — a team can ship a new service in < 1 day.

---

## 2. Pipeline enablement framework — the contract

Define a **deployable artifact contract** that every service must satisfy:

| Stage | Required output |
| --- | --- |
| `lint` | Style, format, secret scan, license scan |
| `unit` | Test report (`junit*.xml`), coverage |
| `build` | OCI image (digest), SBOM (`syft`), license report |
| `scan` | Vulnerabilities (`trivy`), policy gate |
| `sign` | `cosign` signature + attestations |
| `publish` | Push to registry, immutable tag + digest |
| `deploy:dev` | Argo/Helm deploys to dev, runs smoke |
| `deploy:stage` | Same, on green only |
| `deploy:prod` | Manual or progressive (canary/blue-green) |

Anything below that, individual teams may extend. Anything *above* that, platform owns.

```mermaid
flowchart TD
    A[PR opened] --> B[lint + unit]
    B --> C[build + sbom]
    C --> D[scan + policy]
    D --> E{Severity HIGH+ ?}
    E -- yes --> X[Block PR]
    E -- no --> F[sign + publish:rc]
    F --> G[deploy:dev]
    G --> H[smoke + integration]
    H --> I[Merge to main]
    I --> J[deploy:stage]
    J --> K[Performance / soak]
    K --> L[Approval gate]
    L --> M[deploy:prod canary 5%]
    M --> N[SLO + error-budget check]
    N --> O[deploy:prod 100%]
    N --> P[Auto rollback on SLO burn]
```

---

## 3. Shared library — the paved-road implementation (Jenkins example)

Repo layout:
```
shared-library/
├── vars/
│   ├── platformPipeline.groovy
│   ├── platformBuild.groovy
│   ├── platformScan.groovy
│   └── platformDeploy.groovy
├── src/
│   └── com/example/platform/
│       ├── Image.groovy
│       └── Slo.groovy
└── resources/
    └── policies/opa.rego
```

`vars/platformPipeline.groovy`:
```groovy
def call(Map cfg) {
  pipeline {
    agent { kubernetes { yaml libraryResource('agents/default.yaml') } }
    options {
      buildDiscarder(logRotator(numToKeepStr: '50'))
      timeout(time: 60, unit: 'MINUTES')
      timestamps()
      disableConcurrentBuilds()
    }
    environment {
      IMAGE = "${cfg.registry}/${cfg.name}"
      SHA   = "${env.GIT_COMMIT?.take(7)}"
    }
    stages {
      stage('Lint')   { steps { platformLint(cfg) } }
      stage('Unit')   { steps { platformTest(cfg) } }
      stage('Build')  { steps { platformBuild(cfg) } }
      stage('Scan')   { steps { platformScan(cfg) } }
      stage('Sign')   { steps { platformSign(cfg) } }
      stage('Publish'){ steps { platformPublish(cfg) } }
      stage('Deploy: dev')   { when { branch 'main' }; steps { platformDeploy(cfg, 'dev') } }
      stage('Deploy: stage') { when { branch 'main' }; steps { platformDeploy(cfg, 'stage') } }
      stage('Approve prod')  {
        when { branch 'main' }
        steps { input message: "Promote ${IMAGE}:${SHA} to prod?", ok: 'Deploy' }
      }
      stage('Deploy: prod')  { when { branch 'main' }; steps { platformDeploy(cfg, 'prod') } }
    }
    post {
      always  { junit allowEmptyResults: true, testResults: '**/junit*.xml' }
      failure { platformNotify(cfg, 'failure') }
      success { platformNotify(cfg, 'success') }
    }
  }
}
```

Team's `Jenkinsfile` becomes 10 lines:
```groovy
@Library('platform@1.6.0') _
platformPipeline(
  name:     'payments-api',
  registry: 'registry.example.com',
  helmChart:'charts/api',
  slo:      'payments-api-availability',
  owners:   ['payments-sre@example.com']
)
```

---

## 4. Same idea in GitHub Actions / GitLab CI (reusable workflow)

GitHub Actions reusable workflow `.github/workflows/platform-pipeline.yml`:
```yaml
name: platform-pipeline
on:
  workflow_call:
    inputs:
      name:        { required: true,  type: string }
      registry:    { required: true,  type: string }
      helm-chart:  { required: true,  type: string }
      slo:         { required: false, type: string }
jobs:
  ci:
    runs-on: ubuntu-22.04
    permissions:
      contents: read
      id-token: write   # OIDC to AWS, no static keys
      packages: write
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-buildx-action@v3
      - name: Trivy fs scan
        uses: aquasecurity/trivy-action@0.20.0
        with: { scan-type: fs, severity: HIGH,CRITICAL, exit-code: '1' }
      - name: Build & push (digest output)
        id: build
        uses: docker/build-push-action@v6
        with:
          push: true
          tags: ${{ inputs.registry }}/${{ inputs.name }}:${{ github.sha }}
      - name: SBOM
        uses: anchore/sbom-action@v0
        with: { image: ${{ inputs.registry }}/${{ inputs.name }}:${{ github.sha }} }
      - name: Cosign sign
        uses: sigstore/cosign-installer@v3
      - run: cosign sign --yes ${{ inputs.registry }}/${{ inputs.name }}@${{ steps.build.outputs.digest }}
      - name: Helm deploy dev
        run: |
          helm upgrade --install ${{ inputs.name }} ${{ inputs.helm-chart }} \
            -n dev --atomic --timeout 5m \
            --set image.digest=${{ steps.build.outputs.digest }}
```

Team's caller:
```yaml
jobs:
  ci:
    uses: org/platform-workflows/.github/workflows/platform-pipeline.yml@v1.6.0
    with: { name: payments-api, registry: ghcr.io/org, helm-chart: ./charts/api, slo: payments-api-availability }
```

---

## 5. Deployment automation patterns

```mermaid
flowchart LR
    A[Build digest] --> B{Strategy}
    B -- Recreate --> C[stop old + start new]
    B -- Rolling --> D[surge new, retire old]
    B -- Blue/Green --> E[deploy v2 alongside v1, switch DNS/Service]
    B -- Canary --> F[5% -> 25% -> 50% -> 100% with SLO gates]
    B -- Shadow --> G[mirror traffic to v2, don't return its responses]
```

| Pattern | When | Tooling |
| --- | --- | --- |
| Rolling | Stateless web tier, default | K8s `RollingUpdate`, Helm |
| Blue/Green | DB-coupled, fast rollback | Argo Rollouts, ALB target group swap |
| Canary | Progressive rollout with metrics | Argo Rollouts + Datadog/Prometheus checks |
| Shadow | Validate new logic at prod scale | Service mesh (Istio mirror), Diffy |
| Feature flag | Decouple deploy from release | LaunchDarkly, OpenFeature, Unleash |

Argo Rollout (canary) example:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata: { name: api, namespace: payments }
spec:
  replicas: 10
  strategy:
    canary:
      canaryService: api-canary
      stableService: api-stable
      trafficRouting:
        nginx: { stableIngress: api }
      steps:
        - setWeight: 5
        - pause:    { duration: 2m }
        - analysis:
            templates: [{ templateName: success-rate }]
        - setWeight: 25
        - pause:    { duration: 5m }
        - analysis:
            templates: [{ templateName: success-rate }]
        - setWeight: 50
        - pause:    { duration: 5m }
        - setWeight: 100
  selector:    { matchLabels: { app: api } }
  template:    { metadata: { labels: { app: api } }, spec: { containers: [{ name: api, image: registry.example.com/api@sha256:... }] } }
---
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata: { name: success-rate, namespace: payments }
spec:
  metrics:
    - name: success-rate
      interval: 1m
      successCondition: result[0] >= 0.995
      failureLimit: 2
      provider:
        prometheus:
          address: http://prometheus.monitoring:9090
          query: |
            sum(rate(http_requests_total{job="api",code!~"5.."}[1m]))
            / sum(rate(http_requests_total{job="api"}[1m]))
```

---

## 6. Build, test, deploy — the standards

### Build
- **Reproducible:** same source + same digest. Use BuildKit caching, pin base images.
- **Single source of truth for versions:** Git tag → image tag → Helm chart `appVersion`.
- **No "snapshot" tags in prod**, ever.

### Test
- **Test pyramid:** lots of unit, fewer integration, very few E2E.
- **Smoke tests after every deploy** (synthetic + endpoint check).
- **Quality gates fail the build**, not the deploy.

### Deploy
- **Idempotent** — running the deploy twice yields the same state.
- **Atomic** — `helm upgrade --atomic` or `argo rollouts undo`.
- **Auditable** — every deploy ties to a commit, a digest, a deployer identity.

---

## 7. CI platform reliability — SLOs you should run with

| SLO | Target | Why |
| --- | --- | --- |
| Build start latency (queue → agent assigned) | p95 < 60s | Developer productivity |
| Pipeline success rate (excluding test failures) | > 99.5% | Trust in the platform |
| Mean queue length | < 10 | Capacity headroom |
| Plugin/runner CVE remediation | < 14 days | Security |
| Restore-from-backup drill | quarterly success | DR |
| Onboarding time for a new service | < 1 day | Self-service |

Capacity planning loop:
```mermaid
flowchart TD
    A[Track: builds/day, p95 duration, agent pod count] --> B[Compute headroom]
    B --> C{Forecast next quarter}
    C --> D{Above 70% utilization?}
    D -- yes --> E[Raise quota / add node group / shard controller]
    D -- no  --> F[No change, re-check next month]
    E --> G[Validate via load test of pipelines]
    G --> H[Update runbook + SLOs]
```

Useful formulas:
- **Concurrent agents** needed = peak builds × avg duration ÷ work hours.
- **Controller heap** = baseline + ~50 MB per 1k active jobs (rule of thumb; measure).
- **Registry storage** = avg image size × tags retained × services.

---

## 8. CI platform security & supply chain

```mermaid
flowchart LR
    A[Source signed commits + branch protection] --> B[Pinned base images by digest]
    B --> C[SBOM generated per build]
    C --> D[Vulnerability scan with policy gate]
    D --> E[Image signed with cosign keyless OIDC]
    E --> F[Admission controller verifies signatures at deploy]
    F --> G[Audit log: who built, who deployed, what digest]
```

Concrete controls:
- **OIDC to cloud** from CI runners — no static AWS keys.
- **Branch protection** on `main`: required reviews, status checks, signed commits.
- **CODEOWNERS** for `Jenkinsfile`, Helm charts, IaC modules.
- **Allow-listed plugins/actions** only — see [10 Git workflows + governance](10-git-workflows-collaboration.md).
- **SBOM stored alongside image** in registry / OCI artifact.
- **Verify signatures at deploy time** (Kyverno `verifyImages`, sigstore policy controller).

Kyverno verify-image policy:
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata: { name: verify-platform-images }
spec:
  validationFailureAction: Enforce
  rules:
    - name: verify-signatures
      match: { any: [{ resources: { kinds: [Pod] } }] }
      verifyImages:
        - imageReferences: ["registry.example.com/*"]
          attestors:
            - entries:
                - keyless:
                    issuer:  "https://token.actions.githubusercontent.com"
                    subject: "https://github.com/org/*"
```

---

## 9. Observability of the CI platform itself

Always track these — covered fully in [Splunk + Datadog deep dive](../basic/06-splunk-datadog-deep-dive.md):

- **Datadog dashboard:** build duration p50/p95/p99, queue size, agent provisioning latency, success rate by team.
- **Splunk index:** controller logs, audit log, agent JNLP errors.
- **Synthetic build:** a no-op pipeline runs every 5 minutes to detect platform degradation before users do.
- **Alerts:**
  - Build success rate < 99% for 15m → page platform on-call.
  - Queue > 50 for 5m → page platform on-call.
  - Synthetic build duration > 2× baseline → page.

---

## 10. Onboarding workflow (self-service)

```mermaid
flowchart TD
    A[Developer creates new repo from template] --> B[Template includes:<br/>Dockerfile + Jenkinsfile + Helm chart + CODEOWNERS]
    B --> C[Repo webhook registers with Jenkins/Argo]
    C --> D[First pipeline run: lint+test+build+scan]
    D --> E[Auto-create dev namespace + RBAC + secrets]
    E --> F[Service available in service catalog]
    F --> G[Datadog/Splunk auto-discovery enables dashboards + alerts]
    G --> H[< 1 day to first prod deploy]
```

What the template repo provides out of the box:
- Production-grade Dockerfile (see [13 Docker deep dive](13-docker-deep-dive.md)).
- Helm chart with HPA + PDB + NetworkPolicy (see [08 EKS/Docker platform ops](08-eks-docker-platform-ops.md) and the [K8s repo](../../K8s/knowledge/)).
- `Jenkinsfile` calling `platformPipeline()`.
- `CODEOWNERS`, branch protection JSON, PR template.
- README explaining the contract.

---

## 11. What good looks like

- Teams add a new service via a **template + 10-line `Jenkinsfile`**; platform handles the rest.
- Every prod deploy is traceable to **{commit, digest, signature, deployer, change ticket}**.
- The platform itself runs with **published SLOs** and synthetic monitoring.
- **Rollbacks are one command** (or automatic on SLO burn).
- Capacity is planned quarterly; we never page because "Jenkins is full".
- Supply chain is signed, scanned, and verified at admission.

## 12. Anti-patterns

- Every team has its own bespoke `Jenkinsfile` of 500+ lines.
- Deploys are manual scripts in someone's shell history.
- "Snapshot" / `:latest` images deployed to prod.
- No record of what was deployed when, by whom, from what commit.
- Build failures are quietly retried until green.
- CI runs as a privileged service that can write anywhere in cloud.
- Capacity is reactive — pages drive scale-up, not planning.

---

## 13. References

- Continuous Delivery — [continuousdelivery.com](https://continuousdelivery.com/)
- Google "Accelerate" / DORA metrics — [dora.dev](https://dora.dev/)
- SLSA supply chain levels — [slsa.dev](https://slsa.dev/)
- Sigstore — [sigstore.dev](https://www.sigstore.dev/)
- Argo Rollouts — [argo-rollouts.readthedocs.io](https://argo-rollouts.readthedocs.io/)
- GitHub Actions reusable workflows — [docs.github.com/actions/using-workflows/reusing-workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows)
- Companion: [11-jenkins-at-scale.md](11-jenkins-at-scale.md), [10-git-workflows-collaboration.md](10-git-workflows-collaboration.md)

---

## Platform Run Engineering — operating shared services at scale

> JD lines covered: *Operate and maintain key platform services (Terraform Registry, Tracing infrastructure, Quality & Observability resources, docs & chat-support systems). Operate the cloud platform's CI/CD pipelines and reusable workflows used by 300+ developers.*

### 1. What "Run Engineering" actually means

A platform team has **two products**: the tools developers consume, and the **operation of those tools** as 24×7 production services. "Run Engineering" is the discipline of running shared infra like an SRE-owned service.

```mermaid
flowchart TB
    subgraph Tier1[Tier-1 platform services]
      CI[CI/CD platform]
      REG[Terraform Registry]
      TRACE[Tracing backend]
      OBS[Quality + Observability stack]
      DOCS[Docs + chat-support bot]
      ART[Artifact / image registry]
    end
    DEV[300+ developers] --> CI & REG & TRACE & OBS & DOCS & ART
    Tier1 --> SLO[Per-service SLOs + error budgets]
    Tier1 --> ONCALL[Platform on-call rotation]
    Tier1 --> RUNBOOK[Runbooks + synthetic monitors]
    SLO & ONCALL & RUNBOOK --> POST[Postmortems -> roadmap items]
```

Every service in the box on the left gets the same treatment:

| Concern | Implementation |
| --- | --- |
| Ownership | Single owning team listed in service catalog |
| SLOs | Availability + latency + correctness, error budget tracked in Datadog |
| Runbooks | Linked from every alert; quarterly drills |
| Capacity | Quarterly review with growth model |
| Backup / DR | Tested restore at least quarterly |
| Security | Authn = OIDC/SSO; authz = least-privilege; audit log to Splunk |
| Lifecycle | Version pinned, upgrades scheduled, deprecations announced > 90 days ahead |
| Cost | Tagged with `service` + `team`; reviewed monthly |

### 2. SLO templates for common platform services

```yaml
# Terraform Registry
slo: { name: tf-registry-init, target: 99.95, window: 30d }
sli: 'sum:trace.http.request{service:tf-registry,resource:terraform.init,!http.status_code:5*}.as_count() / sum:trace.http.request{service:tf-registry,resource:terraform.init}.as_count()'

# Tracing backend
slo: { name: tracing-ingest, target: 99.9, window: 30d }
sli: '1 - (sum:otel.collector.exporter.send_failed_spans{*}.as_count() / sum:otel.collector.exporter.sent_spans{*}.as_count())'

# CI control plane
slo: { name: ci-queue-latency, target: 99.0, window: 30d }   # p95 < 60s
sli: 'p95:ci.queue.wait_seconds{*}'

# Docs / chat bot
slo: { name: docs-availability, target: 99.9, window: 30d }
sli: '1 - (sum:synthetic.http.error{name:docs-health}.as_count() / sum:synthetic.http.check{name:docs-health}.as_count())'
```

### 3. Synthetic monitoring — detect platform degradation before users do

```yaml
# Datadog synthetic test
name: ci-paved-road-smoke
type: api
subtype: multi
request_definition: |
  1. POST /api/v4/projects/$id/pipeline    # trigger no-op pipeline
  2. GET  /api/v4/projects/$id/pipelines/$pid (poll until status=success, timeout 5m)
assertions:
  - { type: responseTime, operator: lessThan, target: 300000 }
  - { type: body, operator: contains, target: '"status":"success"' }
locations: [aws:us-east-1, aws:eu-west-1]
options: { tick_every: 300, monitor_options: { renotify_interval: 0 } }
```

Same pattern for: `terraform init` against the registry, a span emitted to the tracing backend, a docs search query.

### 4. Scaling reusable workflows to 300+ developers

At 300 developers the platform contract becomes a versioned API. Treat it that way:

```mermaid
flowchart TD
    A[platform-workflows repo] --> B[Versioned tags v1, v2, v3]
    B --> C[Consumers pin to @v1 or @v1.6.0]
    C --> D[Deprecation calendar published 90+ days out]
    D --> E[Linter scans consumers; bumps PRs auto-opened]
    E --> F[Telemetry: usage by version per repo]
    F --> G[Sunset old versions after grace + zero usage]
```

Guardrails:

- **`uses: org/platform-workflows/.github/workflows/x.yml@v1`** — never `@main`.
- **Compatibility shim** when bumping minors so consumers move at their pace.
- **`workflow_dispatch` smoke pipeline** that proves a fresh consumer onboards end-to-end.
- **Per-tenant queues** so a heavy team can't starve everyone else (Jenkins folder quotas, GitHub Actions concurrency groups).
- **Service catalog** lists every service with its owner, on-call, runbook, SLO.

### 5. Developer Experience (DX) — the platform's user metric

DX is what makes 300 developers love or hate the platform. Track it like a product:

| DX signal | How |
| --- | --- |
| Time to first successful pipeline | Sample new repos; target < 1 day |
| Mean PR cycle time | DORA: open → merge → prod |
| Time to provision an environment | Self-service portal timing |
| Quarterly NPS survey | 1-question score + free-text |
| Support ticket volume + resolution time | Categorize by platform area |
| Top 10 "why is my build failing" patterns | Drives docs + paved-road fixes |

### 6. DORA metrics for the platform itself

```mermaid
flowchart LR
    A[Commits + PRs] --> B[Deployment frequency]
    A --> C[Lead time for changes]
    D[Incidents] --> E[Change failure rate]
    D --> F[MTTR]
    B & C & E & F --> G[Weekly platform scorecard]
    G --> H[Roadmap priorities]
```

Query Datadog (or build from CI events + incident records):
```
# Deployment frequency, per service, last 30d
count_not_null(events('source:deploy env:prod').rollup('count', 86400))

# Lead time (PR open -> deploy timestamp), p50/p95
p50:platform.pr.lead_time_seconds{*}.rollup(avg, 86400)
```

### 7. Reducing operational toil systematically

```mermaid
flowchart TD
    A[Track every interrupt: ticket, page, Slack ask] --> B[Bucket by category each week]
    B --> C{Top bucket > 20% of time?}
    C -- yes --> D[Open engineering ticket: automate or remove]
    C -- no --> E[Continue measuring]
    D --> F[Ship fix; close loop with users]
    F --> A
```

Rule of thumb (from the Google SRE Book): keep **toil under 50%** of platform-SRE time. The remaining time funds the roadmap. Publish the ratio monthly.

### 8. What good looks like (Run Engineering)

- Every platform service has an **owner, runbook, SLO, synthetic monitor, on-call** in the catalog.
- Engineers can find any service's status, owner, and last incident in **< 30 s**.
- Reusable workflows are **versioned APIs** with deprecation calendars.
- **DORA + DX scorecards** are published weekly and drive the roadmap.
- **Toil ratio** is measured and below 50%.

### 9. Anti-patterns (Run Engineering)

- Tier-1 service with no SLO, no on-call, no runbook — "if it breaks, somebody Slacks me".
- Consumers stuck on `@main` of reusable workflows; one bad PR breaks 300 builds.
- Roadmap dictated by loudest customer instead of measured pain (DX surveys, toil categorization).
- Platform team measured on raw uptime only; nobody tracks lead time or DX.

### 10. References (Run Engineering + DX)

- Google SRE Workbook — *Eliminating Toil* — [sre.google/workbook/eliminating-toil](https://sre.google/workbook/eliminating-toil/)
- DORA / Accelerate — [dora.dev](https://dora.dev/)
- *Team Topologies* (Skelton & Pais) — [teamtopologies.com](https://teamtopologies.com/)
- Backstage Service Catalog — [backstage.io/docs/features/software-catalog](https://backstage.io/docs/features/software-catalog/)
- Datadog Service Catalog — [docs.datadoghq.com/tracing/service_catalog](https://docs.datadoghq.com/tracing/service_catalog/)
