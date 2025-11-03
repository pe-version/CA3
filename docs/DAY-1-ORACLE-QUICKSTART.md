# Day 1 Quick Start: Oracle Cloud Free Tier

## Overview

We're switching from AWS to **Oracle Cloud Always Free Tier** for CA3 to get:
- **FREE FOREVER** infrastructure (not just 12-month trial)
- **4 OCPUs + 12GB RAM** (more than 3x t3.large on AWS)
- **$0 cost** for the entire assignment (vs. $18-55 on AWS)

---

## Step-by-Step Guide (Total time: ~2 hours)

### Phase 1: Oracle Cloud Setup (30 minutes)

Follow the guide: [docs/oracle-cloud-setup.md](oracle-cloud-setup.md)

**TL;DR**:
1. Create Oracle Cloud account: https://www.oracle.com/cloud/free/
2. Create compartment "CA3-Metals-Pipeline"
3. Generate API keys for Terraform
4. Get your OCIDs (tenancy, user, compartment)
5. Note which Availability Domain has ARM capacity

**Required files after this step**:
- `~/.oci/config` - OCI configuration
- `~/.oci/oci_api_key.pem` - API private key
- `~/.ssh/oci_ca3` - SSH key for VM

---

### Phase 2: Deploy Infrastructure (15 minutes)

```bash
cd ~/Downloads/CA2/terraform-oci

# 1. Copy and edit variables
cp terraform.tfvars.example terraform.tfvars
vi terraform.tfvars

# Fill in (get from oracle-cloud-setup.md):
#   tenancy_ocid     = "ocid1.tenancy.oc1..aaaa..."
#   user_ocid        = "ocid1.user.oc1..aaaa..."
#   compartment_ocid = "ocid1.compartment.oc1..aaaa..."
#   availability_domain = "iKTz:US-ASHBURN-AD-1"  # Check which AD has capacity
#   ssh_public_key   = "<paste from: cat ~/.ssh/oci_ca3.pub>"

# 2. Run deployment script
cd ..
./scripts/oracle-deploy.sh

# This will:
# - Initialize Terraform
# - Create VCN (network)
# - Deploy VM.Standard.A1.Flex (4 OCPU, 12GB RAM, ARM64)
# - Configure security lists (firewall)
# - Output SSH command and IPs
```

**Expected output**:
```
✓ Terraform installed
✓ OCI config found
✓ OCI API key found
✓ terraform.tfvars found

Deployment Complete!

Instance IP: 129.213.xxx.xxx
SSH Command: ssh -i ~/.ssh/oci_ca3 ubuntu@129.213.xxx.xxx

Cost: $0.00/month (FREE FOREVER)
```

---

### Phase 3: Install K3s (10 minutes)

```bash
# 1. SSH into instance
ssh -i ~/.ssh/oci_ca3 ubuntu@<your-instance-ip>

# 2. Install K3s (Kubernetes lightweight distribution)
curl -sfL https://get.k3s.io | sh -

# Wait ~30 seconds for K3s to start

# 3. Verify K3s is running
sudo kubectl get nodes

# Expected output:
# NAME            STATUS   ROLES                  AGE   VERSION
# ca3-k3s-node    Ready    control-plane,master   1m    v1.28.x+k3s1

# 4. Check K3s services
sudo systemctl status k3s

# Should show "active (running)"
```

---

### Phase 4: Setup Local kubectl Access (15 minutes)

```bash
# On your LOCAL machine (not the instance):

# 1. Create kubeconfig directory
mkdir -p ~/.kube

# 2. Copy kubeconfig from instance
scp -i ~/.ssh/oci_ca3 ubuntu@<instance-ip>:/etc/rancher/k3s/k3s.yaml ~/.kube/oci-k3s.yaml

# 3. Replace 127.0.0.1 with your instance's public IP
# On Mac/Linux:
sed -i.bak "s/127.0.0.1/<instance-ip>/g" ~/.kube/oci-k3s.yaml

# On your machine, verify:
export KUBECONFIG=~/.kube/oci-k3s.yaml
kubectl get nodes

# Expected output:
# NAME           STATUS   ROLES                  AGE   VERSION
# ca3-k3s-node   Ready    control-plane,master   5m    v1.28.x+k3s1

# 4. Make this permanent (add to ~/.bashrc or ~/.zshrc):
echo "export KUBECONFIG=~/.kube/oci-k3s.yaml" >> ~/.zshrc
source ~/.zshrc
```

---

### Phase 5: Convert docker-compose to K8s Manifests (30 minutes)

We'll convert your CA2 docker-compose.yml to Kubernetes manifests:

```bash
cd ~/Downloads/CA2

# Create k8s directory
mkdir -p k8s

# We'll create manifests manually (kompose has issues with complex compose files)
```

I'll create the K8s manifests for you in the next step. These will include:
- Namespace
- ConfigMaps
- Secrets
- Deployments (producer, processor)
- StatefulSets (Kafka, ZooKeeper, MongoDB)
- Services
- PersistentVolumeClaims

---

### Phase 6: Deploy CA2 Pipeline to K3s (15 minutes)

```bash
# 1. Create namespace
kubectl create namespace metals-pipeline

# 2. Create secrets
kubectl create secret generic mongodb-password \
  --from-literal=password=SecureMongoP@ss123 \
  -n metals-pipeline

kubectl create secret generic kafka-password \
  --from-literal=password=KafkaAdm1nP@ss456 \
  -n metals-pipeline

kubectl create secret generic api-key \
  --from-literal=key=metals-api-key-placeholder \
  -n metals-pipeline

# 3. Deploy all services
kubectl apply -k k8s/

# 4. Wait for pods to start
watch kubectl get pods -n metals-pipeline

# Expected (after 2-3 minutes):
# NAME                        READY   STATUS    RESTARTS   AGE
# zookeeper-0                 1/1     Running   0          2m
# kafka-0                     1/1     Running   0          90s
# mongodb-0                   1/1     Running   0          90s
# processor-xxx-xxx           1/1     Running   0          60s
# producer-xxx-xxx            1/1     Running   0          60s
```

---

### Phase 7: Run Smoke Test (10 minutes)

```bash
# 1. Check all services are running
kubectl get all -n metals-pipeline

# 2. Check producer logs
kubectl logs -n metals-pipeline -l app=producer --tail=50

# Should see: "Connected to Kafka", "Message sent"

# 3. Check processor logs
kubectl logs -n metals-pipeline -l app=processor --tail=50

# Should see: "Connected to MongoDB", "Message processed"

# 4. Verify MongoDB has data
POD=$(kubectl get pod -n metals-pipeline -l app=mongodb -o jsonpath='{.items[0].metadata.name}')

kubectl exec -it $POD -n metals-pipeline -- mongosh -u admin -p SecureMongoP@ss123 metals --eval "db.prices.countDocuments()"

# Should show a number > 0

# 5. Send test messages
kubectl exec -it -n metals-pipeline deployment/producer -- curl -X POST http://localhost:8000/produce \
  -H "Content-Type: application/json" \
  -d '{"metal": "gold", "price": 1850.00}'

# 6. Screenshot everything
kubectl get pods -n metals-pipeline  # Screenshot this
kubectl get svc -n metals-pipeline   # Screenshot this
kubectl top pods -n metals-pipeline  # Screenshot this
```

---

## Success Criteria for Day 1

- [ ] Oracle Cloud account created (FREE tier)
- [ ] Infrastructure deployed via Terraform
- [ ] K3s installed and running (1 node)
- [ ] kubectl working from local machine
- [ ] All 5 pods running (zookeeper, kafka, mongodb, producer, processor)
- [ ] Messages flowing through pipeline
- [ ] MongoDB contains >100 documents
- [ ] Screenshots taken of:
  - `kubectl get nodes`
  - `kubectl get pods -n metals-pipeline`
  - `kubectl logs` showing successful processing
  - MongoDB count query

---

## Troubleshooting

### "Out of host capacity" during Terraform apply

Try different Availability Domains:
```bash
# In terraform.tfvars, change:
availability_domain = "iKTz:US-ASHBURN-AD-2"  # Try AD-2 instead of AD-1
# Or AD-3

# Then re-run:
./scripts/oracle-deploy.sh
```

### K3s pods stuck in "Pending"

Check resources:
```bash
kubectl describe pod <pod-name> -n metals-pipeline

# If "Insufficient memory" or "Insufficient CPU":
# Reduce resource limits in k8s manifests (we'll create these next)
```

### Can't connect from local kubectl

```bash
# Verify instance IP in kubeconfig:
grep server ~/.kube/oci-k3s.yaml

# Should show: https://<your-instance-ip>:6443
# If it shows 127.0.0.1, run the sed command again

# Test connectivity:
curl -k https://<instance-ip>:6443
# Should show: "Unauthorized" (good - K3s is responding)

# If connection refused, check firewall:
# OCI Console → Networking → Virtual Cloud Networks → Security Lists
# Ensure port 6443 ingress rule exists
```

### SSH connection refused

Wait 2-3 minutes after Terraform completes - cloud-init is still running.

```bash
# Check instance state:
cd terraform-oci
terraform output instance_state

# Should show: "RUNNING"

# If still failing, check security list allows SSH (port 22)
```

---

## Cost Verification

After deployment, verify you're using Free Tier:

1. Login to OCI Console: https://cloud.oracle.com/
2. **Hamburger menu** → **Governance** → **Cost Management** → **Cost Analysis**
3. Should show **$0.00** for today
4. Click on your instance → Should have **"Always Free"** badge

**Our resource usage**:
- ✅ 4 OCPUs (within 4 OCPU free limit)
- ✅ 12GB RAM (within 24GB free limit)
- ✅ 50GB storage (within 200GB free limit)
- ✅ 1 Public IP (2 free IPs included)

**Total: $0.00/month indefinitely**

---

## Next Steps (Day 2)

Once Day 1 is complete:
- Day 2: Instrument code with Prometheus metrics
- Day 3: Deploy Grafana + Prometheus
- Day 4: Deploy Loki for centralized logging
- Days 5-6: Autoscaling with HPA
- Days 7-8: Security hardening (NetworkPolicies, TLS)
- Day 9: Resilience video
- Days 10-11: Documentation and polish

---

## Time Tracking

| Phase | Estimated | Actual |
|-------|-----------|--------|
| Oracle account setup | 30 min | __ min |
| Terraform deployment | 15 min | __ min |
| K3s installation | 10 min | __ min |
| kubectl setup | 15 min | __ min |
| Manifest conversion | 30 min | __ min |
| Pipeline deployment | 15 min | __ min |
| Smoke testing | 10 min | __ min |
| **Total** | **2h 5min** | **__ h __min** |

---

## Comparison: Oracle vs AWS

| Metric | Oracle Free Tier | AWS t3.large (3x) |
|--------|------------------|-------------------|
| **vCPUs** | 4 OCPU (ARM) | 6 vCPU (x86) |
| **RAM** | 12GB | 24GB |
| **Storage** | 50GB | 60GB |
| **Cost (11 days)** | **$0.00** | **$55.00** |
| **Cost (monthly)** | **$0.00** | **$150.00** |
| **Time limit** | **∞ (forever)** | 12 months free tier |
| **Architecture** | ARM64 | x86_64 |

**For CA3, Oracle is the clear winner**: FREE forever, sufficient resources, perfect for learning.

---

Ready to proceed? Start with **Phase 1: Oracle Cloud Setup** using [docs/oracle-cloud-setup.md](oracle-cloud-setup.md)
