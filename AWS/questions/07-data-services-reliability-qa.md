# Q&A: Data Services Reliability

Pairs with: [07-data-services-reliability.md](../07-data-services-reliability.md)

---

## Q1. What are the main AWS data services SREs care about?
**Answer:**  
- Amazon RDS and Aurora  
- Amazon DynamoDB  
- Amazon S3  
- Amazon EFS and FSx  
- Amazon ElastiCache  
- Amazon MSK

## Q2. What is Multi-AZ in RDS, and how does it differ from read replicas?
**Answer:**  
- **Multi-AZ** is a high-availability feature. A standby instance is maintained in a different Availability Zone with synchronous replication. AWS handles automatic failover (typically 60-120 seconds) on instance or AZ failure.  
- The standby is **not used for reads** in classic Multi-AZ (RDS); it exists purely for failover.  
- **Read replicas** are different: asynchronous replication, used for read scaling, can be promoted manually to primary.  
- Combine them: Multi-AZ for HA + read replicas for read scale.  
- **Aurora** is different again: a shared storage layer replicates across three AZs and supports up to 15 read replicas with sub-second lag.  
- Failover does not preserve cached connections; clients should use the RDS endpoint (which AWS updates) and handle reconnects.

## Q3. What is a read replica used for?
**Answer:**  
- Offloading read traffic.  
- Providing additional read capacity.  
- Optionally promoting to a primary in some failure scenarios.

## Q4. What does S3 versioning give you?
**Answer:**  
- Protection against accidental overwrites and deletes.  
- Ability to recover prior object versions.  
- Better recovery posture during incidents.

## Q5. How do you back up RDS or Aurora?
**Answer:**  
- Use automated backups and snapshots.  
- Choose appropriate retention.  
- Test restores periodically.  
- Document the restore runbook.

## Q6. What is a common failure pattern for stateful services?
**Answer:**  
- Storage exhaustion.  
- Connection pool exhaustion.  
- Replication lag.  
- Failover edge cases.  
- Long-running queries holding locks.

## Q7. What is RPO and RTO?
**Answer:**  
- RPO is the recovery point objective, how much data you can afford to lose.  
- RTO is the recovery time objective, how fast you must be back online.

## Q8. How do you size capacity for a database?
**Answer:**  
- Baseline current workload.  
- Project growth.  
- Add safety margin.  
- Validate with load tests.  
- Monitor and revise quarterly.

## Q9. What is a good practice for production data changes?
**Answer:**  
- Use migrations checked into Git.  
- Test migrations against a copy of prod data.  
- Use feature flags to decouple deploy from rollout.  
- Have a rollback plan, including data implications.

## Q10. How do you reduce risk when scaling a data service?
**Answer:**  
- Scale early, not at saturation.  
- Use connection pooling.  
- Use read replicas for read-heavy traffic.  
- Watch tail latency, not just averages.
