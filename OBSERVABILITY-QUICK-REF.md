# CA3 Quick Reference - Observability Stack

## 🚀 Quick Access

### Grafana
```bash
# Port-forward
kubectl port-forward -n ca3-app svc/prometheus-grafana 3000:80

# Get password
kubectl get secret -n ca3-app prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d

# Login: http://localhost:3000
# Username: admin
# Password: (from command above)
```

### Prometheus
```bash
# Port-forward
kubectl port-forward -n ca3-app svc/prometheus-kube-prometheus-prometheus 9090:9090

# Access: http://localhost:9090
```

## 📊 Custom Metrics

### Producer Metrics (port 8000)
```
producer_messages_total{metal, topic}    # Messages sent by metal type
producer_errors_total                    # Production errors
kafka_connection_status                  # 1=connected, 0=disconnected
```

### Processor Metrics (port 8001)
```
processor_messages_total{metal}          # Messages processed by metal
processor_errors_total                   # Processing errors
mongodb_inserts_total{metal}             # MongoDB inserts by metal
processing_duration_seconds              # Processing latency histogram
mongodb_connection_status                # 1=connected, 0=disconnected
kafka_connection_status                  # 1=connected, 0=disconnected
```

## 🔍 Useful PromQL Queries

```promql
# Message rate per second
rate(producer_messages_total[1m])
rate(processor_messages_total[1m])

# Total messages by metal type
sum by (metal) (producer_messages_total)
sum by (metal) (processor_messages_total)

# Error rate
rate(producer_errors_total[5m])
rate(processor_errors_total[5m])

# Processing latency p95
histogram_quantile(0.95, rate(processing_duration_seconds_bucket[1m]))

# Connection health
kafka_connection_status
mongodb_connection_status
```

## 📝 Useful LogQL Queries (Loki)

```logql
# All producer logs
{namespace="ca3-app", app="producer"}

# All processor logs
{namespace="ca3-app", app="processor"}

# Error logs only
{namespace="ca3-app"} |~ "ERROR|Error|error"

# Messages sent
{namespace="ca3-app", app="producer"} |~ "Sent:"

# Messages processed
{namespace="ca3-app", app="processor"} |~ "Processed:"

# Specific metal
{namespace="ca3-app"} |~ "gold"
```

## 🧪 Testing Commands

```bash
# Test producer metrics endpoint
kubectl exec -n ca3-app deployment/producer -- curl -s localhost:8000/metrics

# Test processor metrics endpoint
kubectl exec -n ca3-app deployment/processor -- curl -s localhost:8001/metrics

# View producer logs
kubectl logs -n ca3-app -l app=producer --tail=20 -f

# View processor logs
kubectl logs -n ca3-app -l app=processor --tail=20 -f

# Check ServiceMonitor targets
kubectl get servicemonitor -n ca3-app

# Verify all observability components
./scripts/verify-observability.sh
```

## 📸 Screenshots Needed for Assignment

1. **Grafana Dashboard** - Full CA3 Metals Processing Dashboard with live data
2. **Prometheus Targets** - Status → Targets showing producer/processor as UP
3. **Loki Logs** - Explore view with producer and processor logs
4. **Metrics Endpoint** - Terminal showing curl output from /metrics
5. **Pod Status** - kubectl get pods showing all components Running

## 🎯 Assignment Completion Status

### Observability (25%) ✅ COMPLETE
- ✅ Prometheus metrics collection
- ✅ Grafana dashboards
- ✅ Centralized logging (Loki + Promtail)
- ✅ ServiceMonitors configured
- ✅ Custom application metrics

### Autoscaling (20%) ✅ COMPLETE
- ✅ HPA configured for producer (1-3 replicas)
- ✅ HPA configured for processor (1-3 replicas)
- ✅ CPU and memory targets set

### Security (20%) ⚠️ TODO
- ⚠️ NetworkPolicy needed
- ⚠️ TLS for Kafka
- ⚠️ TLS for MongoDB
- ✅ ExternalSecrets (AWS Secrets Manager)

### Resilience (25%) ⚠️ TODO
- ✅ HPA for auto-recovery
- ⚠️ Chaos testing needed
- ⚠️ Video demonstration needed

### Documentation (10%) ⚠️ TODO
- ⚠️ Final README update
- ⚠️ Architecture documentation
- ✅ Observability guide complete

## 🔗 Documentation Files

- `/k8s/observability/GRAFANA-SETUP.md` - Complete Grafana setup guide
- `/k8s/observability/metals-dashboard.json` - Grafana dashboard JSON
- `/OBSERVABILITY-COMPLETE.md` - Implementation summary
- `/scripts/verify-observability.sh` - Verification script
