# SRE Questions & Answers: Streaming at Scale

> Professional SRE solutions for real-world streaming, K8s, cloud, and Linux challenges.

---

## Overview

This section contains **8 real-world interview/design question sets** on streaming infrastructure, platform engineering, and cloud reliability, with **professional SRE answers/workflows**.

**Context**: All scenarios assume **high-scale streaming** (50M+ concurrent viewers), **multi-region deployment**, and **live event coverage** (sports, entertainment).

---

## Questions

### 1. [Autoscaling 50M+ Concurrent Viewers](01-autoscaling-50m-viewers.md)
**Problem**: Design HPA + Node autoscaling for 50M+ viewers across multiple K8s clusters without over-provisioning.

**Topics**: 
- Multi-cluster orchestration
- HPA metrics (custom, external)
- Node pool strategies
- Cost optimization

---

### 2. [IPL Final: Instant Regional Spinup](02-ipl-final-instant-spinup.md)
**Problem**: During a live event, a new region must spin up in < 5 minutes with zero cold-start impact.

**Topics**:
- Pre-warming strategies
- Deployment velocity
- Readiness gates
- Traffic failover

---

### 3. [Envoy + Istio: Live vs VOD Routing](03-envoy-istio-stream-routing.md)
**Problem**: Route low-latency live streams (10-30s) differently from VOD (buffering OK) without service restarts.

**Topics**:
- Traffic splitting
- Dynamic routing rules
- Timeout/retry tuning
- Hot configuration updates

---

### 4. [Multi-Zone Pod Affinity/Anti-Affinity](04-multi-zone-pod-affinity.md)
**Problem**: Ensure node failure in one zone doesn't impact regional SLA (spread pods, avoid co-location).

**Topics**:
- Pod topology spread
- Zone-aware scheduling
- Failure domain isolation
- SLA preservation

---

### 5. [Monitor HPA Scaling in Real-Time](05-monitor-hpa-scaling.md)
**Problem**: Detect HPA lag, metrics server issues, and scaling decision anomalies live.

**Topics**:
- HPA metrics pipeline
- Metrics server health
- Scaling lag detection
- Observable autoscaling

---

### 6. [Readiness/Liveness Probes for Streaming](06-readiness-liveness-probes.md)
**Problem**: Configure probes to catch buffering, lag, and stream processing failures before users notice.

**Topics**:
- Probe strategy design
- Deep health checks
- Buffering detection
- Probe tuning

---

### 7. [Kube-Proxy Network Rollback Plan](07-kube-proxy-network-rollback.md)
**Problem**: During a live match, a kube-proxy update causes packet drops. Plan rollback to avoid SLA breach.

**Topics**:
- Network observability
- Rapid incident response
- Rollback automation
- Communication planning

---

### 8. [Infra, Kubernetes, and Cloud Patterns (45 mins)](08-infra-kubernetes-cloud-patterns.md)
**Problem Set**: Advanced architecture and operations scenarios across EKS, Kustomize, S3 replication, systemd recovery, lateral movement mitigation, stateful Helm upgrades, hybrid-cloud routing, Terraform state recovery, and Linux troubleshooting.

**Topics**:
- Multi-tenant cluster isolation
- Kustomize overlay strategy
- Secure cross-region replication
- Node-level auto-recovery
- Lateral movement detection/mitigation
- Zero-downtime stateful upgrades
- Hybrid cloud boundaries
- Terraform state recovery
- Bash diagnostics

---

## How to Use

1. **Start with problem statement** — understand the scenario
2. **Review the workflow diagram** — visualize the solution
3. **Read professional approach** — implementation strategy
4. **Study key metrics** — what to monitor
5. **Apply best practices** — lessons from production

---

## Quick Reference: SRE Principles Applied

| Question | Core Principle | Key SRE Practice |
|---|---|---|
| 1 | Embrace Risk | Use error budgets for scaling velocity |
| 2 | Eliminate Toil | Automation + pre-warming |
| 3 | Measure & Monitor | Observable, zero-restart deployments |
| 4 | Reliability Culture | Failure domain isolation |
| 5 | Observability | Metrics pipeline transparency |
| 6 | Proactive Detection | Deep health checks |
| 7 | Blameless Response | Rapid rollback + comms |
| 8 | Platform Reliability | Isolation, recovery, and cross-cloud controls |

---

## Interview Context

These answers are suitable for:
- **SRE hiring interviews** (45 mins, design-focused)
- **On-call incident scenarios** (real-world troubleshooting)
- **Architecture reviews** (production readiness)
- **Technical mentoring** (junior SRE growth)

Each answer demonstrates:
✅ **Technical depth** (concrete implementations)  
✅ **Systems thinking** (tradeoffs, cascading failures)  
✅ **Production experience** (real constraints, edge cases)  
✅ **Communication** (clear problem → solution → metrics)

---

## Learning Path

**For SRE on-call engineers**:
1. Read [Question 7 (Kube-proxy rollback)](07-kube-proxy-network-rollback.md) — incident response
2. Then [Question 5 (HPA monitoring)](05-monitor-hpa-scaling.md) — observability
3. Then [Question 6 (Probes)](06-readiness-liveness-probes.md) — pod health

**For platform engineers**:
1. Start [Question 1 (Autoscaling)](01-autoscaling-50m-viewers.md) — capacity planning
2. Then [Question 2 (Event spinup)](02-ipl-final-instant-spinup.md) — deployment strategy
3. Then [Question 3 (Routing)](03-envoy-istio-stream-routing.md) — traffic management

**For architects**:
1. Read all 7 questions in sequence
2. Focus on tradeoffs and failure modes
3. Adapt to your system's constraints

---

## Key Metrics Dashboard (Across All Questions)

Monitor these metrics together:

```
┌─────────────────────────────────────────────────────────┐
│ Streaming Platform Health (Real-Time)                   │
├─────────────────────────────────────────────────────────┤
│ Concurrent Viewers:    45M / 50M (90% capacity)        │
│ Regional Distribution: APAC 40M | EU 3M | US 2M        │
├─────────────────────────────────────────────────────────┤
│ Latency (live):        p50: 8s | p99: 22s | max: 35s   │
│ Error Rate:            0.02% (< 0.1% SLO)              │
│ Buffer Rate:           < 1% (< 2% SLO)                 │
├─────────────────────────────────────────────────────────┤
│ Pod Count:             1,200 (HPA scaling)              │
│ Node Count:            480 (autoscaled)                 │
│ Pod CPU:               avg 65%, p99 82%                 │
│ Network Egress:        2.3 Tbps (peak)                  │
├─────────────────────────────────────────────────────────┤
│ HPA Scaling Lag:       avg 12s (< 30s target)           │
│ Probe Fail Rate:       0.5% (catch issues early)        │
│ Network Packet Loss:   0 packets (monitored)            │
└─────────────────────────────────────────────────────────┘
```

---

## Summary

These 8 question sets cover:
- **Scalability**: From 50M to 100M+ viewers
- **Reliability**: Survive zone failures, network issues
- **Performance**: Sub-30s latency for live, differentia routing for VOD
- **Observability**: Know what's happening at massive scale
- **Incident Response**: Rapid detection and rollback
- **Platform Patterns**: Multi-tenant isolation, hybrid routing, and IaC recovery

Each answer provides a **production-ready blueprint** that can be adapted to your infrastructure.

---

**Start Reading**: [Question 1: Autoscaling 50M+ Concurrent Viewers](01-autoscaling-50m-viewers.md)
