# 🚀 CA3: Start Here - Oracle Cloud Free Tier Edition

## Overview

We've completely rewritten your infrastructure to use **Oracle Cloud Always Free Tier**:

- ✅ **$0.00 cost** (vs. $18-55 on AWS)
- ✅ **4 OCPU, 12GB RAM ARM instance** (more powerful than AWS t3.large)
- ✅ **Free forever** (not just 12 months)
- ✅ Perfect for CA3 requirements

---

## Quick Start (What to Do Right Now)

### 1. Read the Day 1 Summary
```bash
open ~/Downloads/CA2/DAY-1-SUMMARY.md
```

This explains what was created and why Oracle Cloud is better for CA3.

### 2. Follow the Oracle Cloud Setup Guide
```bash
open ~/Downloads/CA2/docs/oracle-cloud-setup.md
```

**You'll create**:
- Oracle Cloud account (FREE)
- API keys for Terraform
- SSH keys for instance access
- Collect your OCIDs (IDs for tenancy, user, compartment)

**Time**: ~30 minutes

### 3. Configure Terraform
```bash
cd ~/Downloads/CA2/terraform-oci
cp terraform.tfvars.example terraform.tfvars
vi terraform.tfvars  # Paste your OCIDs from step 2
```

### 4. Deploy Infrastructure
```bash
cd ~/Downloads/CA2
./scripts/oracle-deploy.sh
```

This creates your FREE ARM instance in Oracle Cloud.

### 5. Continue with Day 1 Guide
```bash
open ~/Downloads/CA2/docs/DAY-1-ORACLE-QUICKSTART.md
```

Follow from "Phase 4: Setup Local kubectl Access"

---

## File Structure

```
CA2/
├── START-HERE.md                    ← YOU ARE HERE
├── DAY-1-SUMMARY.md                ← Read this first
├── CA3-ROADMAP.md                  ← Full 11-day plan
│
├── docs/
│   ├── oracle-cloud-setup.md       ← Step-by-step OCI setup
│   └── DAY-1-ORACLE-QUICKSTART.md  ← Complete Day 1 guide
│
├── terraform-oci/                   ← NEW: Oracle Cloud infrastructure
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── cloud-init.yaml
│   └── terraform.tfvars.example
│
├── scripts/
│   └── oracle-deploy.sh            ← One-command deployment
│
└── terraform/                       ← OLD: AWS (keep for reference)
```

---

## Why Oracle Cloud?

### Cost Comparison (11 days for CA3)

| Platform | Configuration | Cost |
|----------|--------------|------|
| **Oracle Cloud** | 1x ARM (4 OCPU, 12GB) | **$0.00** |
| AWS Option 1 | 3x t3.large (8GB each) | $55.00 |
| AWS Option 2 | 3x t3.medium (4GB each) | $36.30 |
| AWS Option 3 | 1x t3.medium (4GB) | $12.10 |

### Resource Comparison

| Resource | Oracle Free Tier | AWS t3.large (3x) |
|----------|------------------|-------------------|
| vCPUs | 4 OCPU (ARM64) | 6 vCPU (x86_64) |
| RAM | 12GB | 24GB |
| Storage | 50GB | 60GB |
| **COST** | **$0.00 forever** | **$150/month** |

**Verdict**: Oracle gives you enough for CA3 at ZERO cost.

---

## What You'll Build

**Today (Day 1)**:
- Oracle Cloud ARM instance (FREE)
- K3s (lightweight Kubernetes)
- Metals pipeline running on K3s
- Baseline metrics

**Days 2-4** (Observability - 25%):
- Prometheus + Grafana
- Loki + Promtail
- Instrumented metrics
- Centralized logging

**Days 5-6** (Autoscaling - 20%):
- Horizontal Pod Autoscaler
- Load testing
- Scaling 1→10 replicas

**Days 7-8** (Security - 20%):
- NetworkPolicies
- TLS encryption
- Secrets management

**Day 9** (Resilience - 25%):
- Failure injection
- Recovery demonstration
- 3-minute video

**Days 10-11** (Documentation - 10%):
- README finalization
- Cost analysis
- Final submission

---

## Prerequisites

Install these on your local machine:

```bash
# Terraform (for infrastructure deployment)
brew install terraform

# kubectl (for Kubernetes management)
brew install kubectl

# (Optional) k9s - Kubernetes CLI dashboard
brew install k9s
```

---

## Support

If you get stuck:

1. Check troubleshooting sections in each guide
2. Review the error message carefully
3. Share with me:
   - Which step you're on
   - Exact error message
   - Output of relevant commands

---

## Timeline

**Day 1** (Today - 4 hours):
- [ ] Oracle Cloud setup (30 min)
- [ ] Terraform configuration (5 min)
- [ ] Deploy infrastructure (15 min)
- [ ] Install K3s (10 min)
- [ ] Setup kubectl (15 min)
- [ ] Create K8s manifests (30 min)
- [ ] Deploy pipeline (15 min)
- [ ] Smoke test (10 min)
- [ ] Screenshots (10 min)

**Remaining**: 10 days for Observability, Autoscaling, Security, Resilience, Docs

---

## Success Criteria (Day 1)

By end of today, you should have:

✅ Oracle Cloud account (FREE tier)
✅ ARM instance running (4 OCPU, 12GB RAM)
✅ K3s cluster (1 node, Ready)
✅ kubectl working from local machine
✅ All 5 pods running:
   - zookeeper-0
   - kafka-0
   - mongodb-0
   - producer-xxx
   - processor-xxx
✅ Pipeline processing messages
✅ MongoDB has 1000+ documents
✅ Screenshots of:
   - `kubectl get nodes`
   - `kubectl get pods -n metals-pipeline`
   - Logs showing successful processing

---

## Next Steps

1. **Open this guide**: [docs/oracle-cloud-setup.md](docs/oracle-cloud-setup.md)
2. Create Oracle Cloud account (30 min)
3. Come back here when you have your OCIDs
4. Continue with Terraform deployment

---

## Questions?

- "Is Oracle Cloud really free forever?" → YES, Always Free tier never expires
- "What if I already have an AWS account?" → Still use Oracle - saves $55 for CA3
- "Is ARM64 compatible with my containers?" → Yes, Docker multi-arch images work
- "Can I use this for future projects?" → Yes, keep it running after CA3!

---

## Ready to Start?

```bash
# Step 1: Read the Oracle setup guide
open ~/Downloads/CA2/docs/oracle-cloud-setup.md

# Step 2: After setup, deploy with
./scripts/oracle-deploy.sh
```

**Estimated time to first pod running**: 1 hour 15 minutes

Let's build this! 🚀
