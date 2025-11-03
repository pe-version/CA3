# CA3 Deployment Guide: 3-Node K3s Cluster on AWS

## Overview

This guide deploys a production-like Kubernetes cluster with proper multi-node architecture, addressing the capacity planning lessons learned from CA2.

### Architecture Decision: Why 3x t3.medium?

**CA2 Lesson Learned**: The CA2 submission lost 7/10 points on "Scaling & Observability" because Kafka failed to run on undersized t3.small instances (2GB RAM each, 6GB total). The professor's feedback emphasized understanding the "cost model" - knowing how to right-size infrastructure for specific workloads.

**CA3 Approach**:
- **3x t3.medium** (4GB RAM each, 12GB total)
- Proper multi-node Kubernetes cluster (1 master + 2 workers)
- Service placement strategy based on resource needs
- 54% headroom for autoscaling and safety margin

**Resource Distribution**:
```
Node 1 (Master): K3s control plane (512MB) + overhead
Node 2 (Worker-1): Kafka (1GB) + ZooKeeper (512MB) + MongoDB (512MB) + Prometheus (1GB)
Node 3 (Worker-2): Producer (256MB) + Processor (512MB) + Grafana (512MB) + Loki (512MB)

Total Utilization: 5.5GB / 12GB = 46% (54% headroom for scaling)
```

**Cost Analysis**:
- 1 week runtime: ~$22
- Full assignment period (11 days): ~$35
- Demonstrates understanding of capacity planning and cost tradeoffs

---

## Prerequisites

1. **AWS Account** with CLI configured
   ```bash
   aws configure
   ```

2. **Terraform** installed (>= 1.5.0)
   ```bash
   terraform version
   ```

3. **kubectl** installed
   ```bash
   kubectl version --client
   ```

4. **SSH Key Pair** in AWS
   ```bash
   # Create new key pair
   aws ec2 create-key-pair --key-name ca3-k3s \
     --query 'KeyMaterial' --output text > ~/.ssh/ca3-k3s.pem
   chmod 400 ~/.ssh/ca3-k3s.pem
   ```

5. **Your public IP** for SSH access
   ```bash
   curl ifconfig.me
   ```

---

## Step 1: Infrastructure Setup (15 minutes)

### 1.1 Configure Terraform Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
ssh_key_name = "ca3-k3s"
my_ip = "YOUR.IP.ADDRESS/32"  # Replace with output from: curl ifconfig.me
```

### 1.2 Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Deploy (creates 3x t3.medium instances)
terraform apply
```

**Expected output**: 3 EC2 instances with public IPs

### 1.3 Setup K3s Cluster

```bash
# From project root
./scripts/setup-k3s-cluster.sh
```

This script will:
1. Wait for SSH access to all nodes
2. Wait for K3s master installation
3. Retrieve cluster token
4. Join worker nodes
5. Label nodes for workload placement

**Expected output**: All 3 nodes in Ready state

### 1.4 Configure Local kubectl

```bash
# Get kubeconfig from master
MASTER_IP=$(terraform -chdir=terraform output -raw master_public_ip)
scp -i ~/.ssh/ca3-k3s.pem ubuntu@$MASTER_IP:/etc/rancher/k3s/k3s.yaml ~/.kube/config-ca3

# Edit kubeconfig - replace 127.0.0.1 with master IP
sed -i.bak "s/127.0.0.1/$MASTER_IP/" ~/.kube/config-ca3

# Export kubeconfig
export KUBECONFIG=~/.kube/config-ca3

# Verify cluster access
kubectl get nodes
```

**Expected output**:
```
NAME          STATUS   ROLES                  AGE   VERSION
k3s-master    Ready    control-plane,master   10m   v1.28.x
k3s-worker-1  Ready    worker                 8m    v1.28.x
k3s-worker-2  Ready    worker                 8m    v1.28.x
```

---

## Step 2: Deploy Application (10 minutes)

### 2.1 Create Secrets

```bash
# MongoDB password
kubectl create secret generic mongodb-password \
  --from-literal=password=$(openssl rand -base64 32) \
  -n ca3-app

# Metals API key (get from https://metals-api.com/)
kubectl create secret generic api-key \
  --from-literal=key=YOUR_API_KEY_HERE \
  -n ca3-app
```

### 2.2 Deploy Base Services

```bash
# Deploy in order (wait for each to be ready)
kubectl apply -f k8s/base/00-namespace.yaml
kubectl apply -f k8s/base/02-configmaps.yaml

# Deploy data tier (ZooKeeper, Kafka, MongoDB)
kubectl apply -f k8s/base/10-zookeeper.yaml
kubectl wait --for=condition=ready pod -l app=zookeeper -n ca3-app --timeout=300s

kubectl apply -f k8s/base/11-kafka.yaml
kubectl wait --for=condition=ready pod -l app=kafka -n ca3-app --timeout=300s

kubectl apply -f k8s/base/12-mongodb.yaml
kubectl wait --for=condition=ready pod -l app=mongodb -n ca3-app --timeout=300s

# Deploy application tier (Producer, Processor)
kubectl apply -f k8s/base/21-producer.yaml
kubectl apply -f k8s/base/20-processor.yaml

# Wait for applications to be ready
kubectl wait --for=condition=ready pod -l app=producer -n ca3-app --timeout=180s
kubectl wait --for=condition=ready pod -l app=processor -n ca3-app --timeout=180s
```

### 2.3 Verify Deployment

```bash
# Check all pods
kubectl get pods -n ca3-app -o wide

# Check services
kubectl get svc -n ca3-app

# Check HPA status
kubectl get hpa -n ca3-app

# Test health endpoints
MASTER_IP=$(terraform -chdir=terraform output -raw master_public_ip)
curl http://$MASTER_IP:30000/health  # Producer
curl http://$MASTER_IP:30001/health  # Processor
```

**Expected output**: All pods Running, health checks return 200 OK

---

## Step 3: Deploy Observability Stack (15 minutes)

### 3.1 Install Prometheus + Grafana (kube-prometheus-stack)

```bash
# Add Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install kube-prometheus-stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace ca3-app \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set grafana.adminPassword=admin \
  --set prometheus.service.type=NodePort \
  --set prometheus.service.nodePort=30090 \
  --set grafana.service.type=NodePort \
  --set grafana.service.nodePort=30300

# Wait for deployment
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n ca3-app --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n ca3-app --timeout=300s
```

### 3.2 Deploy Loki + Promtail

```bash
# Add Grafana Helm repo
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Loki
helm install loki grafana/loki-stack \
  --namespace ca3-app \
  --set promtail.enabled=true \
  --set loki.persistence.enabled=true \
  --set loki.persistence.size=5Gi

# Wait for deployment
kubectl wait --for=condition=ready pod -l app=loki -n ca3-app --timeout=300s
```

### 3.3 Access Dashboards

```bash
MASTER_IP=$(terraform -chdir=terraform output -raw master_public_ip)

echo "Grafana: http://$MASTER_IP:30300 (admin/admin)"
echo "Prometheus: http://$MASTER_IP:30090"
```

**Grafana Setup**:
1. Login with admin/admin
2. Add Loki data source: http://loki:3100
3. Import dashboards:
   - Kubernetes Cluster Monitoring (ID: 7249)
   - Node Exporter Full (ID: 1860)
   - Kafka Overview (ID: 7589)

---

## Step 4: Configure Autoscaling & Load Testing (10 minutes)

### 4.1 Verify HPA is Working

```bash
# Check HPA status
kubectl get hpa -n ca3-app

# Watch HPA in real-time
kubectl get hpa -n ca3-app -w
```

### 4.2 Load Testing Script

Create `scripts/load-test.sh`:
```bash
#!/bin/bash
MASTER_IP=$(terraform -chdir=terraform output -raw master_public_ip)

echo "Generating load on producer..."
for i in {1..1000}; do
  curl -s http://$MASTER_IP:30000/health > /dev/null &
done

echo "Generating load on processor..."
for i in {1..1000}; do
  curl -s http://$MASTER_IP:30001/health > /dev/null &
done

echo "Load test started. Monitor with: kubectl get hpa -n ca3-app -w"
```

```bash
chmod +x scripts/load-test.sh
./scripts/load-test.sh
```

### 4.3 Monitor Autoscaling

```bash
# Watch pod scaling
watch kubectl get pods -n ca3-app

# Check HPA events
kubectl describe hpa producer-hpa -n ca3-app
kubectl describe hpa processor-hpa -n ca3-app
```

**Expected behavior**: Pods should scale up to 3 (producer) and 5 (processor) under load, then scale down after 5 minutes.

---

## Step 5: Security Hardening (15 minutes)

### 5.1 Network Policies

Deploy network policies to restrict pod-to-pod communication:

```bash
kubectl apply -f k8s/security/network-policies.yaml
```

### 5.2 TLS with cert-manager

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Wait for cert-manager
kubectl wait --for=condition=ready pod -l app=cert-manager -n cert-manager --timeout=300s

# Apply certificates
kubectl apply -f k8s/security/certificates.yaml
```

---

## Step 6: Resilience Testing & Video Demo (30 minutes)

### 6.1 Resilience Test Scenarios

**Scenario 1: Pod Deletion**
```bash
# Delete a producer pod
kubectl delete pod -l app=producer -n ca3-app --force

# Watch recovery
kubectl get pods -n ca3-app -w
```

**Scenario 2: Process Kill**
```bash
# Get into processor pod
PROCESSOR_POD=$(kubectl get pod -n ca3-app -l app=processor -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $PROCESSOR_POD -n ca3-app -- sh

# Kill main process
kill 1

# Exit and watch recovery
kubectl get pods -n ca3-app -w
```

**Scenario 3: Node Drain (simulated node failure)**
```bash
# Drain worker-2
kubectl drain k3s-worker-2 --ignore-daemonsets --delete-emptydir-data

# Watch pods reschedule
kubectl get pods -n ca3-app -o wide -w

# Uncordon node
kubectl uncordon k3s-worker-2
```

### 6.2 Video Demo Checklist

Record screen showing:
1. **Cluster Status**: `kubectl get nodes -o wide`
2. **Application Pods**: `kubectl get pods -n ca3-app -o wide`
3. **Health Checks**: curl both endpoints showing 200 OK
4. **Grafana Dashboards**: Show metrics, logs, system health
5. **Resilience Test**: Delete pod, show recovery in < 30s
6. **Autoscaling Demo**: Run load test, show HPA scaling up/down
7. **Network Policies**: Show blocked traffic between isolated pods
8. **Cost Analysis**: Show AWS console with running costs

---

## Step 7: Cleanup

### 7.1 Destroy Infrastructure

```bash
# Delete Kubernetes resources first (to release EBS volumes)
kubectl delete namespace ca3-app
helm uninstall prometheus -n ca3-app
helm uninstall loki -n ca3-app

# Destroy Terraform infrastructure
cd terraform
terraform destroy
```

### 7.2 Cost Verification

Check AWS console:
- EC2 instances terminated
- EBS volumes deleted
- No running resources

---

## Troubleshooting

### Pods stuck in Pending

```bash
# Check events
kubectl describe pod <pod-name> -n ca3-app

# Check node resources
kubectl top nodes

# Common issue: Insufficient resources
# Solution: Verify node labels and affinity rules
```

### Kafka not starting

```bash
# Check Kafka logs
kubectl logs -f kafka-0 -n ca3-app

# Common issue: ZooKeeper not ready
# Solution: Wait for ZooKeeper first
kubectl wait --for=condition=ready pod -l app=zookeeper -n ca3-app --timeout=300s
```

### HPA not scaling

```bash
# Check metrics-server is running
kubectl get deployment metrics-server -n kube-system

# If not, install it
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Patch metrics-server for K3s
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'
```

### Can't access dashboards

```bash
# Check NodePort services
kubectl get svc -n ca3-app | grep NodePort

# Check security group allows traffic
MASTER_IP=$(terraform -chdir=terraform output -raw master_public_ip)
curl -v http://$MASTER_IP:30300
```

---

## Cost Model Analysis (for CA3 Report)

### CA2 vs CA3 Comparison

| Aspect | CA2 (Failed) | CA3 (Success) |
|--------|--------------|---------------|
| **Instance Type** | 3x t3.small | 3x t3.medium |
| **Total RAM** | 6GB | 12GB |
| **Kafka Status** | Failed to start | Running stable |
| **Utilization** | 103% (overcommitted) | 46% (safe headroom) |
| **Cost (1 week)** | $14 | $22 |
| **Cost (11 days)** | $22 | $35 |
| **Grade Impact** | -7 points | Expected full credit |

### Key Learnings

1. **Right-sizing matters**: +$8/week investment prevents service failures
2. **Capacity planning**: 54% headroom allows for autoscaling and spikes
3. **Service placement**: Heterogeneous node roles optimize resource usage
4. **Production thinking**: Multi-node cluster demonstrates real-world architecture

### Cost Optimization Strategies

**What we did**:
- K3s instead of full K8s (lower overhead)
- Single-replica stateful services (ZK, Kafka, Mongo)
- Loki instead of EFK (lighter weight)

**Alternative approaches considered**:
- 1x t3.large: $23/week but single point of failure
- Oracle Cloud Free Tier: $0 but signup failed
- 3x t3.small: $14/week but insufficient capacity (CA2 mistake)

---

## Assignment Checklist

- [ ] Infrastructure deployed (3x t3.medium)
- [ ] K3s cluster running (1 master + 2 workers)
- [ ] All application pods Running
- [ ] Prometheus + Grafana deployed
- [ ] Loki + Promtail for logs
- [ ] HPA configured and tested
- [ ] Network Policies applied
- [ ] TLS certificates configured
- [ ] Resilience video recorded
- [ ] Documentation complete
- [ ] Cost analysis documented
- [ ] Infrastructure destroyed after submission

---

## References

- K3s Documentation: https://docs.k3s.io/
- kube-prometheus-stack: https://github.com/prometheus-community/helm-charts
- Loki: https://grafana.com/docs/loki/
- Kubernetes HPA: https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/
- AWS EC2 Pricing: https://aws.amazon.com/ec2/pricing/on-demand/
