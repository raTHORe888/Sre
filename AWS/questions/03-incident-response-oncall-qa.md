# Q&A: Incident Response and On-Call

Pairs with: [03-incident-response-oncall.md](../03-incident-response-oncall.md)

---

## Q1. What is the first action when an alert fires?
**Answer:**  
- Acknowledge the alert.  
- Confirm whether real users are affected.  
- Assign an incident lead if impact is significant.

## Q2. What does "mitigate first, then analyze" mean?
**Answer:**  
- The first goal is to reduce user impact, not to find root cause.  
- Use rollback, scaling, isolation, or failover to stop the bleeding.  
- Investigation can continue once the service is stable.

## Q3. Which AWS services help during an incident?
**Answer:**  
- CloudWatch alarms and dashboards  
- AWS Systems Manager Incident Manager  
- CloudTrail for change history  
- AWS Health Dashboard for AWS service issues  
- SNS or pager integrations for escalations

## Q4. What is a blameless postmortem?
**Answer:**  
- A postmortem that focuses on systems and processes, not individuals.  
- It encourages openness, faster reporting, and real learning.  
- It produces specific, owned action items.

## Q5. What goes into a good postmortem?
**Answer:**  
- Summary of impact  
- Timeline  
- Root cause and contributing factors  
- What went well, what did not  
- Action items with owners and due dates

## Q6. How do you reduce repeat incidents?
**Answer:**  
- Always create action items after incidents.  
- Improve detection or automation, not just documentation.  
- Track action items to completion in the same backlog as features.

## Q7. How do you communicate during a major incident?
**Answer:**  
- Use a single incident channel.  
- Send short, regular updates.  
- State current impact, current actions, and next update time.  
- Avoid speculation in customer messages.

## Q8. What are typical incident severity levels and how do they differ?
**Answer:**  
- **SEV1** is a critical, customer-impacting outage. All hands, all teams paged, executive comms.  
- **SEV2** is significant degradation or partial outage. On-call engages, leads informed.  
- **SEV3** is limited impact or workaround available. Handled in business hours.  
- **SEV4** is minor or cosmetic. Tracked as a ticket.  
- Severity drives paging, response time, and communication cadence, not just labels.

## Q9. What are the key roles during a major incident?
**Answer:**  
- **Incident Commander** owns coordination and decisions, not the hands-on fix.  
- **Operations or Tech Lead** drives investigation and mitigation.  
- **Communications Lead** sends customer and internal updates.  
- **Scribe** records the timeline, actions, and decisions for the postmortem.  
- For smaller incidents one person may wear multiple hats. For SEV1, separating roles prevents tunnel vision.

## Q10. How do you keep an on-call rotation healthy and avoid burnout?
**Answer:**  
- Every page must be actionable; delete or fix noisy alerts.  
- Track on-call interruption metrics and review them per rotation.  
- Provide handoff documents and clear runbooks.  
- Rotate fairly across the team, including across time zones.  
- Give time-off or comp after heavy on-call weeks.  
- Treat repeated noisy alerts as bugs and fix them instead of normalizing them.
