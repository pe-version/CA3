# AWS Deployment Quick Start

## Summary of Changes

✅ **Old instances cannot be recovered** - they are terminated
✅ **Configuration updated** for flexible instance sizing:
- Master: t3.small ($0.50/day) - Control plane + observability
- Worker-1: t3.medium ($1/day) - Data services (Kafka needs RAM)
- Worker-2: t3.small ($0.50/day) - Application services
- **Total: ~$2/day or ~$14/week**

## Deploy to AWS

### Option 1: Automated Script (Recommended)
```bash
./scripts/deploy-aws-k3s.sh
```

This script will:
1. Auto-detect your public IP
2. Show cost estimates
3. Handle old state cleanup
4. Deploy 3-node K3s cluster
5. Provide next steps

### Option 2: Manual Deployment
```bash
# 1. Get your public IP
curl -s ifconfig.me

# 2. Edit terraform/terraform.tfvars
# Uncomment and set: my_ip = "YOUR_IP/32"

# 3. Clean old state
cd terraform
rm -f terraform.tfstate*

# 4. Deploy
terraform init
terraform plan
terraform apply

# 5. Wait 3 minutes for K3s installation, then:
cd ..
./scripts/setup-k3s-cluster.sh

# 6. Deploy applications
kubectl apply -k k8s/base/
```

## Instance Sizing Options

### Current Config (Balanced - Recommended)
```hcl
master_instance_type   = "t3.small"   # $0.50/day
worker_1_instance_type = "t3.medium"  # $1/day  
worker_2_instance_type = "t3.small"   # $0.50/day
# Total: $2/day = ~$14/week
```

### Budget Option (All Small - TIGHT)
```hcl
master_instance_type   = "t3.small"   # $0.50/day
worker_1_instance_type = "t3.small"   # $0.50/day  
worker_2_instance_type = "t3.small"   # $0.50/day
# Total: $1.50/day = ~$10.50/week
```
⚠️ **WARNING**: Kafka may run out of memory on t3.small (2GB RAM)

### Performance Option (All Medium)
```hcl
master_instance_type   = "t3.medium"  # $1/day
worker_1_instance_type = "t3.medium"  # $1/day  
worker_2_instance_type = "t3.medium"  # $1/day
# Total: $3/day = ~$21/week
```

## After Deployment

### Access K3s
```bash
# Get kubeconfig
./scripts/setup-k3s-cluster.sh

# Verify cluster
kubectl get nodes
kubectl get pods -n ca3-app
```

### Access Grafana
```bash
# Port-forward
kubectl port-forward -n ca3-app svc/prometheus-grafana 3000:80

# Get password
kubectl get secret -n ca3-app prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d

# Open: http://localhost:3000
# Username: admin
```

### Monitor Costs
```bash
# Check instance status
aws ec2 describe-instances --region us-east-2 \
  --filters "Name=tag:Project,Values=CA3-K3s-3Node" \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name]' \
  --output table
```

### Cleanup When Done
```bash
cd terraform
terraform destroy
```

## Troubleshooting

### Can't SSH to instances
```bash
# Verify your IP in security group
cd terraform
terraform output security_group_id

aws ec2 describe-security-groups --region us-east-2 \
  --group-ids $(terraform output -raw security_group_id) \
  --query 'SecurityGroups[0].IpPermissions[?FromPort==`22`].IpRanges[].CidrIp'

# If wrong, update terraform.tfvars with: my_ip = "$(curl -s ifconfig.me)/32"
# Then: terraform apply
```

### K3s not installing
```bash
# SSH to master and check logs
ssh -i ~/.ssh/ca0-keys.pem ubuntu@$(cd terraform && terraform output -raw master_public_ip)
sudo journalctl -u k3s -f
```

### Pods not scheduling on correct nodes
```bash
# Verify node labels
kubectl get nodes --show-labels

# Should see:
# - master: workload=control-plane
# - worker-1: workload=data-services  
# - worker-2: workload=application-services
```
