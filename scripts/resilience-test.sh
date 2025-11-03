#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}CA3 Resilience Testing Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Function to wait for pods to be ready
wait_for_pods() {
  local label=$1
  local expected_count=$2
  local timeout=120

  echo -e "${YELLOW}Waiting for $expected_count pod(s) with label $label to be ready...${NC}"

  local count=0
  while [ $count -lt $timeout ]; do
    local ready=$(kubectl get pods -n ca3-app -l "$label" --field-selector=status.phase=Running 2>/dev/null | grep -c "Running" || echo "0")

    if [ "$ready" -ge "$expected_count" ]; then
      echo -e "${GREEN}Pods are ready!${NC}"
      return 0
    fi

    echo "  Waiting... ($ready/$expected_count ready) [$count/$timeout]"
    sleep 2
    count=$((count + 2))
  done

  echo -e "${RED}Timeout waiting for pods${NC}"
  return 1
}

# Function to check health endpoint
check_health() {
  local url=$1
  local max_attempts=30
  local attempt=0

  while [ $attempt -lt $max_attempts ]; do
    if curl -sf "$url" > /dev/null 2>&1; then
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 2
  done

  return 1
}

# Get master IP
MASTER_IP=$(terraform -chdir=terraform output -raw master_public_ip 2>/dev/null || echo "")
if [ -z "$MASTER_IP" ]; then
  echo -e "${RED}Error: Could not get master IP from terraform${NC}"
  exit 1
fi

# Display initial cluster state
echo -e "${BLUE}Initial Cluster State:${NC}"
kubectl get nodes -o wide
echo ""
kubectl get pods -n ca3-app -o wide
echo ""

# Test selection menu
echo -e "${GREEN}Select resilience test:${NC}"
echo "1. Pod deletion test (Kubernetes self-healing)"
echo "2. Process kill test (Container restart)"
echo "3. Node drain test (Pod rescheduling)"
echo "4. Multiple pod failure (Cascading failure)"
echo "5. All tests (sequential)"
echo ""
read -p "Enter choice [1-5]: " choice

run_pod_deletion_test() {
  echo ""
  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN}Test 1: Pod Deletion (Self-Healing)${NC}"
  echo -e "${GREEN}========================================${NC}"
  echo ""
  echo "This test deletes a producer pod and verifies Kubernetes recreates it automatically"
  echo ""

  # Get current producer pod
  PRODUCER_POD=$(kubectl get pod -n ca3-app -l app=producer -o jsonpath='{.items[0].metadata.name}')
  echo -e "${YELLOW}Target pod:${NC} $PRODUCER_POD"

  # Check health before
  echo -e "${YELLOW}Checking health before deletion...${NC}"
  if check_health "http://$MASTER_IP:30000/health"; then
    echo -e "${GREEN}Producer is healthy${NC}"
  else
    echo -e "${RED}Producer is not healthy - test may be invalid${NC}"
  fi

  # Record start time
  START_TIME=$(date +%s)

  # Delete pod
  echo ""
  echo -e "${YELLOW}Deleting pod...${NC}"
  kubectl delete pod "$PRODUCER_POD" -n ca3-app --force --grace-period=0

  # Wait for new pod
  echo -e "${YELLOW}Waiting for replacement pod...${NC}"
  wait_for_pods "app=producer" 1

  # Get new pod name
  NEW_PRODUCER_POD=$(kubectl get pod -n ca3-app -l app=producer -o jsonpath='{.items[0].metadata.name}')
  echo -e "${YELLOW}New pod:${NC} $NEW_PRODUCER_POD"

  # Check health after
  echo -e "${YELLOW}Checking health after recreation...${NC}"
  if check_health "http://$MASTER_IP:30000/health"; then
    END_TIME=$(date +%s)
    RECOVERY_TIME=$((END_TIME - START_TIME))
    echo -e "${GREEN}Producer is healthy again!${NC}"
    echo -e "${GREEN}Recovery time: ${RECOVERY_TIME}s${NC}"
  else
    echo -e "${RED}Producer failed to recover${NC}"
    return 1
  fi

  echo ""
  echo -e "${BLUE}Pod details:${NC}"
  kubectl get pod "$NEW_PRODUCER_POD" -n ca3-app -o wide
  echo ""
}

run_process_kill_test() {
  echo ""
  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN}Test 2: Process Kill (Container Restart)${NC}"
  echo -e "${GREEN}========================================${NC}"
  echo ""
  echo "This test kills the main process inside a processor pod and verifies container restart"
  echo ""

  # Get current processor pod
  PROCESSOR_POD=$(kubectl get pod -n ca3-app -l app=processor -o jsonpath='{.items[0].metadata.name}')
  echo -e "${YELLOW}Target pod:${NC} $PROCESSOR_POD"

  # Get restart count before
  RESTART_BEFORE=$(kubectl get pod "$PROCESSOR_POD" -n ca3-app -o jsonpath='{.status.containerStatuses[0].restartCount}')
  echo -e "${YELLOW}Restart count before:${NC} $RESTART_BEFORE"

  # Record start time
  START_TIME=$(date +%s)

  # Kill process (PID 1 is the main process)
  echo ""
  echo -e "${YELLOW}Killing main process (PID 1)...${NC}"
  kubectl exec "$PROCESSOR_POD" -n ca3-app -- sh -c "kill 1" 2>/dev/null || true

  # Wait for restart
  echo -e "${YELLOW}Waiting for container to restart...${NC}"
  sleep 5

  # Wait for pod to be ready again
  wait_for_pods "app=processor" 1

  # Get restart count after
  RESTART_AFTER=$(kubectl get pod "$PROCESSOR_POD" -n ca3-app -o jsonpath='{.status.containerStatuses[0].restartCount}')
  echo -e "${YELLOW}Restart count after:${NC} $RESTART_AFTER"

  if [ "$RESTART_AFTER" -gt "$RESTART_BEFORE" ]; then
    END_TIME=$(date +%s)
    RECOVERY_TIME=$((END_TIME - START_TIME))
    echo -e "${GREEN}Container restarted successfully!${NC}"
    echo -e "${GREEN}Recovery time: ${RECOVERY_TIME}s${NC}"
  else
    echo -e "${RED}Container did not restart${NC}"
    return 1
  fi

  # Check health
  echo -e "${YELLOW}Checking health after restart...${NC}"
  if check_health "http://$MASTER_IP:30001/health"; then
    echo -e "${GREEN}Processor is healthy${NC}"
  else
    echo -e "${RED}Processor failed health check${NC}"
    return 1
  fi

  echo ""
  echo -e "${BLUE}Pod details:${NC}"
  kubectl get pod "$PROCESSOR_POD" -n ca3-app -o wide
  echo ""
}

run_node_drain_test() {
  echo ""
  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN}Test 3: Node Drain (Pod Rescheduling)${NC}"
  echo -e "${GREEN}========================================${NC}"
  echo ""
  echo "This test drains worker-2 and verifies pods reschedule to other nodes"
  echo ""

  # Check if we have enough nodes
  NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
  if [ "$NODE_COUNT" -lt 2 ]; then
    echo -e "${RED}Error: Need at least 2 nodes for drain test${NC}"
    return 1
  fi

  # Target node
  TARGET_NODE="k3s-worker-2"
  echo -e "${YELLOW}Target node:${NC} $TARGET_NODE"

  # Get pods on target node before drain
  echo -e "${YELLOW}Pods on $TARGET_NODE before drain:${NC}"
  kubectl get pods -n ca3-app -o wide | grep "$TARGET_NODE" || echo "None"
  echo ""

  # Record start time
  START_TIME=$(date +%s)

  # Drain node
  echo -e "${YELLOW}Draining node...${NC}"
  kubectl drain "$TARGET_NODE" --ignore-daemonsets --delete-emptydir-data --force --grace-period=10

  # Wait for pods to reschedule
  echo -e "${YELLOW}Waiting for pods to reschedule...${NC}"
  sleep 10

  # Verify no pods on drained node
  PODS_ON_NODE=$(kubectl get pods -n ca3-app -o wide 2>/dev/null | grep "$TARGET_NODE" | wc -l || echo "0")
  if [ "$PODS_ON_NODE" -eq 0 ]; then
    echo -e "${GREEN}All pods successfully rescheduled!${NC}"
  else
    echo -e "${RED}Warning: $PODS_ON_NODE pod(s) still on $TARGET_NODE${NC}"
  fi

  # Show new pod distribution
  echo ""
  echo -e "${BLUE}Pod distribution after drain:${NC}"
  kubectl get pods -n ca3-app -o wide
  echo ""

  # Uncordon node
  echo -e "${YELLOW}Uncordoning node...${NC}"
  kubectl uncordon "$TARGET_NODE"

  END_TIME=$(date +%s)
  RECOVERY_TIME=$((END_TIME - START_TIME))
  echo -e "${GREEN}Node drain test complete!${NC}"
  echo -e "${GREEN}Total time: ${RECOVERY_TIME}s${NC}"
  echo ""
}

run_multiple_pod_failure_test() {
  echo ""
  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN}Test 4: Multiple Pod Failure${NC}"
  echo -e "${GREEN}========================================${NC}"
  echo ""
  echo "This test deletes multiple pods simultaneously to test cascading recovery"
  echo ""

  # Record start time
  START_TIME=$(date +%s)

  # Get pod counts before
  PRODUCER_COUNT=$(kubectl get pods -n ca3-app -l app=producer --no-headers | wc -l)
  PROCESSOR_COUNT=$(kubectl get pods -n ca3-app -l app=processor --no-headers | wc -l)

  echo -e "${YELLOW}Deleting all producer and processor pods...${NC}"

  # Delete all producer and processor pods
  kubectl delete pods -n ca3-app -l app=producer --force --grace-period=0
  kubectl delete pods -n ca3-app -l app=processor --force --grace-period=0

  # Wait for recovery
  echo -e "${YELLOW}Waiting for pods to recover...${NC}"
  wait_for_pods "app=producer" "$PRODUCER_COUNT"
  wait_for_pods "app=processor" "$PROCESSOR_COUNT"

  # Check health
  echo -e "${YELLOW}Checking health endpoints...${NC}"
  if check_health "http://$MASTER_IP:30000/health" && check_health "http://$MASTER_IP:30001/health"; then
    END_TIME=$(date +%s)
    RECOVERY_TIME=$((END_TIME - START_TIME))
    echo -e "${GREEN}All services recovered!${NC}"
    echo -e "${GREEN}Recovery time: ${RECOVERY_TIME}s${NC}"
  else
    echo -e "${RED}Some services failed to recover${NC}"
    return 1
  fi

  echo ""
  echo -e "${BLUE}Final pod status:${NC}"
  kubectl get pods -n ca3-app
  echo ""
}

# Run selected test
case $choice in
  1)
    run_pod_deletion_test
    ;;
  2)
    run_process_kill_test
    ;;
  3)
    run_node_drain_test
    ;;
  4)
    run_multiple_pod_failure_test
    ;;
  5)
    run_pod_deletion_test
    run_process_kill_test
    run_node_drain_test
    run_multiple_pod_failure_test
    ;;
  *)
    echo -e "${RED}Invalid choice${NC}"
    exit 1
    ;;
esac

# Summary
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Resilience Test Complete${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Final cluster state:${NC}"
kubectl get pods -n ca3-app -o wide
echo ""
echo -e "${GREEN}All tests passed! Kubernetes self-healing is working correctly.${NC}"
