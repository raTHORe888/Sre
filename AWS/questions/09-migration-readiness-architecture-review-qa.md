# Q&A: Migration Readiness and Architecture Review

Pairs with: [09-migration-readiness-architecture-review.md](../09-migration-readiness-architecture-review.md)

---

## Q1. What is migration readiness in an SRE context?
**Answer:**  
The state where a workload can be moved or onboarded to a target environment with low risk and predictable behavior. It covers observability, scaling, security, and runbooks.

## Q2. What is the AWS Well-Architected Framework?
**Answer:**  
A set of best practice pillars from AWS that guide design and operations:  
- Operational Excellence  
- Security  
- Reliability  
- Performance Efficiency  
- Cost Optimization  
- Sustainability

## Q3. Why do architecture reviews matter?
**Answer:**  
They surface risks before launch, align stakeholders, and improve the chance of meeting reliability and security goals.

## Q4. What questions should an architecture review answer?
**Answer:**  
- What is the SLO?  
- What are the failure modes?  
- How is data protected and recovered?  
- How is the system observed?  
- How are changes deployed and rolled back?  
- What is the cost profile?

## Q5. What signals indicate a workload is not migration-ready?
**Answer:**  
- No clear owner.  
- No SLOs.  
- No dashboards or alerts.  
- No runbooks.  
- No defined deploy or rollback process.  
- No backup and restore validation.

## Q6. How do you mitigate risk during a migration?
**Answer:**  
- Run old and new in parallel.  
- Use feature flags to ramp traffic.  
- Validate metrics in each step.  
- Have rollback ready.  
- Communicate timelines.

## Q7. What is a migration checklist worth keeping?
**Answer:**  
- Architecture diagram.  
- IAM and network model.  
- IaC repo links.  
- Dashboards and alerts.  
- Runbooks.  
- DR plan.  
- Cost forecast.

## Q8. How do you measure success after migration?
**Answer:**  
- SLO compliance.  
- Incident frequency and severity.  
- Deploy frequency.  
- MTTR.  
- Cost per request or per tenant.

## Q9. How do you prepare AI workloads for migration?
**Answer:**  
- Verify GPU capacity and quotas.  
- Capture model versions in IaC or Git.  
- Plan for autoscaling latency.  
- Test inference latency in the target environment.  
- Build dashboards for tokens, queue depth, and GPU usage.

## Q10. What happens after the migration is "done"?
**Answer:**  
- Run a post-implementation review.  
- Update documentation.  
- Plan for ongoing capacity and cost reviews.  
- Schedule the next architecture review cycle.
