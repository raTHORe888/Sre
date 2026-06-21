# Q&A: Observability and Monitoring

Pairs with: [02-observability-monitoring.md](../02-observability-monitoring.md)

---

## Q1. What are the four golden signals?
**Answer:**  
- Latency  
- Traffic  
- Errors  
- Saturation

## Q2. What is the difference between monitoring and observability?
**Answer:**  
- Monitoring tells you that something is wrong.  
- Observability helps you explain why something is wrong.  
- Observability needs metrics, logs, and traces together.

## Q3. Which AWS services support observability for Kubernetes?
**Answer:**  
- CloudWatch Container Insights  
- CloudWatch Logs and Logs Insights  
- AWS X-Ray  
- OpenTelemetry exporters  
- Datadog or Grafana when teams need more correlation

## Q4. What metrics matter most for AI workloads on EKS?
**Answer:**  
- GPU and CPU utilization  
- Inference latency p95 and p99  
- Queue depth or batch backlog  
- Pod restarts and OOMKilled events  
- HPA target value and replica count

## Q5. How do you avoid alert fatigue?
**Answer:**  
- Alert on symptoms, not every metric.  
- Use burn-rate alerts tied to SLOs.  
- Route alerts based on severity and ownership.  
- Remove alerts that no one acts on.

## Q6. When should you use traces?
**Answer:**  
- When a single request crosses many services.  
- When latency is high but no service looks broken.  
- When you need to find the slowest hop in a request path.

## Q7. What is the purpose of structured logs?
**Answer:**  
- Easier search in CloudWatch Logs Insights or Datadog.  
- Easier dashboards.  
- Consistent fields across services.  
- Enables automated parsing for incidents and audits.

## Q8. How should observability differ by environment?
**Answer:**  
- Dev needs visibility but tolerates noise.  
- Staging should mirror production dashboards.  
- Production needs symptom-based alerts and clear ownership.

## Q9. What is the difference between the RED and USE methods?
**Answer:**  
- **RED** is for request-driven services: **R**ate, **E**rrors, **D**uration.  
- **USE** is for resources: **U**tilization, **S**aturation, **E**rrors.  
- RED fits APIs and microservices.  
- USE fits CPU, memory, disk, network, GPUs, and queues.  
- The four golden signals are a superset of both.

## Q10. How do you reduce CloudWatch and observability cost without losing visibility?
**Answer:**  
- Right-size log retention per log group; do not keep everything forever.  
- Use log levels and sampling for high-volume services.  
- Use metric filters and CloudWatch Embedded Metric Format to emit metrics from logs efficiently.  
- Apply X-Ray sampling rules instead of tracing every request.  
- Tier storage: hot in CloudWatch, cold in S3 with Athena for ad hoc queries.  
- Audit high-cardinality custom metrics, since cardinality is the main cost driver.
