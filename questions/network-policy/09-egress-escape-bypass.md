# 9. Silent Egress Escape — Deny-All Not Working

**Difficulty**: ⭐⭐⭐⭐⭐  
**Topics**: Egress policy bypass, hostNetwork, Calico node, iptables order, DaemonSet

---

## Problem

> You apply a `deny-all` egress policy. Your team swears traffic is still leaving the pod to an external IP. You verify the policy is applied. CNI is Calico. How is egress traffic still escaping — name 3 possible reasons.

---

## The Trap

Kubernetes NetworkPolicy only controls **pod-network traffic**. Several bypass vectors exist at the node, host, and CNI levels.

---

## Workflow

```mermaid
flowchart TD
    DENY["Egress deny-all applied\nPod traffic should be blocked\nTraffic still escaping to external IP"]

    DENY --> CAUSES["3 Bypass Vectors"]

    CAUSES --> B1["Bypass 1:\nhostNetwork: true\nPod uses node IP\nNetworkPolicy doesn't apply"]

    CAUSES --> B2["Bypass 2:\nCalico iptables rule ordering bug\nor GlobalNetworkPolicy missing\niptables ACCEPT before Calico DROP"]

    CAUSES --> B3["Bypass 3:\nNode-local traffic\nPod talks to node itself (169.254.x.x)\nor NodePort service on same node\nbypasses pod-network routing"]

    B1 --> DIAGNOSE1["kubectl get pod -o yaml | grep hostNetwork"]
    B2 --> DIAGNOSE2["kubectl get globalnetworkpolicies\ncalicoctl get policy -A\niptables-save on node | grep CALICO"]
    B3 --> DIAGNOSE3["Check destination IP:\nIs it a node IP or metadata endpoint?\ntraceroute from pod (if available)"]
```

---

## Bypass 1: hostNetwork Pod

```bash
# Check if pod uses host network
kubectl get pod <pod-name> -o yaml | grep -i hostNetwork

# If hostNetwork: true:
# Pod shares the NODE's network namespace
# Uses NODE's IP, not pod IP
# NetworkPolicy doesn't apply — it only controls pod-network interfaces
```

```mermaid
graph LR
    subgraph Node["Node (host network)"]
        N_IF["eth0: 10.1.1.5\n(node IP)"]
        POD["Pod with hostNetwork: true\nUses 10.1.1.5\nNot in pod CIDR"]
    end
    
    POD -->|"Egress via node IP"| INTERNET["External IP 1.2.3.4"]
    POLICY["NetworkPolicy\ndeny-all egress\nfor pod CIDR"]
    POLICY -.->|"Does NOT apply"| POD
    
    style POLICY fill:#ffcccc
```

**Fix**: Don't use `hostNetwork: true` unless absolutely necessary. Use NSG/firewall rules to control host-network pods.

---

## Bypass 2: Calico iptables Rule Ordering / Missing GlobalNetworkPolicy

```bash
# Check if Calico has a GlobalNetworkPolicy
kubectl get globalnetworkpolicies.crd.projectcalico.org -A
# If empty: no global deny; namespace policy may not be enforced at calico tier

# Check iptables order on node (requires node access or debug pod)
# iptables-save | grep -E 'CALICO|cali-' | head -50

# Check if Calico felix is programming rules correctly
kubectl logs -n kube-system -l k8s-app=calico-node -c calico-node --tail=200 | grep -iE "error|program|deny"
```

```mermaid
graph TD
    PKT["Egress packet from pod"]
    PKT --> RAW["iptables RAW table"]
    RAW --> CALICO_PRE["cali-PREROUTING (Calico)"]
    CALICO_PRE --> FORWARD["iptables FORWARD"]
    FORWARD --> CALICO_FWD["cali-FORWARD (Calico)\nCalico DROP rule should be here"]
    CALICO_FWD -->|"Rule missing or delayed"| ACCEPT["ACCEPT — packet escapes!"]
    CALICO_FWD -->|"Rule present"| DROP["DROP — blocked correctly"]
    
    style ACCEPT fill:#ffcccc
    style DROP fill:#ccffcc
```

**Root cause**: Calico programs rules asynchronously. If Felix (Calico agent) crashes or lags, rules are missing and traffic passes through `ACCEPT` by default.

```bash
# Check Calico Felix status
kubectl get pods -n kube-system -l k8s-app=calico-node
kubectl describe pod -n kube-system -l k8s-app=calico-node | grep -A5 "calico-node"

# If Felix crashed/restarting: policy temporarily not enforced
```

---

## Bypass 3: Node-Local Traffic Bypassing Pod Network

```bash
# Traffic to 169.254.169.254 (Azure IMDS) or node IPs
# goes through the NODE's routing table, not pod network
# NetworkPolicy only applies to pod-network (veth) traffic

# Check destination of escaping traffic
kubectl exec <pod> -- cat /proc/net/tcp6  # active connections
kubectl exec <pod> -- ss -tnp             # if available
```

```mermaid
graph LR
    POD["Pod\n10.244.1.5"]
    VETH["veth pair\n(pod network)"]
    BRIDGE["cbr0 / azure bridge"]
    NODE["Node interface\neth0: 10.1.1.5"]
    META["Azure IMDS\n169.254.169.254"]

    POD -->|"NodePort or hostIP traffic\nSkips pod network routing"| NODE
    NODE --> META
    
    POLICY["deny-all egress\napplied to veth"]
    POLICY -.->|"Does not see\nthis path"| NODE
    
    style POLICY fill:#ffcccc
```

**Fix**: Block IMDS/NodePort traffic at NSG level in addition to NetworkPolicy.

---

## Comprehensive Forensic Checklist (No Exec)

```bash
# 1. Verify policy is actually applied
kubectl get networkpolicy -n <namespace> -o yaml

# 2. Verify pod is NOT using hostNetwork
kubectl get pod <pod> -o jsonpath='{.spec.hostNetwork}'

# 3. Check Calico node health
kubectl get pods -n kube-system -l k8s-app=calico-node
kubectl describe pod -n kube-system -l k8s-app=calico-node | grep -E "Ready|Error|OOM"

# 4. Check Calico Felix logs
kubectl logs -n kube-system -l k8s-app=calico-node -c calico-node --tail=300 | \
  grep -iE "error|fail|policy|deny"

# 5. Check GlobalNetworkPolicy existence
kubectl get globalnetworkpolicies.crd.projectcalico.org -A 2>/dev/null || echo "No CRD"

# 6. Use Azure Monitor to see actual traffic (no exec needed)
az monitor log-analytics query \
  --workspace <ws-id> \
  --analytics-query "AzureNetworkAnalytics_CL
    | where SrcIP_s == '<pod-ip>'
    | where FlowStatus_s == 'A'  // Allowed
    | project TimeGenerated, SrcIP_s, DestIP_s, DestPort_d"
```

---

## Key Takeaway

| Bypass Vector | Why Policy Doesn't Apply | Fix |
|---|---|---|
| `hostNetwork: true` | Pod uses node IP, not pod CIDR | Remove hostNetwork; use NSG for host pods |
| Calico Felix crash/lag | Rules temporarily unprogrammed | Monitor Felix health; alert on crashes |
| Node-local / IMDS traffic | Bypasses veth routing | NSG rules to block at node level |
| Missing GlobalNetworkPolicy | Namespace policy alone insufficient | Add Calico GlobalNetworkPolicy default-deny |

> **Rule**: NetworkPolicy controls pod-network traffic only. For anything at the node level, use NSG + Calico GlobalNetworkPolicy.
