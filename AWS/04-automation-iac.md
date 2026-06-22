# Automation, IaC, and Runbooks

## What is it?
This topic covers replacing repetitive manual work with code, automation, and repeatable operational steps.

## Why does it matter?
Automation reduces toil, lowers drift, and makes operations safer and faster.

## AWS services to use
- Terraform
- AWS CloudFormation
- AWS Systems Manager Automation
- AWS Lambda
- AWS Step Functions

## Workflow
```mermaid
flowchart TD
    A[Find repetitive task] --> B[Define safe steps]
    B --> C[Implement as code]
    C --> D[Test in staging]
    D --> E[Add logging and guards]
    E --> F[Promote to prod]
    F --> G[Review failures]
    G --> A
```

## Practical steps in AWS
1. Identify tasks done repeatedly during incidents or operations.
2. Turn them into a runbook or an automation script.
3. Test the workflow in staging first.
4. Add approvals if the action is risky.
5. Keep the automation version-controlled in Git.
6. Review failure cases and improve the design.

## Common examples
- Restarting unhealthy services
- Rotating secrets
- Validating backups
- Scaling capacity during spikes
- Running safe configuration changes

## IaC habits
- Prefer declarative infrastructure.
- Separate modules by service or environment.
- Review plans before apply.
- Avoid manual drift.

## What good looks like
- Repeated tasks become predictable and safe.
- Infrastructure changes are auditable.
- Runbooks are easy to execute during incidents.

---

## Automation and Scalability for AI Workloads

### What this covers
- Automating infrastructure tasks for AI services: upgrades, scaling, and provisioning.
- Using Infrastructure as Code with Terraform and Helm.
- Building CI/CD support for automatic scaling and safe change management.

### Why it matters for AI platforms
- AI environments grow fast and need repeatable provisioning.
- Scaling decisions must be reliable, not manual guesses.
- Drift between environments causes hard-to-debug AI incidents.
- IaC keeps platform changes auditable and reversible.

### Automation workflow
```mermaid
flowchart TD
    A[Identify recurring infra task] --> B[Model as Terraform or Helm]
    B --> C[Validate in staging]
    C --> D[Add tests and policy checks]
    D --> E[Promote via CI pipeline]
    E --> F[Apply with logging and approvals]
    F --> G[Monitor outcome]
    G --> H[Refine module and policies]
    H --> A
```

### IaC approach
- Use **Terraform** for VPCs, EKS clusters, IAM, RDS, S3, Lambda, and monitoring stacks.
- Use **Helm** for in-cluster Kubernetes workloads, scaling configs, and platform add-ons.
- Keep modules **small and reusable** per service or environment.
- Run **terraform plan** in CI for every change.
- Use **policy-as-code** tools to block risky changes early.
- Store all IaC in Git with reviews and tags.

### Scaling automation
- Automate **EKS cluster autoscaling** with Karpenter or Cluster Autoscaler.
- Automate **HPA** and **VPA** rules for AI workloads.
- Use **Lambda** or **Step Functions** for event-driven remediation.
- Provision new environments through **Terraform pipelines**, not manual clicks.
- Use **Systems Manager Automation** runbooks for safe operational actions.

### Change management practices
- Every infra change goes through a pull request.
- High-impact changes need approvals and clear rollback steps.
- Pipelines log who applied what, when, and where.
- Drift detection runs regularly against production.

### What good looks like for AI platforms
- New environments are created with a single, reviewed pipeline run.
- Scaling and upgrades are automated and observable.
- Risky changes are blocked or gated before they reach production.
- Engineers spend less time on infrastructure toil and more on reliability.


---

## Shell + Python automation patterns

> This section adds the **JD-aligned automation depth** — *Ability to build automation using Shell, Python, or similar scripting languages* — beyond IaC. Use Shell for glue, Python for anything with state, types, or retries.

### 1. When to reach for Bash vs Python

```mermaid
flowchart TD
    A[Task] --> B{Shape}
    B -- glue: run tools, pipe files --> C[Bash]
    B -- parse JSON/YAML, HTTP, retries --> D[Python]
    B -- long-lived service / API --> D
    B -- fleet-wide repeated change --> E[Ansible]
    B -- infra change --> F[Terraform / CDK]
```

Rule of thumb: if Bash exceeds **300 lines** or uses `eval` / temp files for state, rewrite it in Python.

### 2. Bash — the strict template every script should use

```bash
#!/usr/bin/env bash
# rotate_logs.sh — keep last N days of build logs
# Usage: rotate_logs.sh [-d days] [-r root] [--dry-run]
set -Eeuo pipefail
IFS=$'\n\t'

DAYS=14
ROOT="${LOG_ROOT:-/var/log/builds}"
DRY=false
LOG_TAG="rotate_logs"

log() { logger -t "$LOG_TAG" -- "$*"; printf '%s %s\n' "$(date -Is)" "$*" >&2; }
die() { log "ERROR: $*"; exit "${2:-1}"; }
trap 'die "line $LINENO: $BASH_COMMAND" 1' ERR
trap 'log "received signal; exiting"; exit 130' INT TERM

while (($#)); do
  case "$1" in
    -d|--days)  DAYS="${2:?missing days}"; shift 2 ;;
    -r|--root)  ROOT="${2:?missing root}"; shift 2 ;;
    --dry-run)  DRY=true;                  shift ;;
    -h|--help)  sed -n '2,4p' "$0"; exit 0 ;;
    *) die "unknown arg: $1" 2 ;;
  esac
done

[[ -d $ROOT ]] || die "root not found: $ROOT" 3
[[ "$DAYS" =~ ^[0-9]+$ ]] || die "days must be int" 2

count=0
while IFS= read -r -d '' f; do
  count=$((count + 1))
  $DRY && log "DRY would remove $f" || rm -f -- "$f"
done < <(find "$ROOT" -type f -name 'log' -mtime "+$DAYS" -print0)

log "done: $count files matched"
```

What this gives you:

- `set -Eeuo pipefail` + `trap ... ERR` — fail loud, print the failing line.
- `--dry-run`, `--help`, long-form args, exit codes.
- `find -print0` + `read -d ''` — handles filenames with spaces/newlines.

Lint and test with `shellcheck *.sh` and `bats-core` in CI.

### 3. Python — production scaffold

`pyproject.toml`:

```toml
[project]
name = "platform-tools"
version = "0.4.0"
requires-python = ">=3.11"
dependencies = [
  "click>=8.1",
  "httpx>=0.27",
  "pydantic>=2.7",
  "tenacity>=8.3",
  "kubernetes>=30.1",
  "boto3>=1.34",
  "structlog>=24.1",
]
[project.scripts]
platform-tools = "platform_tools.cli:main"
```

Drain a Kubernetes node, safely, with retries and structured logs:

```python
"""Drain Kubernetes nodes safely, honoring PDBs."""
from __future__ import annotations
import structlog
from kubernetes import client, config
from tenacity import retry, stop_after_attempt, wait_exponential

log = structlog.get_logger(__name__)

def _kube() -> client.CoreV1Api:
    try:
        config.load_incluster_config()
    except config.ConfigException:
        config.load_kube_config()
    return client.CoreV1Api()

@retry(stop=stop_after_attempt(5), wait=wait_exponential(min=1, max=15))
def cordon(node: str) -> None:
    _kube().patch_node(node, {"spec": {"unschedulable": True}})
    log.info("cordoned", node=node)

@retry(stop=stop_after_attempt(3), wait=wait_exponential(min=2, max=30))
def drain(node: str, grace: int = 60, dry_run: bool = False) -> int:
    v1 = _kube()
    pods = v1.list_pod_for_all_namespaces(field_selector=f"spec.nodeName={node}").items
    evicted = 0
    for p in pods:
        if any(o.kind == "DaemonSet" for o in (p.metadata.owner_references or [])):
            continue
        body = client.V1Eviction(
            metadata=client.V1ObjectMeta(name=p.metadata.name, namespace=p.metadata.namespace),
            delete_options=client.V1DeleteOptions(grace_period_seconds=grace),
        )
        if dry_run:
            log.info("would evict", pod=p.metadata.name, ns=p.metadata.namespace)
            continue
        v1.create_namespaced_pod_eviction(name=p.metadata.name, namespace=p.metadata.namespace, body=body)
        evicted += 1
    log.info("drained", node=node, evicted=evicted, dry_run=dry_run)
    return evicted
```

CLI front door using `click`:

```python
import click
from .k8s.drain_nodes import cordon, drain

@click.group()
def main() -> None:
    """Platform SRE automation toolbox."""

@main.command("drain")
@click.argument("node")
@click.option("--grace", default=60, type=int)
@click.option("--dry-run/--apply", default=True)
def drain_cmd(node: str, grace: int, dry_run: bool) -> None:
    cordon(node)
    n = drain(node, grace=grace, dry_run=dry_run)
    click.echo(f"evicted={n}")
```

### 4. Boto3 with retries and paging

```python
import boto3
from botocore.config import Config
from tenacity import retry, wait_exponential, stop_after_attempt

cfg = Config(retries={"max_attempts": 10, "mode": "adaptive"}, region_name="us-east-1")
ec2 = boto3.client("ec2", config=cfg)

@retry(wait=wait_exponential(min=1, max=10), stop=stop_after_attempt(5))
def list_stopped_instances() -> list[str]:
    out: list[str] = []
    for page in ec2.get_paginator("describe_instances").paginate(
        Filters=[{"Name": "instance-state-name", "Values": ["stopped"]}]
    ):
        for r in page["Reservations"]:
            for i in r["Instances"]:
                out.append(i["InstanceId"])
    return out
```

### 5. Promotion workflow — script → platform tool

```mermaid
flowchart LR
    A[Local one-liner in someone's shell history] --> B[Move into a repo]
    B --> C[Add template, shellcheck/ruff, tests]
    C --> D[Add CLI flags, --help, exit codes, --dry-run]
    D --> E[Ship as image / pip wheel from CI]
    E --> F[RBAC + audit log + runbook entry]
```

Discipline: **never let a critical operation live only as someone's shell history.**

### 6. Secrets and observability for your scripts

- Never read secrets via CLI args (`ps aux` shows them) — use env vars, files mounted by the platform, or fetch from SSM/Vault at runtime.
- Mask in logs; never echo a token.
- Treat each script as a tiny service: emit **structured JSON logs**, meaningful **exit codes**, and a **heartbeat ping** to a monitor (Healthchecks.io / Datadog) on success so silence is alarming.

```bash
curl -fsS --retry 3 "https://hc-ping.com/$HEALTHCHECK_UUID" >/dev/null
```

### 7. What good looks like (Shell + Python)

- Every recurring task lives **as a script in Git**, not in shell history.
- Bash scripts pass `shellcheck` and use the strict template.
- Python tools live in **one packaged repo** with type hints, tests, retries, structured logs.
- Critical ops are **wrapped in a CLI/bot** with audit + RBAC; nobody runs raw `aws`/`kubectl` against prod by hand.
- Each tool ships with a **runbook entry**: inputs, outputs, exit codes, rollback.

### 8. Anti-patterns (Shell + Python)

- Bash without `set -e`, swallowing errors silently.
- 1 000-line Bash parsing JSON with `awk` and storing state in temp files.
- Hardcoded creds, tokens passed via CLI args, secrets in `~/.bash_history`.
- `eval` on untrusted input.
- Python "script.py" shipped without `pyproject.toml`, no tests, no retries.
- Tools that print "success" but exit `0` on partial failure.
- No idempotence — running twice doubles the change.

### 9. References (Shell + Python)

- Bash manual — [gnu.org/software/bash/manual](https://www.gnu.org/software/bash/manual/)
- ShellCheck — [shellcheck.net](https://www.shellcheck.net/)
- bats-core — [github.com/bats-core/bats-core](https://github.com/bats-core/bats-core)
- Google Shell Style Guide — [google.github.io/styleguide/shellguide.html](https://google.github.io/styleguide/shellguide.html)
- Python docs — [docs.python.org/3](https://docs.python.org/3/)
- `click` — [click.palletsprojects.com](https://click.palletsprojects.com/)
- `tenacity` — [tenacity.readthedocs.io](https://tenacity.readthedocs.io/)
- `structlog` — [www.structlog.org](https://www.structlog.org/)
