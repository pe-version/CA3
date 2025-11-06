# Grafana Setup Guide for CA3

## Access Grafana

1. **Port-forward Grafana service:**
   ```bash
   kubectl --namespace ca3-app port-forward svc/prometheus-grafana 3000:80
   ```

2. **Access Grafana UI:**
   - URL: http://localhost:3000
   - Username: `admin`
   - Password: Run this command to get it:
     ```bash
     kubectl --namespace ca3-app get secrets prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo
     ```

## Configure Loki Datasource

1. Navigate to **Configuration → Data Sources** (gear icon on left sidebar)
2. Click **Add data source**
3. Select **Loki**
4. Configure:
   - **Name:** Loki
   - **URL:** `http://loki:3100`
5. Click **Save & Test**

## Import Metals Dashboard

### Option 1: Via UI
1. Navigate to **Dashboards → Import** (+ icon on left sidebar)
2. Click **Upload JSON file**
3. Select: `/Users/jr.ikamp/Downloads/CA3/k8s/observability/metals-dashboard.json`
4. Select **Prometheus** as the datasource
5. Click **Import**

### Option 2: Via API
```bash
# Get Grafana admin password
GRAFANA_PASSWORD=$(kubectl --namespace ca3-app get secrets prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d)

# Port-forward Grafana (if not already done)
kubectl --namespace ca3-app port-forward svc/prometheus-grafana 3000:80 &

# Import dashboard
curl -X POST http://admin:${GRAFANA_PASSWORD}@localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d @k8s/observability/metals-dashboard.json
```

## Dashboard Panels

The CA3 Metals Processing Dashboard includes:

1. **Producer Message Rate by Metal** - Messages produced per second for each metal type
2. **Processor Message Rate by Metal** - Messages processed per second for each metal type
3. **Total Messages Produced** - Cumulative count of all produced messages
4. **Total Messages Processed** - Cumulative count of all processed messages
5. **MongoDB Insert Rate** - Database inserts per second by metal type
6. **Processing Duration (p95)** - 95th percentile of message processing time
7. **Kafka Connection Status** - Real-time Kafka connection health (1=connected, 0=disconnected)
8. **MongoDB Connection Status** - Real-time MongoDB connection health
9. **Total Errors** - Combined error count from producer and processor

## View Application Logs in Grafana

1. Navigate to **Explore** (compass icon on left sidebar)
2. Select **Loki** datasource from dropdown
3. Use LogQL queries to filter logs:

### Example Queries:

**Producer logs:**
```logql
{namespace="ca3-app", app="producer"}
```

**Processor logs:**
```logql
{namespace="ca3-app", app="processor"}
```

**Error logs only:**
```logql
{namespace="ca3-app"} |~ "ERROR|Error|error"
```

**Logs with "Sent" messages:**
```logql
{namespace="ca3-app", app="producer"} |~ "Sent:"
```

**Logs with "Processed" messages:**
```logql
{namespace="ca3-app", app="processor"} |~ "Processed:"
```

## Verify Metrics Endpoints

Test that metrics are being exposed:

```bash
# Producer metrics
kubectl exec -n ca3-app deployment/producer -- curl -s localhost:8000/metrics | grep producer_messages_total

# Processor metrics
kubectl exec -n ca3-app deployment/processor -- curl -s localhost:8001/metrics | grep processor_messages_total
```

## Verify Prometheus Targets

1. Port-forward Prometheus:
   ```bash
   kubectl --namespace ca3-app port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090
   ```

2. Access Prometheus UI at http://localhost:9090

3. Navigate to **Status → Targets** to verify that:
   - `ca3-app/producer-monitor/0` is UP
   - `ca3-app/processor-monitor/0` is UP

## Screenshots for Assignment

Capture the following for your CA3 submission:

1. **Grafana Dashboard** - Full view showing all panels with live data
2. **Loki Logs** - Explore view showing producer and processor logs
3. **Prometheus Targets** - Targets page showing ServiceMonitors as UP
4. **Metrics Endpoint** - Terminal output showing custom metrics from producer/processor
