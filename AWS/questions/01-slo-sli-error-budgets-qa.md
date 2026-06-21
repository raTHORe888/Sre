# Q&A: SLOs, SLIs, and Error Budgets

Pairs with: [01-slo-sli-error-budgets.md](../01-slo-sli-error-budgets.md)

---

## Q1. What is the difference between SLI, SLO, and SLA?
**Answer:**  
- **SLI** is a measured indicator of reliability, such as request success rate.  
- **SLO** is a target for an SLI, such as 99.9% success over 30 days.  
- **SLA** is a contractual promise with business consequences if the target is missed.  
SLOs are internal targets. SLAs are usually less strict to give a safety buffer.

## Q2. How do you pick a good SLI?
**Answer:**  
- Pick something that reflects user experience.  
- Make the numerator and denominator clear.  
- Avoid vanity metrics that do not change behavior.  
- Examples: successful HTTP requests, query latency, data freshness.

## Q3. How do you compute an error budget?
**Answer:**  
- If SLO is 99.9% over 30 days, the error budget is 0.1% of requests.  
- For uptime SLOs, error budget converts to allowable minutes of downtime.  
- The budget resets at the start of each SLO window.

## Q4. What is burn rate?
**Answer:**  
- Burn rate is how fast you are consuming the error budget.  
- A 1x burn rate means you would exactly exhaust the budget in the window.  
- A 10x burn rate means the budget will be gone in one tenth of the window.  
- Alerting on multiple burn rate thresholds reduces both noise and missed incidents.

## Q5. Which AWS services help measure SLIs?
**Answer:**  
- CloudWatch metrics and alarms  
- ALB and API Gateway metrics  
- Route 53 health checks  
- CloudWatch Synthetics  
- X-Ray for traces

## Q6. What is a healthy way to use error budgets?
**Answer:**  
- When budget is healthy, the team can ship faster.  
- When budget is depleted, the team slows down risky changes.  
- Use the budget to drive engineering priorities, not blame.

## Q7. How often should SLOs be reviewed?
**Answer:**  
- At least monthly.  
- Also after major incidents.  
- Also when the product or traffic pattern changes.

## Q8. What is a common SLO mistake?
**Answer:**  
- Setting an SLO that no one acts on.  
- Defining too many SLOs.  
- Alerting on raw metrics instead of error budget burn.  
- Picking averages instead of percentiles for latency SLIs.

## Q9. How do you set an initial SLO for a brand new service?
**Answer:**  
- Measure current behavior for two to four weeks first.  
- Pick an SLI that reflects user pain, such as request success rate or p99 latency.  
- Set the SLO slightly stricter than current performance so it drives improvement without being unrealistic.  
- Communicate it to stakeholders and review after 30 days.  
- It is normal for the first SLO to be wrong. Iterate.

## Q10. Why do SREs prefer percentile latency over average latency?
**Answer:**  
- Averages hide tail latency, which is what users actually feel.  
- A service with p50 of 50ms and p99 of 5s has unhappy users even if the average looks fine.  
- p95 and p99 reveal slow requests caused by GC pauses, cold starts, retries, and contention.  
- AWS tools like CloudWatch metrics, X-Ray, ALB and API Gateway metrics all support percentile statistics, so there is no reason not to use them.
