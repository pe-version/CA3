#!/bin/bash
# Resilience Video Pre-Flight Checklist
# Test these commands before recording

# Use SSH to avoid TLS cert issues with public IP
MASTER="ubuntu@3.145.176.214"
SSH_KEY="~/.ssh/ca0-keys.pem"
KUBECTL="ssh -o StrictHostKeyChecking=no -i $SSH_KEY $MASTER sudo k3s kubectl"

# Verify current IP matches security group (Current: 185.203.218.49/32)

echo "========================================="
echo "1. SYSTEM HEALTH CHECK"
echo "========================================="
echo "All pods should be Running:"
$KUBECTL get pods -n ca3-app
echo ""
echo "Press Enter to continue..."; read

echo "========================================="
echo "2. TEST POD DELETION & RECOVERY"
echo "========================================="
echo "Current processor pods:"
$KUBECTL get pods -n ca3-app | grep processor
echo ""
echo "Deleting one processor pod..."
PROCESSOR_POD=$($KUBECTL get pods -n ca3-app -l app=processor -o jsonpath='{.items[0].metadata.name}')
$KUBECTL delete pod $PROCESSOR_POD -n ca3-app
echo ""
echo "Watch it come back (Ctrl+C when Running):"
$KUBECTL get pods -n ca3-app -w | grep processor

echo ""
echo "Press Enter to continue..."; read

echo "========================================="
echo "3. TEST STATEFULSET PERSISTENCE (MongoDB)"
echo "========================================="
echo "Check current data in MongoDB:"
$KUBECTL exec -n ca3-app mongodb-0 -- mongosh --tls --tlsCAFile /etc/mongodb/certs/ca.crt --eval "db.getSiblingDB('metals').prices.countDocuments()"
echo ""
echo "Current PVCs (should exist):"
$KUBECTL get pvc -n ca3-app | grep mongodb
echo ""
echo "Delete MongoDB pod..."
$KUBECTL delete pod mongodb-0 -n ca3-app
echo ""
echo "Waiting for MongoDB to come back..."
$KUBECTL wait --for=condition=ready pod/mongodb-0 -n ca3-app --timeout=120s
echo ""
echo "Check data still exists after restart:"
$KUBECTL exec -n ca3-app mongodb-0 -- mongosh --tls --tlsCAFile /etc/mongodb/certs/ca.crt --eval "db.getSiblingDB('metals').prices.countDocuments()"
echo ""
echo "Data should be the same!"

echo ""
echo "Press Enter to continue..."; read

echo "========================================="
echo "4. TEST STATEFULSET PERSISTENCE (Kafka)"
echo "========================================="
echo "Current Kafka PVCs:"
$KUBECTL get pvc -n ca3-app | grep kafka
echo ""
echo "Delete Kafka pod..."
$KUBECTL delete pod kafka-0 -n ca3-app
echo ""
echo "Waiting for Kafka to come back..."
$KUBECTL wait --for=condition=ready pod/kafka-0 -n ca3-app --timeout=120s
echo ""
echo "Check Kafka topics still exist:"
$KUBECTL exec -n ca3-app kafka-0 -- kafka-topics --bootstrap-server localhost:9092 --list

echo ""
echo "Press Enter to continue..."; read

echo "========================================="
echo "5. TEST SYSTEM CONTINUES DURING FAILURE"
echo "========================================="
echo "Current metrics count:"
$KUBECTL exec -n ca3-app mongodb-0 -- mongosh --tls --tlsCAFile /etc/mongodb/certs/ca.crt --eval "db.getSiblingDB('metals').prices.countDocuments()"
echo ""
echo "Delete processor pod (system should keep working)..."
$KUBECTL delete pod $($KUBECTL get pods -n ca3-app -l app=processor -o jsonpath='{.items[0].metadata.name}') -n ca3-app
echo ""
echo "Wait 30 seconds for recovery..."
sleep 30
echo ""
echo "New metrics count (should have increased despite failure):"
$KUBECTL exec -n ca3-app mongodb-0 -- mongosh --tls --tlsCAFile /etc/mongodb/certs/ca.crt --eval "db.getSiblingDB('metals').prices.countDocuments()"

echo ""
echo "Press Enter to continue..."; read

echo "========================================="
echo "6. HPA STATUS CHECK"
echo "========================================="
echo "Current HPA status:"
$KUBECTL get hpa -n ca3-app
echo ""
echo "HPA should show current replicas and be ready to scale"

echo ""
echo "========================================="
echo "PRE-FLIGHT CHECK COMPLETE!"
echo "========================================="
echo "If all tests passed, you're ready to record!"
echo ""
echo "For the video, you'll demonstrate:"
echo "1. Delete processor pod → watch it recover"
echo "2. Delete MongoDB pod → verify data persists"
echo "3. Delete Kafka pod → verify topics persist"
echo "4. Show system keeps processing during failures"
echo "5. (Optional) Trigger HPA scaling if load generator available"
