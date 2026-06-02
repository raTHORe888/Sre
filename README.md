# SRE Learning Repository

> Site Reliability Engineering Knowledge Base — Public resources, best practices, and operational frameworks

---

## Overview

This repository contains SRE (Site Reliability Engineering) learning materials covering fundamentals, incident response, observability, on-call operations, and deployment reliability.

**Important**: All content is derived from **public sources only** — Google SRE Book, industry standards, and general best practices. No proprietary or internal information is included.

---

## Folder Structure

```
sre/
├── README.md (this file)
└── basic/
    ├── README.md (Overview of SRE basics)
    ├── 01-sre-fundamentals.md
    ├── 02-runbooks-incident-response.md
    ├── 03-monitoring-observability.md
    ├── 04-on-call-guide.md
    └── 05-deployment-reliability.md
```

---

## Quick Navigation

### [Basic SRE Concepts](basic/)

Start here to understand SRE fundamentals:

1. **[SRE Fundamentals & Core Concepts](basic/01-sre-fundamentals.md)** — SLO/SLI/error budgets, toil, incident severity
2. **[Runbooks & Incident Response](basic/02-runbooks-incident-response.md)** — Escalation, blameless culture, postmortems
3. **[Monitoring & Observability](basic/03-monitoring-observability.md)** — Metrics, logs, traces, alerting
4. **[On-Call Guide](basic/04-on-call-guide.md)** — Rotations, handoffs, triage, burnout prevention
5. **[Deployment & Reliability](basic/05-deployment-reliability.md)** — Canary, blue-green, feature flags, chaos tests

---

## Content Standards

✅ **What's Included**:
- Public SRE best practices (Google SRE Book, CNCF, industry standards)
- General workflows and decision trees
- Educational examples and templates
- Conceptual diagrams and Mermaid flowcharts

❌ **What's NOT Included**:
- Proprietary company procedures or secrets
- Internal tool names or hardcoded configurations
- Employee names or organizational specifics
- Production credentials or access patterns

---

## Key Topics Covered

| Topic | File | Key Concepts |
|---|---|---|
| Reliability Targets | 01 | SLO, SLI, SLA, error budgets, toil |
| Incident Handling | 02 | Severity levels, escalation, postmortems, blameless culture |
| System Observability | 03 | Golden signals, metrics, logs, traces, alerting |
| On-Call Operations | 04 | Rotation design, handoffs, burnout prevention, triage |
| Safe Deployments | 05 | Canary, blue-green, feature flags, load testing, chaos |

---

## Learning Path

### For New Team Members
1. Start: [SRE Fundamentals](basic/01-sre-fundamentals.md)
2. Then: [Monitoring & Observability](basic/03-monitoring-observability.md)
3. Then: [On-Call Guide](basic/04-on-call-guide.md)
4. Finally: [Incident Response](basic/02-runbooks-incident-response.md) and [Deployments](basic/05-deployment-reliability.md)

### For On-Call Engineers
- Pre-shift: [On-Call Guide](basic/04-on-call-guide.md) (handoff checklist)
- During incident: [Runbooks & Incident Response](basic/02-runbooks-incident-response.md)
- Post-incident: [Monitoring & Observability](basic/03-monitoring-observability.md) (rootcause analysis)

### For Operators & DevOps
- [Monitoring & Observability](basic/03-monitoring-observability.md) — Build dashboards & alerts
- [Deployment & Reliability](basic/05-deployment-reliability.md) — Safe rollouts
- [SRE Fundamentals](basic/01-sre-fundamentals.md) — Understand SLOs

---

## How to Use This Repo

1. **Read through sequentially** or jump to topics of interest
2. **Study the workflows & diagrams** — they illustrate key concepts
3. **Adapt templates** (checklists, postmortem format, runbook structure) to your context
4. **Reference during incidents** — bookmark key pages
5. **Share with your team** — use as onboarding material

---

## Source & Attribution

All content is derived from publicly available sources:
- Google SRE Book (free online)
- CNCF & CISA guidance
- Industry best practices (Incident Command System, etc.)
- Standard SRE conference talks and papers

No proprietary or internal organizational knowledge is included.

---

## Document Safety & Public Source Policy

**Commitment**: Every document in this repo:
- Contains only public knowledge
- Includes general workflows, not internal procedures
- Uses template/example names, not real systems
- Includes educational diagrams (Mermaid flowcharts)
- Never includes credentials, secrets, or hardcoded configs

If you spot anything that violates this policy, please flag it.

---

## Summary

This SRE knowledge base provides a solid foundation in:
- **Reliability culture** (SLOs, error budgets, blameless postmortems)
- **Operational excellence** (monitoring, on-call, incident response)
- **Deployment safety** (canary, blue-green, feature flags, testing)

Use these materials to build and maintain reliable, scalable systems.

---

**Last Updated**: June 2024  
**Status**: Public educational resource  
**License**: Use freely for learning purposes
