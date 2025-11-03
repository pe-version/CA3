# CA3 Quick Start Guide

## TL;DR - Get Running in 30 Minutes

This is the condensed version of the deployment guide. For detailed explanations, see [CA3-DEPLOYMENT-GUIDE.md](CA3-DEPLOYMENT-GUIDE.md).

### Prerequisites Check

```bash
# Verify tools are installed
terraform version    # Need >= 1.5.0
kubectl version --client
aws configure list   # Should show your credentials

# Get your public IP
curl ifconfig.me     # Save this for next step
```

### 1. Deploy Infrastructure (10 min)

```bash
cd terraform

# Configure
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Edit ssh_key_name and my_ip

# Deploy
terraform init
terraform apply  # Type 'yes' when prompted
```

### 2. Setup K3s Cluster (5 min)

```bash
cd ..
./scripts/setup-k3s-cluster.sh  # Automated cluster setup

# Get kubeconfig
MASTER_IP=$(terraform -chdir=terraform output -raw master_public_ip)
scp -i ~/.ssh/YOUR_KEY.pem ubuntu@$MASTER_IP:/etc/rancher/k3s/k3s.yaml ~/.kube/config-ca3
sed -i.bak "s/127.0.0.1/$MASTER_IP/" ~/.kube/config-ca3
export KUBECONFIG=~/.kube/config-ca3

# Verify
kubectl get nodes  # Should show 3 nodes Ready
```

### 3. Deploy Application (10 min)

```bash
# Create secrets (IMPORTANT: Replace placeholders!)
kubectl create secret generic mongodb-password \
  --from-literal=password=$(openssl rand -base64 32) -n ca3-app

kubectl create secret generic api-key \
  --from-literal=key=YOUR_METALS_API_KEY -n ca3-app  # Get from metals-api.com

# Deploy everything
kubectl apply -f k8s/base/

# Wait for pods
kubectl wait --for=condition=ready pod -l app=zookeeper -n ca3-app --timeout=300s
kubectl wait --for=condition=ready pod -l app=kafka -n ca3-app --timeout=300s
kubectl wait --for=condition=ready pod -l app=mongodb -n ca3-app --timeout=300s
kubectl wait --for=condition=ready pod -l app=producer -n ca3-app --timeout=180s
kubectl wait --for=condition=ready pod -l app=processor -n ca3-app --timeout=180s

# Verify
kubectl get pods -n ca3-app  # All should be Running
```

### 4. Deploy Observability (5 min)

```bash
# Add Helm repos
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Prometheus + Grafana
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n ca3-app -f k8s/observability/prometheus-values.yaml

# Install Loki
helm install loki grafana/loki-stack \
  -n ca3-app -f k8s/observability/loki-values.yaml

# Access dashboards
MASTER_IP=$(terraform -chdir=terraform output -raw master_public_ip)
echo "Grafana: http://$MASTER_IP:30300 (admin/admin)"
echo "Prometheus: http://$MASTER_IP:30090"
```

### 5. Test Everything

```bash
# Health checks
MASTER_IP=$(terraform -chdir=terraform output -raw master_public_ip)
curl http://$MASTER_IP:30000/health  # Producer
curl http://$MASTER_IP:30001/health  # Processor

# Run load test (triggers autoscaling)
./scripts/load-test.sh

# Run resilience tests
./scripts/resilience-test.sh
```

---

## What You Just Deployed

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    AWS VPC 10.0.0.0/16                  │
│                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  Master      │  │  Worker-1    │  │  Worker-2    │  │
│  │  t3.medium   │  │  t3.medium   │  │  t3.medium   │  │
│  │              │  │              │  │              │  │
│  │ K3s Control  │  │ ZooKeeper    │  │ Producer     │  │
│  │ Plane        │  │ Kafka        │  │ Processor    │  │
│  │              │  │ MongoDB      │  │ Grafana      │  │
│  │              │  │ Prometheus   │  │ Loki         │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Resource Distribution

- **Node 1 (Master)**: K3s API server, scheduler, controller-manager
- **Node 2 (Worker-1)**: Data services - Kafka, ZooKeeper, MongoDB, Prometheus
- **Node 3 (Worker-2)**: Application services - Producer, Processor, Grafana, Loki

### Cost Breakdown

```
3x t3.medium @ $0.0416/hr = $0.1248/hr
3x 20GB EBS @ $0.10/GB/mo = ~$0.0082/hr
Total: ~$0.133/hr = $3.19/day

1 week: $22.33
11 days: $35.09
```

---

## Common Commands

### Check cluster status
```bash
kubectl get nodes -o wide
kubectl get pods -n ca3-app -o wide
kubectl top nodes
kubectl top pods -n ca3-app
```

### Check HPA (autoscaling)
```bash
kubectl get hpa -n ca3-app
kubectl get hpa -n ca3-app -w  # Watch mode
```

### View logs
```bash
# Application logs
kubectl logs -f -l app=producer -n ca3-app
kubectl logs -f -l app=processor -n ca3-app

# Kafka logs
kubectl logs -f kafka-0 -n ca3-app
```

### Access services
```bash
MASTER_IP=$(terraform -chdir=terraform output -raw master_public_ip)

# Health endpoints
curl http://$MASTER_IP:30000/health  # Producer
curl http://$MASTER_IP:30001/health  # Processor

# Dashboards
open http://$MASTER_IP:30300  # Grafana (admin/admin)
open http://$MASTER_IP:30090  # Prometheus
```

### Debugging
```bash
# Describe pod for events
kubectl describe pod POD_NAME -n ca3-app

# Get into a pod
kubectl exec -it POD_NAME -n ca3-app -- sh

# Check resource usage
kubectl top pods -n ca3-app
kubectl describe node NODE_NAME
```

---

## Troubleshooting Quick Fixes

### Pods stuck in Pending
```bash
# Check what's wrong
kubectl describe pod POD_NAME -n ca3-app

# Common cause: Node selector can't be satisfied
# Fix: Check node labels
kubectl get nodes --show-labels
```

### Kafka won't start
```bash
# Make sure ZooKeeper is ready first
kubectl get pods -n ca3-app -l app=zookeeper

# Check Kafka logs
kubectl logs -f kafka-0 -n ca3-app

# Common issue: Insufficient memory
kubectl top nodes  # Should have headroom
```

### Can't access dashboards
```bash
# Check NodePort services
kubectl get svc -n ca3-app | grep NodePort

# Verify security group allows your IP
# Edit terraform/variables.tf and update my_ip
terraform apply
```

### HPA not working
```bash
# Install/patch metrics-server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

# Wait 1 minute, then check
kubectl top pods -n ca3-app
```

---

## Cleanup

```bash
# Delete application
kubectl delete namespace ca3-app

# Uninstall Helm charts
helm uninstall prometheus -n ca3-app
helm uninstall loki -n ca3-app

# Destroy infrastructure
cd terraform
terraform destroy  # Type 'yes' when prompted

# Verify in AWS console - no charges
```

---

## Next Steps

1. **For the assignment video**: Run `./scripts/resilience-test.sh` and record the screen
2. **For the report**: Document the cost model analysis (see CA3-DEPLOYMENT-GUIDE.md)
3. **For extra credit**: Implement TLS with cert-manager (see deployment guide)

---

## Getting Help

**If something fails**:
1. Check pod status: `kubectl get pods -n ca3-app`
2. Check pod events: `kubectl describe pod POD_NAME -n ca3-app`
3. Check logs: `kubectl logs POD_NAME -n ca3-app`
4. Check node resources: `kubectl top nodes`

**Common issues**:
- Pods pending → Not enough resources or node selector issue
- Pods CrashLoopBackOff → Check logs, usually config issue
- Can't access dashboards → Check security group allows your IP
- HPA not scaling → Install metrics-server (see troubleshooting)

**Still stuck?** Check the detailed guide: [CA3-DEPLOYMENT-GUIDE.md](CA3-DEPLOYMENT-GUIDE.md)
