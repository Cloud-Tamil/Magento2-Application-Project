# Monitoring, Logging & Observability Guide

## 1. Centralized Observability Matrix

| Layer | Tooling | Metrics / Log Destinations |
|---|---|---|
| Load Balancer | AWS ALB | HTTP 2XX, 4XX, 5XX counts, Target Response Time, Unhealthy Host Count |
| Kubernetes Cluster | CloudWatch Container Insights & Prometheus | Pod CPU/Memory, Node Disk I/O, Network Tx/Rx, HPA scaling events |
| Web Server | Nginx Ingress / Pod Nginx | Access logs, slow requests, 502/504 errors |
| Application | PHP-FPM / Magento 2 | `var/log/system.log`, `var/log/exception.log`, PHP slow query log |
| Relational Database | Amazon RDS MySQL | CPUUtilization, FreeableMemory, DatabaseConnections, SlowQueryLog |
| In-Memory Cache | Amazon ElastiCache Redis | CPUUtilization, DatabaseMemoryUsagePercentage, CacheHits, Evictions |
| Search Engine | Amazon OpenSearch | ClusterStatus (Green/Yellow/Red), JVMGC, SearchLatency, IndexingRate |
| Message Broker | Amazon MQ (RabbitMQ) | MessageCount, QueueCount, ConsumerCount, ChannelCount |

## 2. Recommended Production Alerts

1. **RDS MySQL High CPU / Connection Exhaustion**:
   - Condition: `CPUUtilization > 80%` for 2 consecutive 5-minute periods OR `DatabaseConnections > 200`.
   - Action: CloudWatch Alarm -> SNS Topic -> PagerDuty.
2. **ElastiCache Redis Memory Saturation**:
   - Condition: `DatabaseMemoryUsagePercentage > 85%`.
   - Action: Triggers autoscaling or node type resize.
3. **Application Load Balancer 5XX Spike**:
   - Condition: `HTTPCode_Target_5XX_Count > 10` in 1 minute.
   - Action: Indicates PHP-FPM worker exhaustion or database connection drop.
4. **Pod CrashLoopBackOff**:
   - Condition: Any Magento Pod restarting more than 3 times in 10 minutes.
   - Action: Kubernetes event captured via Prometheus Alertmanager.
