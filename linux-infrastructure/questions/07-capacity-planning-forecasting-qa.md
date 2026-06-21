# Q&A: Capacity Planning and Growth Forecasting

Pairs with: [07-capacity-planning-forecasting.md](../07-capacity-planning-forecasting.md)

> 10 interview-grade questions on capacity planning.

---

## Q1. What is capacity planning, and how does it differ from autoscaling?
**Answer:**  
- **Capacity planning** is the proactive process of forecasting future demand and provisioning resources in advance (often weeks or months ahead).  
- **Autoscaling** is a reactive mechanism that scales resources up or down within an existing capacity pool, typically in minutes.  
- They complement each other:
  - Capacity planning ensures the pool exists.
  - Autoscaling distributes that pool efficiently across workloads.
- For bare metal or constrained cloud quotas, capacity planning is the critical lever.

## Q2. What inputs do you need to build a capacity model?
**Answer:**  
- Historical usage time series: CPU, memory, disk, IOPS, throughput, request rate.  
- SLO targets (e.g., never exceed 70% steady-state utilization).  
- Business roadmap: new customers, regions, features.  
- Hardware lead times and cloud quota approval times.  
- Per-tenant usage patterns to anticipate surges.  
- Failure budget: how much spare capacity you keep for losing N hosts/AZs.

## Q3. How do you forecast organic growth versus surge growth?
**Answer:**  
- **Organic growth**: model with linear regression, exponential smoothing (Holt-Winters), or Prophet on long historical data.  
- **Surge growth**: identify drivers (product launches, marketing events, large customer onboards) and add explicit demand from those events on top of the baseline.  
- Always keep **scenarios**: best, expected, worst case.  
- Re-forecast quarterly or after major business changes.

## Q4. What is a utilization ceiling, and why do you set one?
**Answer:**  
- A target maximum utilization (e.g., 70% on disk, 60% on CPU) you do not want steady-state usage to cross.  
- Reasons:
  - Headroom for tail latency.
  - Headroom for losing hosts/AZs without breaking SLOs.
  - Headroom to absorb growth between procurement cycles.
- For object storage, ceilings around **70-80%** are common because performance and recovery degrade as clusters fill.

## Q5. How do hardware lead times influence capacity planning?
**Answer:**  
- Lead times include vendor manufacturing, shipping, racking, cabling, provisioning.  
- For bare metal, this can be **weeks to months**.  
- Your **planning horizon must exceed lead time** plus a safety buffer.  
- Maintain a **rolling forecast** that always has at least one lead time of runway.  
- For cloud, "lead time" is the cycle to request, approve, and obtain new quotas; do not assume infinite cloud capacity.

## Q6. How do you handle a sudden growth spike that exceeds your forecast?
**Answer:**  
- **Short-term**: use spare capacity, autoscaling, or burst into another region/AZ.  
- **Cloud**: open emergency quota requests; consider Spot/Reserved instance mix.  
- **On-prem**: redistribute workloads, deprioritize non-critical jobs, accelerate procurement.  
- **Communicate**: notify product and leadership about the spike and the response plan.  
- **Post-event**: update the forecast model to incorporate the new trend.

## Q7. What metrics indicate that you are running out of capacity?
**Answer:**  
- Utilization trending toward or above the ceiling.  
- Increased tail latency (p95/p99) without obvious bugs.  
- Queue depth and request rate climbing.  
- Failed autoscale events ("no available capacity").  
- Per-tenant slowdowns or quota throttling.  
- Operator alerts for "X% full" thresholds firing more frequently.

## Q8. How would you build a capacity dashboard for a clustered service?
**Answer:**  
- Show **current usage** vs **ceiling** per resource (CPU, memory, disk, IOPS, throughput, request rate).  
- Show **projection** based on the forecast model with confidence intervals.  
- Display **runway** in days/weeks until exhaustion.  
- Break down by **service, region, AZ, tenant**.  
- Highlight **growth anomalies** with automated alerts.  
- Track **deliveries**: hardware on order, expected install dates.

## Q9. How do you tie capacity planning into change management?
**Answer:**  
- Every large rollout, customer onboard, or migration triggers a **capacity check**.  
- The change record references current and projected utilization.  
- For changes that increase demand significantly, an explicit capacity sign-off is required.  
- After the change, validate that real demand matches forecast.  
- Adjust models if forecasts repeatedly miss real demand.

## Q10. What is the relationship between capacity planning and SLOs?
**Answer:**  
- SLOs define what reliability is required.  
- Capacity planning ensures you have enough resources to meet SLOs even with failures and growth.  
- If utilization approaches the ceiling, SLO burn often increases (tail latency, errors).  
- Use SLO burn as an **early warning** that capacity headroom is shrinking.  
- Treat capacity as one of the levers (alongside code and architecture) to keep SLOs healthy.
