# Day 1 Complete Setup - Oracle Cloud Free Tier

## What We Created

I've rewritten all infrastructure for **Oracle Cloud Always Free Tier** instead of AWS. This gives you:

✅ **$0.00 cost** (vs. $18-55 on AWS for 11 days)
✅ **4 OCPU + 12GB RAM** (more powerful than 3x t3.medium)
✅ **Forever free** (not just 12-month trial)
✅ **ARM64 architecture** (modern, efficient)

---

## Files Created

### 1. Documentation
- **[docs/oracle-cloud-setup.md](docs/oracle-cloud-setup.md)** - Complete OCI account setup guide
- **[docs/DAY-1-ORACLE-QUICKSTART.md](docs/DAY-1-ORACLE-QUICKSTART.md)** - Step-by-step Day 1 guide

### 2. Terraform Configuration (New Directory: `terraform-oci/`)
- **[terraform-oci/main.tf](terraform-oci/main.tf)** - OCI infrastructure (VCN, instance, security lists)
- **[terraform-oci/variables.tf](terraform-oci/variables.tf)** - Input variables with FREE tier defaults
- **[terraform-oci/outputs.tf](terraform-oci/outputs.tf)** - SSH commands, URLs, next steps
- **[terraform-oci/cloud-init.yaml](terraform-oci/cloud-init.yaml)** - Instance initialization script
- **[terraform-oci/terraform.tfvars.example](terraform-oci/terraform.tfvars.example)** - Template for your OCIDs
- **[terraform-oci/.gitignore](terraform-oci/.gitignore)** - Prevents committing secrets

### 3. Deployment Scripts
- **[scripts/oracle-deploy.sh](scripts/oracle-deploy.sh)** - One-command deployment with validation

---

## Your Action Items (In Order)

### Step 1: Oracle Cloud Account (30 minutes)
```bash
# Open the guide:
open ~/Downloads/CA2/docs/oracle-cloud-setup.md

# Complete:
# 1. Create Oracle Cloud account at https://www.oracle.com/cloud/free/
# 2. Create compartment "CA3-Metals-Pipeline"
# 3. Generate API keys (~/.oci/oci_api_key.pem)
# 4. Setup ~/.oci/config
# 5. Generate SSH key (~/.ssh/oci_ca3)
```

**You'll collect**:
- Tenancy OCID
- User OCID
- Compartment OCID
- Availability Domain (which has ARM capacity)
- SSH public key

---

### Step 2: Configure Terraform (5 minutes)
```bash
cd ~/Downloads/CA2/terraform-oci

# Copy template
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
vi terraform.tfvars
```

Paste your OCIDs from Step 1:
```hcl
tenancy_ocid     = "ocid1.tenancy.oc1..aaaa..."
user_ocid        = "ocid1.user.oc1..aaaa..."
compartment_ocid = "ocid1.compartment.oc1..aaaa..."
availability_domain = "iKTz:US-ASHBURN-AD-1"
ssh_public_key   = "ssh-rsa AAAAB3NzaC1yc2E..."
```

---

### Step 3: Deploy Infrastructure (15 minutes)
```bash
cd ~/Downloads/CA2

# Run deployment script
./scripts/oracle-deploy.sh

# This will:
# ✓ Validate prerequisites
# ✓ Initialize Terraform
# ✓ Show deployment plan
# ✓ Deploy VCN, security lists, and FREE ARM instance
# ✓ Output SSH command and IPs
```

**Expected result**:
```
Deployment Complete!

Instance IP: 129.213.xxx.xxx
SSH Command: ssh -i ~/.ssh/oci_ca3 ubuntu@129.213.xxx.xxx

Cost: $0.00/month (FREE FOREVER)
```

---

### Step 4: Install K3s (10 minutes)
```bash
# SSH into your instance
ssh -i ~/.ssh/oci_ca3 ubuntu@<instance-ip>

# Install K3s (lightweight Kubernetes)
curl -sfL https://get.k3s.io | sh -

# Wait 30 seconds, then verify
sudo kubectl get nodes

# Expected:
# NAME           STATUS   ROLES                  AGE
# ca3-k3s-node   Ready    control-plane,master   1m
```

---

### Step 5: Setup Local kubectl (15 minutes)
```bash
# On YOUR LOCAL machine:

# Create kubeconfig directory
mkdir -p ~/.kube

# Copy K3s config from instance
scp -i ~/.ssh/oci_ca3 ubuntu@<instance-ip>:/etc/rancher/k3s/k3s.yaml ~/.kube/oci-k3s.yaml

# Replace 127.0.0.1 with instance IP
sed -i.bak "s/127.0.0.1/<instance-ip>/g" ~/.kube/oci-k3s.yaml

# Test it works
export KUBECONFIG=~/.kube/oci-k3s.yaml
kubectl get nodes

# Make permanent
echo "export KUBECONFIG=~/.kube/oci-k3s.yaml" >> ~/.zshrc
source ~/.zshrc
```

---

### Step 6: Convert docker-compose to K8s (Next - I'll help you)

Once Steps 1-5 are complete, come back and I'll help you:
1. Create Kubernetes manifests from your docker-compose.yml
2. Deploy the metals pipeline
3. Run smoke tests
4. Verify everything works

---

## Why Oracle Cloud?

| Feature | Oracle Free Tier | AWS (CA2 approach) |
|---------|------------------|-------------------|
| **Cost (11 days)** | **$0.00** | $18-55 |
| **Cost (monthly)** | **$0.00** | $45-150 |
| **vCPUs** | 4 OCPU (ARM) | 2-6 vCPU |
| **RAM** | 12GB | 4-24GB |
| **Time limit** | **Forever** | 12 months |
| **Capacity issues** | Rare | t3.small Kafka failure (CA2) |

**You learned from CA2**: Don't compromise on resources. Oracle gives you production-grade hardware for FREE.

---

## Troubleshooting

### "I don't see the ARM instance option"
- Check you selected **"Always Free Eligible"** filter in OCI Console
- Shape: `VM.Standard.A1.Flex`
- If "Out of capacity", try different Availability Domains (AD-1, AD-2, AD-3)

### "Terraform says invalid credentials"
- Verify fingerprint matches:
  ```bash
  openssl rsa -pubout -outform DER -in ~/.oci/oci_api_key.pem | openssl md5 -c
  ```
- Compare with fingerprint in `~/.oci/config`
- Ensure no trailing whitespace in config file

### "Can't SSH into instance"
- Wait 2-3 minutes after Terraform completes (cloud-init still running)
- Check security list allows port 22:
  ```bash
  cd terraform-oci
  terraform state show oci_core_security_list.ca3_seclist | grep 22
  ```

---

## Next Session

After you complete Steps 1-5 above, message me and we'll continue with:

**Day 1 Afternoon** (2 hours remaining):
- Create K8s manifests (Deployments, StatefulSets, Services)
- Deploy metals pipeline to K3s
- Run smoke test
- Screenshot evidence

**Day 2** (tomorrow):
- Instrument producer.py and processor.py with Prometheus metrics
- Rebuild Docker images
- Deploy updated images

---

## Questions?

If you get stuck on any step, share:
1. Which step you're on
2. The exact error message
3. Output of relevant commands

I'll help debug!

---

## Time Estimate

- ⏱️ Steps 1-2 (Oracle setup): **35 minutes**
- ⏱️ Step 3 (Terraform): **15 minutes**
- ⏱️ Step 4 (K3s install): **10 minutes**
- ⏱️ Step 5 (kubectl setup): **15 minutes**
- ⏱️ **Total so far**: **1h 15min**

Remaining for Day 1:
- K8s manifests: **30 minutes** (I'll help)
- Deploy pipeline: **15 minutes**
- Smoke test: **10 minutes**
- Screenshots: **10 minutes**
- **Total Day 1**: **2h 20min** (within 4-hour budget)

---

**START HERE**: [docs/oracle-cloud-setup.md](docs/oracle-cloud-setup.md)

Let me know when you've completed Step 3 (infrastructure deployed) and we'll continue! 🚀
