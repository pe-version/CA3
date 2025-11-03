#!/bin/bash
# Oracle Cloud Infrastructure Deployment Script for CA3
# This script deploys a FREE ARM instance for running K3s

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     CA3: Oracle Cloud Infrastructure Deployment (FREE)         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}✗ Terraform not found${NC}"
    echo "  Install: https://www.terraform.io/downloads"
    exit 1
fi
echo -e "${GREEN}✓ Terraform installed${NC}"

if [ ! -f ~/.oci/config ]; then
    echo -e "${RED}✗ OCI config not found at ~/.oci/config${NC}"
    echo "  Follow: docs/oracle-cloud-setup.md"
    exit 1
fi
echo -e "${GREEN}✓ OCI config found${NC}"

if [ ! -f ~/.oci/oci_api_key.pem ]; then
    echo -e "${RED}✗ OCI API key not found at ~/.oci/oci_api_key.pem${NC}"
    echo "  Follow: docs/oracle-cloud-setup.md"
    exit 1
fi
echo -e "${GREEN}✓ OCI API key found${NC}"

if [ ! -f ~/.ssh/oci_ca3 ]; then
    echo -e "${YELLOW}⚠ SSH key not found, generating...${NC}"
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/oci_ca3 -N "" -C "ca3-k3s-node"
    echo -e "${GREEN}✓ SSH key generated${NC}"
fi

cd terraform-oci

if [ ! -f terraform.tfvars ]; then
    echo -e "${RED}✗ terraform.tfvars not found${NC}"
    echo ""
    echo "Create terraform.tfvars with:"
    echo "  cp terraform.tfvars.example terraform.tfvars"
    echo "  vi terraform.tfvars  # Fill in your OCIDs"
    echo ""
    echo "You need:"
    echo "  - tenancy_ocid (from OCI Console → Profile → Tenancy)"
    echo "  - user_ocid (from OCI Console → Profile → User Settings)"
    echo "  - compartment_ocid (from OCI Console → Identity → Compartments)"
    echo "  - availability_domain (from OCI Console → Governance → Limits)"
    echo "  - ssh_public_key (from: cat ~/.ssh/oci_ca3.pub)"
    exit 1
fi
echo -e "${GREEN}✓ terraform.tfvars found${NC}"
echo ""

# Initialize Terraform
echo -e "${BLUE}Initializing Terraform...${NC}"
terraform init

# Validate configuration
echo ""
echo -e "${BLUE}Validating Terraform configuration...${NC}"
terraform validate
echo ""

# Plan deployment
echo -e "${BLUE}Planning deployment...${NC}"
terraform plan -out=tfplan
echo ""

# Confirm deployment
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}Review the plan above. This will create:${NC}"
echo -e "${YELLOW}  • 1x VM.Standard.A1.Flex (4 OCPU, 12GB RAM) - ARM64${NC}"
echo -e "${YELLOW}  • 1x VCN (Virtual Cloud Network)${NC}"
echo -e "${YELLOW}  • 1x Public subnet${NC}"
echo -e "${YELLOW}  • 1x Internet gateway${NC}"
echo -e "${YELLOW}  • Security lists (firewall rules)${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Cost: \$0.00/month (Oracle Cloud Always Free Tier)${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
echo ""

read -p "Deploy infrastructure? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Deployment cancelled"
    exit 0
fi

# Apply deployment
echo ""
echo -e "${BLUE}Deploying infrastructure...${NC}"
terraform apply tfplan

# Get outputs
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              Deployment Complete - Next Steps                  ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

PUBLIC_IP=$(terraform output -raw instance_public_ip)
SSH_COMMAND=$(terraform output -raw ssh_command)

echo -e "${BLUE}Instance IP:${NC} $PUBLIC_IP"
echo -e "${BLUE}SSH Command:${NC} $SSH_COMMAND"
echo ""

echo -e "${YELLOW}1. Wait 60 seconds for instance to boot...${NC}"
sleep 60

echo -e "${YELLOW}2. Testing SSH connection...${NC}"
if ssh -i ~/.ssh/oci_ca3 -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$PUBLIC_IP "echo 'Connection successful'" 2>/dev/null; then
    echo -e "${GREEN}✓ SSH connection successful${NC}"
else
    echo -e "${RED}⚠ SSH not ready yet (instance still booting)${NC}"
    echo "  Try again in 1-2 minutes: $SSH_COMMAND"
fi

echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "  1. SSH into instance:"
echo "     ${SSH_COMMAND}"
echo ""
echo "  2. Install K3s:"
echo "     curl -sfL https://get.k3s.io | sh -"
echo ""
echo "  3. Verify K3s:"
echo "     sudo kubectl get nodes"
echo ""
echo "  4. Continue with Day 1 tasks (convert docker-compose to K8s manifests)"
echo ""
echo -e "${GREEN}Cost: \$0.00/month (FREE FOREVER)${NC}"
echo ""
