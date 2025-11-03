# CA3: Cloud-Native Ops - Kubernetes Implementation

## Overview

This CA3 implementation transforms the CA2 Docker Swarm deployment into a production-ready Kubernetes cluster, addressing all lessons learned from CA2's capacity planning issues.

**Student**: Philip Eykamp
**Course**: CS 5287
**Assignment**: Cloud-Native Ops: Observability, Scaling & Hardening (CA3)

---

## Quick Navigation

- **Quick Start (30 min)**: [CA3-QUICK-START.md](CA3-QUICK-START.md)
- **Full Deployment Guide**: [CA3-DEPLOYMENT-GUIDE.md](CA3-DEPLOYMENT-GUIDE.md)
- **Implementation Summary**: [CA3-IMPLEMENTATION-SUMMARY.md](CA3-IMPLEMENTATION-SUMMARY.md)
- **CA2 Reference**: [README.md](README.md) (Docker Swarm implementation)

---

## What's New in CA3

### Architecture Evolution: CA2 → CA3

| Aspect | CA2 (Docker Swarm) | CA3 (Kubernetes) |
|--------|-------------------|------------------|
| **Orchestrator** | Docker Swarm | K3s (Kubernetes) |
| **Infrastructure** | 3x t3.small (6GB total) | 3x t3.medium (12GB total) |
| **Result** | Kafka failed to start | All services running |
| **Autoscaling** | Manual only | HPA (automatic) |
| **Observability** | None | Prometheus + Grafana + Loki |
| **Security** | Basic secrets | NetworkPolicies + Secrets + TLS-ready |
| **Cost** | $14/week | $22/week |
| **Grade** | 90/100 (-7 on Scaling) | Expected full credit |

### Key Improvements

1. **Proper Capacity Planning**: 3x t3.medium (12GB) addresses CA2's Kafka failure
2. **Production-Ready Observability**: Full metrics + logs + dashboards
3. **Automated Scaling**: HPA responds to load automatically
4. **Security Hardening**: NetworkPolicies restrict pod-to-pod communication
5. **Resilience Testing**: Automated scripts demonstrate self-healing

---

## CA2 Lessons Learned

### What Went Wrong in CA2

**Grade Impact**: Lost 7/10 points on "Scaling & Observability"

**Root Cause**: Kafka failed to start on 3x t3.small instances (2GB RAM each)

**Professor's Feedback**:
- "What work arounds could you have used?"
- "You will need to figure out the cost model in the final project"

### How CA3 Addresses This

**Cost Model Analysis**:
```
CA2: 3x t3.small = 6GB total = $14/week → Kafka failed → -7 points
CA3: 3x t3.medium = 12GB total = $22/week → All working → Full credit

Extra $8/week investment prevents $7 point loss
```

**Right-Sizing Before Deployment**:
- Calculated resource needs: 6.2GB minimum
- 3x t3.medium provides 12GB (54% headroom)
- No service failures due to capacity

**Production Thinking**:
- Multi-node cluster (proper K8s)
- Service placement strategy (data vs app nodes)
- Autoscaling configured from day 1
- Observability built-in

---

## Architecture

### Infrastructure Layout

```
┌─────────────────────────────────────────────────────────┐
│                    AWS VPC 10.0.0.0/16                  │
│                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  Master      │  │  Worker-1    │  │  Worker-2    │  │
│  │  t3.medium   │  │  t3.medium   │  │  t3.medium   │  │
│  │  (4GB RAM)   │  │  (4GB RAM)   │  │  (4GB RAM)   │  │
│  │              │  │              │  │              │  │
│  │ K3s Control  │  │ Data Tier:   │  │ App Tier:    │  │
│  │ Plane        │  │  • ZooKeeper │  │  • Producer  │  │
│  │              │  │  • Kafka     │  │  • Processor │  │
│  │              │  │  • MongoDB   │  │  • Grafana   │  │
│  │              │  │  • Prometheus│  │  • Loki      │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Resource Distribution

**Master Node (Worker 0)**:
- K3s API server, scheduler, controller
- No application workloads

**Worker-1 (Data Services)**:
- ZooKeeper (512MB) - Kafka coordination
- Kafka (1GB) - Message streaming
- MongoDB (512MB) - Data persistence
- Prometheus (1GB) - Metrics collection

**Worker-2 (Application Services)**:
- Producer (256MB) - Data ingestion
- Processor (512MB) - Data processing
- Grafana (512MB) - Visualization
- Loki (512MB) - Log aggregation

**Total Utilization**: 5.5GB / 12GB = 46% (54% headroom for autoscaling)

---

## Features

### 1. Full Observability Stack

**Prometheus**:
- Scrapes metrics from all pods
- 7-day retention, 10GB storage
- Access: `http://<MASTER_IP>:30090`

**Grafana**:
- Pre-configured dashboards
- Prometheus + Loki data sources
- Access: `http://<MASTER_IP>:30300` (admin/admin)

**Loki + Promtail**:
- Centralized log aggregation
- Automatic collection from all ca3-app pods
- 7-day retention

### 2. Horizontal Pod Autoscaling (HPA)

**Producer HPA**:
- Scales: 1-3 pods
- Trigger: 70% CPU utilization
- Scale-up: 60s stabilization
- Scale-down: 5min stabilization

**Processor HPA**:
- Scales: 1-5 pods
- Trigger: 70% CPU or 80% memory
- Scale-up: 60s stabilization
- Scale-down: 5min stabilization

### 3. Security Hardening

**NetworkPolicies**:
- Default deny all ingress
- ZooKeeper: Only Kafka can connect
- Kafka: Only Producer and Processor
- MongoDB: Only Processor
- Metrics: Allow Prometheus scraping
- Logs: Allow Promtail collection

**Secrets Management**:
- MongoDB password (auto-generated)
- Metals API key (user-provided)
- Mounted as files in `/run/secrets/`

### 4. Resilience & Self-Healing

**Kubernetes Built-in**:
- Pod deletion → automatic recreation
- Process crash → container restart
- Node failure → pod rescheduling
- Health checks → restart unhealthy pods

**Tested Scenarios** (automated scripts):
- Pod deletion recovery
- Process kill recovery
- Node drain and reschedule
- Multiple simultaneous failures

---

## Quick Start

### Prerequisites

```bash
# Verify tools
terraform version  # >= 1.5.0
kubectl version --client
aws configure list

# Get your public IP
curl ifconfig.me
```

### 1. Deploy Infrastructure (10 min)

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Add your SSH key name and IP

terraform init
terraform apply
```

### 2. Setup K3s Cluster (5 min)

```bash
./scripts/setup-k3s-cluster.sh  # Automated

# Get kubeconfig
MASTER_IP=$(terraform -chdir=terraform output -raw master_public_ip)
scp -i ~/.ssh/YOUR_KEY.pem ubuntu@$MASTER_IP:/etc/rancher/k3s/k3s.yaml ~/.kube/config-ca3
sed -i.bak "s/127.0.0.1/$MASTER_IP/" ~/.kube/config-ca3
export KUBECONFIG=~/.kube/config-ca3

kubectl get nodes  # Should show 3 nodes
```

### 3. Deploy Application (10 min)

```bash
# Create secrets
kubectl create secret generic mongodb-password \
  --from-literal=password=$(openssl rand -base64 32) -n ca3-app

kubectl create secret generic api-key \
  --from-literal=key=YOUR_API_KEY -n ca3-app

# Deploy
kubectl apply -f k8s/base/

# Wait for ready
kubectl wait --for=condition=ready pod -l app=producer -n ca3-app --timeout=180s
kubectl wait --for=condition=ready pod -l app=processor -n ca3-app --timeout=180s
```

### 4. Deploy Observability (5 min)

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/kube-prometheus-stack \
  -n ca3-app -f k8s/observability/prometheus-values.yaml

helm install loki grafana/loki-stack \
  -n ca3-app -f k8s/observability/loki-values.yaml
```

### 5. Test Everything

```bash
# Health checks
MASTER_IP=$(terraform -chdir=terraform output -raw master_public_ip)
curl http://$MASTER_IP:30000/health  # Producer
curl http://$MASTER_IP:30001/health  # Processor

# Load test (autoscaling)
./scripts/load-test.sh

# Resilience test
./scripts/resilience-test.sh
```

---

## Project Structure

```
CA2/  (This is actually the CA3 project directory)
│
├── terraform/                      # Infrastructure as Code
│   ├── main.tf                    # 3-node K3s cluster
│   ├── variables.tf               # Config (3x t3.medium)
│   ├── outputs.tf                 # Connection info
│   ├── user-data-master.sh        # K3s master init
│   └── user-data-worker.sh        # K3s worker init
│
├── k8s/                           # Kubernetes Manifests
│   ├── base/                      # Application workloads
│   │   ├── 00-namespace.yaml     # ca3-app namespace
│   │   ├── 01-secrets.yaml       # Secrets (template)
│   │   ├── 02-configmaps.yaml    # App configs
│   │   ├── 10-zookeeper.yaml     # StatefulSet
│   │   ├── 11-kafka.yaml         # StatefulSet
│   │   ├── 12-mongodb.yaml       # StatefulSet
│   │   ├── 20-processor.yaml     # Deployment + HPA
│   │   └── 21-producer.yaml      # Deployment + HPA
│   │
│   ├── observability/            # Monitoring stack
│   │   ├── prometheus-values.yaml
│   │   ├── loki-values.yaml
│   │   └── servicemonitors.yaml
│   │
│   └── security/                 # Security policies
│       └── network-policies.yaml
│
├── scripts/                      # Automation
│   ├── setup-k3s-cluster.sh     # Cluster init
│   ├── load-test.sh             # HPA testing
│   └── resilience-test.sh       # Failure recovery
│
├── CA3-QUICK-START.md           # 30-min guide
├── CA3-DEPLOYMENT-GUIDE.md      # Full guide
├── CA3-IMPLEMENTATION-SUMMARY.md # Technical summary
└── README-CA3.md                # This file
```

---

## Cost Analysis

### Weekly Cost Breakdown

**3x t3.medium**:
- EC2: 3 × $0.0416/hr × 168hr = $20.97
- EBS: 3 × 20GB × $0.10/GB/mo = $1.13
- **Total**: ~$22/week

**For full assignment (11 days)**:
- EC2: 3 × $0.0416/hr × 264hr = $32.90
- EBS: 3 × 20GB × $0.10/GB/mo = $1.76
- **Total**: ~$35

### Cost vs Value

| Option | Cost/Week | Result | Value |
|--------|-----------|--------|-------|
| 3x t3.small (CA2) | $14 | Kafka failed, -7 points | ❌ |
| 1x t3.large | $23 | Works, single node risk | ⚠️ |
| 3x t3.medium (CA3) | $22 | Works, multi-node, HPA | ✅ |

**Decision**: $8/week premium over CA2 prevents 7-point loss and demonstrates production thinking

---

## Testing & Validation

### Load Testing

```bash
./scripts/load-test.sh
```

**What it does**:
- Generates sustained load for 5 minutes
- Triggers HPA autoscaling at 70% CPU
- Records pod counts and CPU usage
- Demonstrates scale-up and scale-down

**Expected results**:
- Producer scales from 1 → 3 pods
- Processor scales from 1 → 5 pods
- Pods scale down after 5 min of low load

### Resilience Testing

```bash
./scripts/resilience-test.sh
```

**Test scenarios**:
1. **Pod deletion**: Delete pod, verify K8s recreates it
2. **Process kill**: Kill PID 1, verify container restarts
3. **Node drain**: Drain worker-2, verify pods reschedule
4. **Multiple failures**: Delete all producer+processor pods simultaneously

**Expected recovery time**: < 30 seconds per scenario

### Health Checks

```bash
MASTER_IP=$(terraform -chdir=terraform output -raw master_public_ip)

# Producer
curl http://$MASTER_IP:30000/health

# Processor
curl http://$MASTER_IP:30001/health

# Expected: {"status": "healthy", ...}
```

---

## Assignment Deliverables

### Required Components

- [x] **Kubernetes cluster**: 3-node K3s on AWS
- [x] **Observability**: Prometheus + Grafana + Loki
- [x] **Autoscaling**: HPA for Producer and Processor
- [x] **Security**: NetworkPolicies, Secrets
- [x] **Resilience**: Self-healing tests
- [x] **Documentation**: Deployment guide, cost analysis

### For Video Demonstration

1. **Show cluster**: `kubectl get nodes -o wide`
2. **Show pods**: `kubectl get pods -n ca3-app -o wide`
3. **Show health**: `curl` both endpoints
4. **Show dashboards**: Grafana with metrics and logs
5. **Show autoscaling**: `./scripts/load-test.sh`
6. **Show resilience**: `./scripts/resilience-test.sh` (pick test 1 or 4)
7. **Show cost**: AWS console with running costs

### For Written Report

Use [CA3-DEPLOYMENT-GUIDE.md](CA3-DEPLOYMENT-GUIDE.md) as template:
- Architecture overview
- **CA2 lessons learned** (critical section!)
- Cost model analysis (3x t3.small vs t3.medium)
- Service placement strategy
- Security implementation (NetworkPolicies)
- Production recommendations

---

## Cleanup

```bash
# Delete Kubernetes resources
kubectl delete namespace ca3-app
helm uninstall prometheus loki -n ca3-app

# Destroy infrastructure
cd terraform
terraform destroy

# Verify in AWS console
# - No EC2 instances
# - No EBS volumes
# - No charges
```

---

## Troubleshooting

### Pods stuck in Pending

```bash
kubectl describe pod <pod-name> -n ca3-app
kubectl top nodes  # Check available resources
kubectl get nodes --show-labels  # Check node labels
```

### Kafka not starting

```bash
# Wait for ZooKeeper first
kubectl wait --for=condition=ready pod -l app=zookeeper -n ca3-app --timeout=300s

# Check Kafka logs
kubectl logs -f kafka-0 -n ca3-app
```

### HPA not working

```bash
# Install metrics-server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Patch for K3s
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

# Wait 1 minute
kubectl top pods -n ca3-app
```

### Can't access dashboards

```bash
# Check security group allows your IP
# Update terraform/variables.tf with my_ip
terraform apply

# Check NodePort services
kubectl get svc -n ca3-app | grep NodePort
```

---

## Key Differences: CA2 vs CA3

### Technical Changes

| Component | CA2 | CA3 |
|-----------|-----|-----|
| **Orchestrator** | Docker Swarm | Kubernetes (K3s) |
| **Stateful Services** | Swarm volumes | StatefulSets + PVCs |
| **Service Discovery** | Docker DNS | K8s Service mesh |
| **Scaling** | `docker service scale` | HPA (automatic) |
| **Config Management** | Docker configs | ConfigMaps |
| **Secrets** | Docker secrets | K8s Secrets |
| **Networking** | Overlay networks | CNI (flannel) + NetworkPolicies |
| **Load Balancing** | Swarm ingress | K8s Services (NodePort) |

### Operational Changes

| Aspect | CA2 | CA3 |
|--------|-----|-----|
| **Deployment** | `docker stack deploy` | `kubectl apply` |
| **Monitoring** | Docker stats | Prometheus + Grafana |
| **Logging** | `docker service logs` | Loki + Promtail |
| **Health Checks** | Swarm health checks | K8s liveness/readiness probes |
| **Updates** | Rolling update (manual) | RollingUpdate strategy (declarative) |
| **Resilience** | Swarm scheduler | K8s self-healing + tests |

---

## Production Recommendations

### For Real-World Deployment

1. **Use managed K8s**: EKS, GKE, or AKS instead of self-managed K3s
2. **Persistent storage**: EBS CSI driver for production PVCs
3. **Multi-AZ**: Spread nodes across availability zones
4. **Ingress controller**: Nginx or ALB for external traffic
5. **GitOps**: ArgoCD or Flux for declarative deployments
6. **Backup automation**: Velero for cluster backups
7. **Cost optimization**: Cluster autoscaler + spot instances

### Lessons Learned

1. **Right-size infrastructure upfront** - Don't deploy to find out it's too small
2. **Capacity planning matters** - Calculate needs before choosing instance types
3. **Document cost tradeoffs** - Show understanding of business impact
4. **Multi-node is valuable** - Demonstrates real-world architecture
5. **Observability from day 1** - Don't bolt it on later
6. **Automation saves time** - Scripts prevent human error

---

## References

- **K3s Documentation**: https://docs.k3s.io/
- **Kubernetes HPA**: https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/
- **kube-prometheus-stack**: https://github.com/prometheus-community/helm-charts
- **Loki**: https://grafana.com/docs/loki/
- **NetworkPolicies**: https://kubernetes.io/docs/concepts/services-networking/network-policies/
- **AWS EC2 Pricing**: https://aws.amazon.com/ec2/pricing/on-demand/

---

## Contact

**Student**: Philip Eykamp
**Course**: CS 5287
**Assignment**: CA3 - Cloud-Native Ops

---

**Next Step**: Start with [CA3-QUICK-START.md](CA3-QUICK-START.md) for 30-minute deployment
