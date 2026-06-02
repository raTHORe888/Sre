# NetworkPolicy — Twisted SRE Questions & Answers

> 10 advanced, production-grade NetworkPolicy scenarios with full workflows, YAML, and triage runbooks.

---

## Questions

| # | File | Core Trap | Difficulty |
|---|---|---|---|
| 1 | [Staging Works, Prod Fails](01-staging-prod-mismatch.md) | Namespace label missing in prod | ⭐⭐⭐ |
| 2 | [Silent Break After New Deploy](02-silent-break-new-deploy.md) | Version label in policy selector changes on deploy | ⭐⭐⭐ |
| 3 | [DNS Black Hole](03-dns-blackhole-egress.md) | Egress deny-all; forgot UDP/53 | ⭐⭐⭐⭐ |
| 4 | [Partial Allow Paradox](04-partial-allow-paradox.md) | Port isolation per namespace; no cross-permission | ⭐⭐⭐⭐ |
| 5 | [Ghost Traffic — Azure NPM](05-ghost-traffic-npm.md) | NPM programming lag window; hostNetwork bypass | ⭐⭐⭐⭐⭐ |
| 6 | [Rolling Deploy Readiness Lag](06-rolling-deploy-readiness-lag.md) | HPA + rolling deploy saturates NPM event queue | ⭐⭐⭐⭐⭐ |
| 7 | [Istio mTLS Probe Conflict](07-istio-mtls-probe-conflict.md) | STRICT mTLS rejects kubelet plain-HTTP probes | ⭐⭐⭐⭐⭐ |
| 8 | [AND vs OR Selector Logic](08-cross-namespace-and-or-logic.md) | One extra `-` changes AND to OR; unintended access | ⭐⭐⭐⭐⭐ |
| 9 | [Silent Egress Escape](09-egress-escape-bypass.md) | hostNetwork / Felix crash / node-local traffic | ⭐⭐⭐⭐⭐ |
| 10 | [IPL Final 3AM Triage](10-ipl-final-3am-triage.md) | Read-only triage: CNI lag + Istio + autoscale race | ⭐⭐⭐⭐⭐ |

---

## Core Concepts Covered

- **AND vs OR** in `namespaceSelector` + `podSelector` YAML structure
- **DNS egress**: UDP/53 vs TCP/53 — the most common mistake
- **Azure NPM** programming lag and race conditions
- **Calico** GlobalNetworkPolicy, Felix health, iptables ordering
- **Istio + NetworkPolicy** dual-layer interaction: mTLS ports, Envoy interception
- **Rolling deploy + HPA** interaction: CNI event queue saturation
- **hostNetwork bypass**: pods that NetworkPolicy cannot control
- **Label stability**: never use `version` in policy selectors
- **Read-only triage**: Portal, Azure Monitor, Network Watcher
