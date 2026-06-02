# 6. Rolling Deploy — 90-Second Readiness Failure Window

**Difficulty**: ⭐⭐⭐⭐⭐  
**Topics**: CNI IP allocation, NPM programming race, HPA + rolling deploy interaction

---

## Problem

> During a rolling deploy of 200 pods, ~15% fail readiness for 90 seconds before recovering. No app changes. NetworkPolicy unchanged. HPA is scaling simultaneously. What's causing the 90s window?

---

## The Trap

When HPA scales AND a rolling deploy happens simultaneously, the CNI (especially Azure NPM or Calico) can't keep up with IP allocation + policy programming at the rate pods are being created. New pods get IPs but **NetworkPolicy rules aren't programmed yet** — dependency calls (DNS, downstream services) time out → readiness probe fails.

---

## Workflow

```mermaid
flowchart TD
    START["Rolling deploy starts:\n200 pods → replace with new version\nHPA simultaneously scaling:\n200 → 300 pods (traffic spike)"]

    START --> STORM["IP + Policy storm:\nNew pods need:\n1. IP allocated from CNI\n2. iptables rules programmed by NPM\n3. DNS resolves dependencies\n4. Downstream services reachable\nAll at once for 100+ pods"]

    STORM --> NPM_LAG["Azure NPM can't keep up:\n- NPM processes events serially\n- 100 pod events queued\n- Each takes ~1s to program\n- Backlog = 100s lag"]

    NPM_LAG --> POD_FAIL["New pod starts\nTries to connect to Redis/Kafka/DB\niptables rule not yet programmed\nEgress to dependency → DROPPED"]

    POD_FAIL --> READINESS["Readiness probe fails\nPod marked NotReady\nKubernetes removes from LB\nReady after ~90s when NPM catches up"]

    READINESS --> FIX["Fix strategy:\n1. Slow down deploy (maxSurge/maxUnavailable)\n2. Add startup delay\n3. Rate-limit HPA scaleUp\n4. Upgrade NPM version\n5. Use readiness gates"]
```

---

## Root Cause: NPM Event Queue Saturation

```mermaid
sequenceDiagram
    participant HPA as HPA Controller
    participant Deploy as Rolling Deploy
    participant NPM as Azure NPM
    participant Pod as New Pod

    HPA->>NPM: 50 new pod events (scale up)
    Deploy->>NPM: 200 pod events (rolling replace)
    Note over NPM: Queue: 250 events<br/>Processing: 1 event/sec<br/>Backlog: 250 seconds!
    Pod->>Pod: Starts, tries to connect
    Pod->>NPM: Rules not programmed yet
    NPM-->>Pod: iptables DROP (default deny active)
    Note over Pod: Readiness probe fails<br/>Wait 90s for NPM to catch up
    NPM->>Pod: Rules programmed (t=90s)
    Pod->>Pod: Readiness passes
```

---

## Fix 1: Slow Down Rolling Deploy

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fanout-service
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 10        # Only 10 new pods at a time (was 50)
      maxUnavailable: 5   # Only 5 pods down at a time
  # Result: NPM only gets 10-15 events per batch
  # Processes in < 15s; pods ready quickly
```

---

## Fix 2: Add Startup Delay (Init Container)

```yaml
spec:
  initContainers:
  - name: wait-for-cni
    image: busybox:1.35
    command:
    - sh
    - -c
    - |
      echo "Waiting for CNI policy programming..."
      sleep 15
      echo "Checking DNS..."
      until nslookup redis-service.default.svc.cluster.local; do
        echo "DNS not ready yet, waiting..."
        sleep 2
      done
      echo "Network ready"
  containers:
  - name: fanout
    ...
    readinessProbe:
      httpGet:
        path: /ready
        port: 8080
      initialDelaySeconds: 5  # Give app time after init container
```

---

## Fix 3: Rate-Limit HPA Scale-Up During Deploys

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: fanout-hpa
spec:
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Pods
        value: 10        # Max 10 pods per cycle during normal operation
        periodSeconds: 30
      # During deploy: HPA won't fight the rolling deploy
      selectPolicy: Min  # Most conservative policy
    scaleDown:
      stabilizationWindowSeconds: 300
```

---

## Fix 4: Use Readiness Gates (Long-Term)

```yaml
spec:
  readinessGates:
  - conditionType: "networking.azure.com/policy-ready"
  # Pod won't become Ready until CNI signals policy is programmed
  # Requires Azure NPM v1.4+ or custom webhook
```

---

## Monitoring: Detect This Before It Happens

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: deploy-readiness-lag
spec:
  groups:
  - name: deploy
    rules:
    - alert: HighReadinessFailureDuringDeploy
      expr: |
        rate(kubelet_probe_failure_total{probe_type="readiness"}[2m]) > 5
        and on()
        rate(kube_pod_container_status_restarts_total[2m]) > 0
      for: 1m
      annotations:
        summary: "Readiness failures spiking during deploy — possible CNI lag"
        action: "Check NPM queue depth; slow down rolling deploy"
    
    - alert: NPMQueueDepthHigh
      expr: |
        npm_controller_work_queue_depth > 50
      for: 30s
      annotations:
        summary: "NPM queue > 50 events; policy programming lagging"
        action: "Reduce pod creation rate; HPA + deploy overlap"
```

---

## Summary of Timeline

```mermaid
timeline
    title 90-Second Readiness Failure Window
    0s   : Deploy starts
         : HPA also scaling
         : 250 pod events queued to NPM
    0-15s : New pods get IPs
          : NPM still processing queue
          : iptables rules NOT ready
          : Pod egress fails → readiness fails
    15-60s : NPM processes events
           : Rules slowly programmed
           : Some pods recover
    60-90s : All rules programmed
           : All pods pass readiness
    90s+  : Normal — all 300 pods ready
```

---

## Key Takeaway

| Cause | Signal | Fix |
|---|---|---|
| NPM event queue saturation | 90s readiness window, NPM logs show backlog | Reduce `maxSurge` |
| HPA + deploy overlap | Both creating pods simultaneously | Rate-limit HPA during deploys |
| No startup delay | Pod connects before rules active | Init container with delay |
| No readiness gates | App marks ready before network ready | Readiness gate on NetworkPolicy |
