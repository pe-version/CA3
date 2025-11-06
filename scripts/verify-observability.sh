#!/bin/bash

# CA3 Observability Stack Verification Script

set -e

echo "=========================================="
echo "CA3 Observability Stack Verification"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check all pods
echo "1. Checking pod status..."
if kubectl get pods -n ca3-app | grep -E "(producer|processor|prometheus|grafana|loki|promtail)" | grep -q "Running"; then
    echo -e "${GREEN}✓ All observability pods are running${NC}"
    kubectl get pods -n ca3-app | grep -E "(producer|processor|prometheus|grafana|loki|promtail)"
else
    echo -e "${RED}✗ Some pods are not running${NC}"
    exit 1
fi
echo ""

# Check ServiceMonitors
echo "2. Checking ServiceMonitors..."
if kubectl get servicemonitor -n ca3-app producer-monitor processor-monitor &>/dev/null; then
    echo -e "${GREEN}✓ ServiceMonitors created${NC}"
    kubectl get servicemonitor -n ca3-app producer-monitor processor-monitor
else
    echo -e "${RED}✗ ServiceMonitors not found${NC}"
    exit 1
fi
echo ""

# Test producer metrics
echo "3. Testing producer metrics endpoint..."
PRODUCER_POD=$(kubectl get pod -n ca3-app -l app=producer -o jsonpath='{.items[0].metadata.name}')
if kubectl exec -n ca3-app $PRODUCER_POD -- curl -s localhost:8000/metrics | grep -q "producer_messages_total"; then
    echo -e "${GREEN}✓ Producer metrics endpoint working${NC}"
    echo "Sample metrics:"
    kubectl exec -n ca3-app $PRODUCER_POD -- curl -s localhost:8000/metrics | grep -E "(producer_messages_total|kafka_connection_status)" | head -5
else
    echo -e "${RED}✗ Producer metrics not working${NC}"
    exit 1
fi
echo ""

# Test processor metrics
echo "4. Testing processor metrics endpoint..."
PROCESSOR_POD=$(kubectl get pod -n ca3-app -l app=processor -o jsonpath='{.items[0].metadata.name}')
if kubectl exec -n ca3-app $PROCESSOR_POD -- curl -s localhost:8001/metrics | grep -q "processor_messages_total"; then
    echo -e "${GREEN}✓ Processor metrics endpoint working${NC}"
    echo "Sample metrics:"
    kubectl exec -n ca3-app $PROCESSOR_POD -- curl -s localhost:8001/metrics | grep -E "(processor_messages_total|mongodb_inserts_total)" | head -5
else
    echo -e "${RED}✗ Processor metrics not working${NC}"
    exit 1
fi
echo ""

# Check Grafana
echo "5. Checking Grafana..."
if kubectl get pod -n ca3-app -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].status.phase}' | grep -q "Running"; then
    echo -e "${GREEN}✓ Grafana pod is running${NC}"
    echo -e "${YELLOW}→ Access Grafana at http://localhost:3000${NC}"
    echo -e "${YELLOW}→ Username: admin${NC}"
    echo -e "${YELLOW}→ Password: Run this command to get it:${NC}"
    echo "  kubectl --namespace ca3-app get secrets prometheus-grafana -o jsonpath=\"{.data.admin-password}\" | base64 -d ; echo"
else
    echo -e "${RED}✗ Grafana pod not running${NC}"
    exit 1
fi
echo ""

# Check Loki
echo "6. Checking Loki..."
if kubectl get pod -n ca3-app loki-0 -o jsonpath='{.status.phase}' | grep -q "Running"; then
    echo -e "${GREEN}✓ Loki pod is running${NC}"
    echo -e "${YELLOW}→ Loki service: http://loki:3100${NC}"
else
    echo -e "${RED}✗ Loki pod not running${NC}"
    exit 1
fi
echo ""

# Check Promtail
echo "7. Checking Promtail..."
if kubectl get daemonset -n ca3-app loki-promtail -o jsonpath='{.status.numberReady}' | grep -q "1"; then
    echo -e "${GREEN}✓ Promtail DaemonSet is running${NC}"
else
    echo -e "${RED}✗ Promtail DaemonSet not ready${NC}"
    exit 1
fi
echo ""

# Summary
echo "=========================================="
echo -e "${GREEN}✓ All observability checks passed!${NC}"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Port-forward Grafana: kubectl --namespace ca3-app port-forward svc/prometheus-grafana 3000:80"
echo "2. Access Grafana at http://localhost:3000"
echo "3. Configure Loki datasource: http://loki:3100"
echo "4. Import dashboard from: k8s/observability/metals-dashboard.json"
echo "5. See full guide: k8s/observability/GRAFANA-SETUP.md"
echo ""
