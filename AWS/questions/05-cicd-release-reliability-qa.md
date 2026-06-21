# Q&A: CI/CD and Release Reliability

Pairs with: [05-cicd-release-reliability.md](../05-cicd-release-reliability.md)

> 10 interview-grade questions on CI/CD and safe releases on AWS. All content is from public sources: AWS docs, AWS Well-Architected Framework, and general SRE practice.

---

## Q1. What is the goal of CI/CD in an SRE context, and how does it differ from a generic dev pipeline?
**Answer:**  
- The goal is to **ship changes frequently with low risk**, not just to deploy fast.  
- A generic dev pipeline focuses on build + deploy. An SRE-grade pipeline adds:
  - Pre-deploy safety: tests, security scans, IaC plan review.
  - Progressive rollout: canary or blue-green with health gates.
  - Auto-rollback on SLO regression.
  - Audit trail tied back to a PR.
- Two key DORA metrics it should improve:
  - **Deployment frequency** goes up.
  - **Change failure rate** and **MTTR** go down.

## Q2. What AWS services would you use to build a production CI/CD pipeline, and how do they fit together?
**Answer:**  
- **Source:** AWS CodeCommit or GitHub (via webhook).  
- **Build:** **AWS CodeBuild** for compiling, running unit tests, building Docker images.  
- **Artifact store:** **Amazon ECR** for container images, **Amazon S3** for build artifacts.  
- **Pipeline orchestration:** **AWS CodePipeline** for stages and manual approval gates.  
- **Deploy:** 
  - **AWS CodeDeploy** for EC2, Lambda (with alias traffic shifting), and ECS.
  - **kubectl / Helm / Argo CD** for EKS.  
- **Identity:** Use **GitHub OIDC** or **IAM roles** for short-lived credentials; never long-lived access keys.  
- **Observability:** CloudWatch, CloudTrail, and pipeline notifications via SNS/EventBridge.

## Q3. Explain canary deployments and how you would implement one on AWS.
**Answer:**  
- A **canary** sends a small slice of real traffic (e.g., 5%) to the new version, while the rest stays on the old version.  
- If health metrics (errors, latency, business KPIs) stay healthy for a defined bake time, traffic shifts gradually (e.g., 5% → 25% → 50% → 100%).  
- AWS implementations:
  - **Lambda:** alias traffic shifting (weighted alias), with CodeDeploy `Canary10Percent5Minutes` or similar.
  - **ECS / EKS:** weighted target groups in an **ALB**, or service meshes like App Mesh / Istio for L7 routing.
  - **API Gateway:** canary release deployments shift a percentage of requests to a new stage.
- Pair canaries with **CloudWatch alarms** that auto-abort and rollback if alarms trip.

## Q4. Explain blue-green deployments and when you would choose them over canaries.
**Answer:**  
- **Blue-green** runs two identical production environments. Blue serves live traffic; green is the new version, fully deployed but idle.  
- After validation, traffic flips from blue to green (DNS, ALB target group swap, or service swap).  
- **Pros vs canary:**
  - Instant rollback by flipping back to blue.
  - Easier to test the full new environment end-to-end before traffic flips.
- **Cons vs canary:**
  - Costs more (two environments).
  - Doesn't expose the new version to a slice of real traffic gradually.
- **Choose blue-green** for major, risky releases (database migrations, framework upgrades), or when you need a guaranteed instant rollback. **Choose canary** for frequent app deploys with safe metrics.

## Q5. What is a feature flag, and how does it help release reliability?
**Answer:**  
- A **feature flag** is a runtime switch that turns code paths on or off without redeploying.  
- It decouples **deploy** from **release**: you can deploy code dark and turn it on later for a percentage of users or a specific cohort.  
- Benefits:
  - Instant mitigation: turn off a broken feature without a redeploy.
  - Gradual rollout: 1% → 10% → 50% → 100% by user segment.
  - A/B testing and experimentation.
- AWS option: **AWS AppConfig** with feature flags, plus CloudWatch evaluation.  
- Risk: flag debt. Track flags, set expiry dates, and remove dead flags.

## Q6. How would you design auto-rollback in a production deployment?
**Answer:**  
- Define **deploy success criteria** in advance: error rate < X, p99 latency < Y, no spike in 5xx, no SLO burn.  
- Wire **CloudWatch alarms** to your deploy tool. CodeDeploy supports alarms that automatically abort and rollback.  
- For Kubernetes (EKS), use **Argo Rollouts** or **Flagger** for analysis-based promotion with auto-abort.  
- Key practices:
  - Bake-time between traffic shift steps (e.g., 5 minutes minimum).
  - Compare new version metrics to the old version (not absolute thresholds only).
  - Always rollback first, investigate later.
  - Log the rollback to make postmortem analysis easy.

## Q7. How should CI/CD interact with HPA, Karpenter, and other autoscalers on EKS?
**Answer:**  
- Do not disable HPA during a rollout. The Deployment controller and HPA cooperate during rolling updates.  
- Set sensible **`maxSurge` and `maxUnavailable`** so a rollout doesn't drop below SLO capacity.  
- Use **PodDisruptionBudgets** so voluntary disruptions (drains, rollouts) don't kill too many replicas at once.  
- Validate scaling behavior in **staging with load tests** before prod.  
- For Karpenter: pin the controller version and validate node-launch behavior during deploys, especially with **Spot** capacity.  
- Watch for **HPA flapping** caused by deploy-induced CPU spikes; smooth metrics or use behavior policies.

## Q8. How do you make deployments auditable and traceable for postmortems and compliance?
**Answer:**  
- Every change starts as a **PR**; pipelines only run on merged PRs.  
- Pipelines emit **structured events**: who, what, where, when, commit SHA, artifact digest.  
- Tag every release: container image immutable digest in ECR, Git tag, Helm release revision.  
- Store pipeline logs in **CloudWatch Logs** or S3 with retention aligned to compliance.  
- Use **CloudTrail** to record AWS API actions taken by the pipeline role.  
- During incident postmortems, you should be able to answer "what changed in the last 24 hours" in under a minute.  
- For regulated environments, segregate duties: the person who merges is not the same as the approver of the prod gate.

## Q9. A deployment caused a production regression. Walk me through the response.
**Answer:**  
1. **Rollback first.** Use the pipeline's rollback or `helm rollback` / Argo Rollouts abort. Don't try to forward-fix during impact.  
2. **Communicate.** Open the incident channel, post impact, ETA, current action, next update time.  
3. **Stabilize.** Verify metrics returned to baseline.  
4. **Preserve evidence.** Capture logs, traces, metric screenshots, and the offending diff.  
5. **Diagnose.** Identify root cause and contributing factors after the system is stable.  
6. **Write a blameless postmortem.** Include timeline, impact, what went well, what didn't, and concrete action items.  
7. **Add guardrails.** New test, new alarm, lower canary percent, longer bake time, or a feature flag for the risky path.

## Q10. How does CI/CD interact with automatic scaling and capacity planning?
**Answer:**  
- Pipelines ship not just code but also **autoscaler configs**: HPA, VPA, Karpenter NodePools, ASG launch templates.  
- Treat scaling configuration as **code reviewed in PRs**, with the same plan/approval discipline as the workload itself.  
- Run **load tests in staging** as part of the pipeline for high-traffic services so autoscaling is validated before prod.  
- Capture **post-deploy telemetry**: new version's CPU/memory profile may shift scaling behavior; tune requests/limits and HPA targets accordingly.  
- Tie capacity planning to SLOs: if a service is burning error budget under load, the fix may be more replicas, larger nodes, or shifting to GPU/Spot, all driven by IaC and reviewed via the pipeline.
