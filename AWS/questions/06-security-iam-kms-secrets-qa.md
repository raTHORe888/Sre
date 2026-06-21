# Q&A: Security, IAM, KMS, and Secrets

Pairs with: [06-security-iam-kms-secrets.md](../06-security-iam-kms-secrets.md)

---

## Q1. What is the principle of least privilege?
**Answer:**  
Grant only the permissions needed for a workload or user to perform their tasks, nothing more. It limits blast radius if credentials are compromised.

## Q2. What is the difference between an IAM user and an IAM role?
**Answer:**  
- An IAM user is a long-term identity, usually for a human.  
- An IAM role is a set of permissions that can be assumed temporarily by trusted entities such as EC2, Lambda, or federated users.  
- Roles are strongly preferred for workloads.

## Q3. What is IRSA on EKS, and why is it preferred over node-level IAM?
**Answer:**  
- **IRSA** stands for IAM Roles for Service Accounts.  
- It uses an **OIDC provider** registered with the EKS cluster to exchange a pod's Kubernetes service account token for short-lived AWS credentials via STS.  
- Each pod gets only the permissions its workload needs, not the broad permissions of the worker node.  
- Compared to node-level IAM (instance profile shared by all pods):
  - Smaller blast radius if a pod is compromised.
  - No static credentials stored in pods.
  - Per-workload audit trail in CloudTrail.
- This pattern aligns with **least privilege** and the AWS Well-Architected Security pillar.

## Q4. Why is KMS important?
**Answer:**  
- It manages encryption keys centrally.  
- It integrates with S3, RDS, EBS, Secrets Manager, and more.  
- It supports audit through CloudTrail.  
- It can enforce strong access policies.

## Q5. How should application secrets be handled?
**Answer:**  
- Store them in AWS Secrets Manager or SSM Parameter Store.  
- Reference them at runtime.  
- Avoid baking secrets into images or Git.  
- Rotate them on a schedule.

## Q6. What is the purpose of CloudTrail in SRE, and how do you use it during an incident?
**Answer:**  
- **CloudTrail** records nearly every AWS API call as an event: who called what, when, from where, and the result.  
- For SRE:
  - **Incident forensics**: figure out which IAM principal made a change just before the outage.
  - **Detecting drift**: spot console changes that bypass IaC.
  - **Security audit**: detect use of root, use of unusual regions, or denied API calls.
- Best practices:
  - Enable a multi-region, multi-account trail aggregated to a central S3 bucket.
  - Encrypt with KMS, enable log file integrity validation.
  - Pipe events to CloudWatch Logs or EventBridge for alerting on critical actions (`DeleteBucket`, `DisableKey`, IAM policy changes).
- During an incident, query CloudTrail or **AWS CloudTrail Lake** for the last 60 minutes of activity on the impacted resource.

## Q7. How do you detect risky configurations?
**Answer:**  
- AWS Config rules.  
- AWS Security Hub.  
- Amazon GuardDuty.  
- Periodic IAM access reviews.

## Q8. What should you do if a key is suspected to be compromised?
**Answer:**  
- Rotate or disable the key immediately.  
- Investigate where it was used via CloudTrail.  
- Identify exposure and impacted resources.  
- Document the event and the fix.

## Q9. What is a good practice for service-to-service auth on AWS?
**Answer:**  
- Use IAM roles and signed requests where possible.  
- Avoid sharing static credentials between services.  
- Use VPC endpoints and resource policies to limit exposure.

## Q10. How does SRE work with security teams?
**Answer:**  
- Share telemetry and logs.  
- Align on incident severity definitions.  
- Practice joint incident drills.  
- Integrate security checks into the release pipeline.
