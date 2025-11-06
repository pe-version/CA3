# CA3 Observability Stack - Implementation Complete

## What We Built

✅ **Complete observability stack for CA3 assignment (25% of grade)**

### Components Deployed

1. **Prometheus + Grafana (kube-prometheus-stack)**
   - Prometheus for metrics collection
   - Grafana for visualization
   - Alertmanager for alerts
   - ServiceMonitors for automatic service discovery

2. **Loki + Promtail**
   - Loki for centralized log storage
   - Promtail DaemonSet for log collection from all pods

3. **Instrumented Python Applications**
   - Producer v1.1 with Prometheus metrics
   - Processor v1.1 with Prometheus metrics
   - Custom metrics endpoints at `/metrics`

## Custom Metrics Implemented

### Producer Metrics (`producer:v1.1`)
- `producer_messages_total{metal, topic}` - Counter of messages produced by metal type
- `producer_errors_total` - Counter of production errors
- `kafka_connection_status` - Gauge (1=connected, 0=disconnected)

### Processor Metrics (`processor:v1.1`)
- `processor_messages_total{metal}` - Counter of messages processed by metal type
- `processor_errors_total` - Counter of processing errors
- `mongodb_inserts_total{metal}` - Counter of MongoDB inserts by metal type
- `processing_duration_seconds` - Histogram of processing latency
- `kafka_connection_status` - Gauge for Kafka connection health
- `mongodb_connection_status` - Gauge for MongoDB connection health

## Files Created/Modified

### New Files:
```
k8s/base/22-servicemonitors.yaml          # ServiceMonitor CRDs for Prometheus
k8s/observability/metals-dashboard.json   # Grafana dashboard JSON
k8s/observability/GRAFANA-SETUP.md        # Setup and usage guide
```

### Modified Files:
```
producer/producer.py                      # Added prometheus_client metrics
producer/requirements.txt                 # Added prometheus-client==0.19.0
processor/processor.py                    # Added prometheus_client metrics
processor/requirements.txt                # Added prometheus-client==0.19.0
k8s/base/21-producer.yaml                 # Updated to v1.1 image
k8s/base/20-processor.yaml                # Updated to v1.1 image
k8s/base/kustomization.yaml               # Added servicemonitors resource
```

## Access Information

### Grafana
- **URL:** http://localhost:3000 (when port-forwarded)
- **Username:** admin
- **Password:** Get with: `kubectl --namespace ca3-app get secrets prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d`

### Prometheus
- **URL:** http://localhost:9090 (when port-forwarded)
- **Port-forward:** `kubectl --namespace ca3-app port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090`

### Metrics Endpoints
- **Producer:** http://producer:8000/metrics
- **Processor:** http://processor:8001/metrics

## Dashboard Features

The CA3 Metals Processing Dashboard provides:

1. **Real-time message rates** - Producer and processor throughput by metal type
2. **Cumulative totals** - Total messages produced and processed
3. **MongoDB performance** - Insert rates and operation counts
4. **Processing latency** - p95 latency histogram
5. **Connection health** - Kafka and MongoDB connection status gauges
6. **Error tracking** - Combined error counts from both services

## Verification Commands

```bash
# Check all observability pods
kubectl get pods -n ca3-app | grep -E '(prometheus|grafana|loki|promtail)'

# Verify ServiceMonitors
kubectl get servicemonitor -n ca3-app

# Test producer metrics
kubectl exec -n ca3-app deployment/producer -- curl -s localhost:8000/metrics | grep producer_messages_total

# Test processor metrics
kubectl exec -n ca3-app deployment/processor -- curl -s localhost:8001/metrics | grep processor_messages_total

# View producer logs
kubectl logs -n ca3-app -l app=producer --tail=20

# View processor logs
kubectl logs -n ca3-app -l app=processor --tail=20
```

## Assignment Requirements Met

✅ **Observability (25%):**
- Prometheus metrics collection from custom applications
- Grafana dashboards with meaningful visualizations
- Centralized logging with Loki + Promtail
- ServiceMonitor CRDs for automatic service discovery
- Custom metrics: message rates, errors, connection status, processing latency

## Next Steps for CA3

1. **Security (20%):**
   - [ ] Implement NetworkPolicy for pod-to-pod communication
   - [ ] Configure TLS for Kafka
   - [ ] Configure TLS for MongoDB
   - [ ] Review RBAC configurations

2. **Resilience (25%):**
   - [x] HPA already configured (done earlier)
   - [ ] Perform chaos testing (kill pods)
   - [ ] Record video demonstrating recovery
   - [ ] Test persistent data recovery

3. **Documentation (10%):**
   - [ ] Update README with full deployment instructions
   - [ ] Document architecture decisions
   - [ ] Include screenshots of Grafana dashboards
   - [ ] Document testing procedures

## Current Status

🟢 **All pods running successfully:**
- Producer: 2/2 replicas running with v1.1 (metrics enabled)
- Processor: 2/2 replicas running with v1.1 (metrics enabled)
- Kafka: 1/1 running
- Zookeeper: 1/1 running
- MongoDB: 1/1 running
- Prometheus: 1/1 running
- Grafana: 1/1 running
- Loki: 1/1 running
- Promtail: 1/1 running (DaemonSet)

🟢 **Metrics collection verified:**
- Custom producer metrics working
- Custom processor metrics working
- ServiceMonitors discovered by Prometheus
- Metrics endpoints responding on both services

🟢 **Logging infrastructure ready:**
- Loki receiving logs from Promtail
- All pod logs being collected
- Ready for Grafana Explore queries
