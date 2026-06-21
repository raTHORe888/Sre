# Q&A: EKS, Docker, and Platform Operations

Pairs with: [08-eks-docker-platform-ops.md](../08-eks-docker-platform-ops.md)

---

## Q1. What is Amazon EKS, and what does AWS manage versus what you manage?
**Answer:**  
- **Amazon EKS** is AWS's managed Kubernetes service. It runs the **Kubernetes control plane** (API server, etcd, controllers, scheduler) for you across multiple AZs.  
- **AWS manages:** control plane availability, patching, etcd backups, certificate rotation, and the control plane SLA.  
- **You manage:** worker nodes (EC2 or Fargate), node OS updates, add-ons (CNI, CoreDNS, kube-proxy), workloads, RBAC, autoscaling, and observability.  
- EKS integrates with AWS native features: **IAM via IRSA**, **VPC CNI** for native pod networking, **ALB / NLB** via the AWS Load Balancer Controller, **EBS / EFS / FSx** for storage, and **KMS** for secrets encryption.

## Q2. What are managed node groups?
**Answer:**  
EC2 worker nodes managed by EKS. AWS handles provisioning and lifecycle, while you control sizing and config.

## Q3. What is Fargate for EKS?
**Answer:**  
Serverless compute for Kubernetes pods. You define the pod, and AWS runs it without managing EC2 nodes.

## Q4. What is the difference between HPA and VPA?
**Answer:**  
- HPA scales the number of pod replicas based on metrics.  
- VPA adjusts the CPU and memory requests of a pod.  
- They are usually not used together on the same workload.

## Q5. What is Karpenter and why is it useful?
**Answer:**  
A node autoscaler that responds quickly to pending pods. It selects instance types automatically and reduces operational overhead.

## Q6. How does IRSA improve security on EKS?
**Answer:**  
It binds Kubernetes service accounts to IAM roles, removing the need for long-lived AWS credentials in pods.

## Q7. What is a PodDisruptionBudget?
**Answer:**  
A Kubernetes object that limits how many pods of an application can be unavailable during voluntary disruptions, such as node drains.

## Q8. How do you handle stateful workloads on EKS?
**Answer:**  
- Use StatefulSets with stable identities.  
- Use EBS or EFS for durable storage.  
- Plan for backup and restore.  
- Be careful with rolling updates and PVC reuse.

## Q9. What are common EKS production issues?
**Answer:**  
- ImagePullBackOff due to missing pull permissions.  
- Pending pods due to insufficient capacity.  
- Throttling on AWS APIs.  
- Misconfigured ingress and DNS.  
- Misconfigured liveness or readiness probes.

## Q10. How do you run AI inference workloads on EKS?
**Answer:**  
- Use GPU-capable node groups.  
- Define resource requests and limits clearly.  
- Use HPA based on relevant signals.  
- Use Karpenter or Cluster Autoscaler for node scaling.  
- Monitor latency and throughput, not just CPU.
