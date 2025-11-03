#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}CA3 Load Testing Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Get master IP
if ! command -v terraform &> /dev/null; then
  echo -e "${RED}Error: terraform not found${NC}"
  exit 1
fi

MASTER_IP=$(terraform -chdir=terraform output -raw master_public_ip 2>/dev/null || echo "")
if [ -z "$MASTER_IP" ]; then
  echo -e "${RED}Error: Could not get master IP from terraform${NC}"
  echo "Please ensure terraform has been applied successfully"
  exit 1
fi

echo -e "${YELLOW}Master IP:${NC} $MASTER_IP"
echo -e "${YELLOW}Producer endpoint:${NC} http://$MASTER_IP:30000/health"
echo -e "${YELLOW}Processor endpoint:${NC} http://$MASTER_IP:30001/health"
echo ""

# Function to check if endpoint is accessible
check_endpoint() {
  local url=$1
  if curl -sf "$url" > /dev/null; then
    return 0
  else
    return 1
  fi
}

# Check endpoints are accessible
echo -e "${YELLOW}Checking endpoints...${NC}"
if ! check_endpoint "http://$MASTER_IP:30000/health"; then
  echo -e "${RED}Error: Producer endpoint not accessible${NC}"
  exit 1
fi
if ! check_endpoint "http://$MASTER_IP:30001/health"; then
  echo -e "${RED}Error: Processor endpoint not accessible${NC}"
  exit 1
fi
echo -e "${GREEN}Endpoints are accessible${NC}"
echo ""

# Display current HPA status
echo -e "${YELLOW}Current HPA status:${NC}"
kubectl get hpa -n ca3-app
echo ""

# Display current pod counts
echo -e "${YELLOW}Current pod counts:${NC}"
kubectl get pods -n ca3-app | grep -E "producer|processor"
echo ""

# Start load test
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Starting Load Test${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "This will generate sustained load for 5 minutes to trigger autoscaling"
echo "Monitor with: kubectl get hpa -n ca3-app -w"
echo ""
read -p "Press Enter to start or Ctrl+C to cancel..."

DURATION=300  # 5 minutes
CONCURRENCY=50
END_TIME=$(($(date +%s) + DURATION))

echo ""
echo -e "${YELLOW}Load test parameters:${NC}"
echo "  Duration: 5 minutes"
echo "  Concurrent requests: $CONCURRENCY per endpoint"
echo "  Target CPU: >70% (will trigger HPA)"
echo ""

# Start background monitoring
(
  echo "Time,Producer Pods,Processor Pods,Producer CPU,Processor CPU" > load-test-results.csv
  while [ $(date +%s) -lt $END_TIME ]; do
    TIMESTAMP=$(date +%H:%M:%S)
    PRODUCER_PODS=$(kubectl get pods -n ca3-app -l app=producer --no-headers 2>/dev/null | wc -l)
    PROCESSOR_PODS=$(kubectl get pods -n ca3-app -l app=processor --no-headers 2>/dev/null | wc -l)
    PRODUCER_CPU=$(kubectl top pods -n ca3-app -l app=producer --no-headers 2>/dev/null | awk '{sum+=$2} END {print sum}' || echo "0")
    PROCESSOR_CPU=$(kubectl top pods -n ca3-app -l app=processor --no-headers 2>/dev/null | awk '{sum+=$2} END {print sum}' || echo "0")

    echo "$TIMESTAMP,$PRODUCER_PODS,$PROCESSOR_PODS,$PRODUCER_CPU,$PROCESSOR_CPU" >> load-test-results.csv
    echo -e "${YELLOW}[$TIMESTAMP]${NC} Producer: $PRODUCER_PODS pods | Processor: $PROCESSOR_PODS pods"

    sleep 10
  done
) &
MONITOR_PID=$!

# Generate load
echo -e "${GREEN}Generating load...${NC}"
(
  while [ $(date +%s) -lt $END_TIME ]; do
    for i in $(seq 1 $CONCURRENCY); do
      curl -sf "http://$MASTER_IP:30000/health" > /dev/null &
      curl -sf "http://$MASTER_IP:30001/health" > /dev/null &
    done
    sleep 1
  done
  wait
) &
LOAD_PID=$!

# Wait for load test to complete
echo "Load test in progress... (5 minutes)"
echo "You can monitor in another terminal with:"
echo "  kubectl get hpa -n ca3-app -w"
echo "  kubectl top pods -n ca3-app"
echo ""

wait $LOAD_PID
wait $MONITOR_PID

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Load Test Complete${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Display final HPA status
echo -e "${YELLOW}Final HPA status:${NC}"
kubectl get hpa -n ca3-app
echo ""

# Display final pod counts
echo -e "${YELLOW}Final pod counts:${NC}"
kubectl get pods -n ca3-app | grep -E "producer|processor"
echo ""

# Display results
echo -e "${YELLOW}Results saved to:${NC} load-test-results.csv"
echo ""
echo -e "${GREEN}Scale-down observation:${NC}"
echo "Pods will scale down after 5 minutes of low load"
echo "Monitor with: kubectl get hpa -n ca3-app -w"
echo ""

# Display HPA events
echo -e "${YELLOW}Recent HPA events:${NC}"
kubectl describe hpa producer-hpa -n ca3-app | tail -20
echo ""
kubectl describe hpa processor-hpa -n ca3-app | tail -20
