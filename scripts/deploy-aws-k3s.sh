#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}CA3 AWS Deployment Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Change to terraform directory
cd "$(dirname "$0")/../terraform"

# Check if my_ip is set in terraform.tfvars
if ! grep -q "^my_ip" terraform.tfvars || grep -q "YOUR_IP_HERE" terraform.tfvars; then
    echo -e "${YELLOW}Getting your public IP address...${NC}"
    MY_IP=$(curl -s ifconfig.me)
    echo -e "${GREEN}Your public IP: ${MY_IP}${NC}"
    echo ""
    echo -e "${YELLOW}Adding to terraform.tfvars...${NC}"
    
    # Check if my_ip line exists but is commented or has placeholder
    if grep -q "# my_ip" terraform.tfvars; then
        # Replace commented line
        sed -i.bak "s|# my_ip.*|my_ip = \"${MY_IP}/32\"|g" terraform.tfvars
    else
        # Append if not exists
        echo "my_ip = \"${MY_IP}/32\"" >> terraform.tfvars
    fi
    echo -e "${GREEN}✓ IP address configured${NC}"
    echo ""
fi

# Show current configuration
echo -e "${BLUE}Current Configuration:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
grep -E "^(aws_region|ssh_key_name|master_instance_type|worker_.*_instance_type|my_ip)" terraform.tfvars | while read line; do
    echo "  $line"
done
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Calculate estimated cost
MASTER_TYPE=$(grep "^master_instance_type" terraform.tfvars | cut -d'"' -f2)
WORKER1_TYPE=$(grep "^worker_1_instance_type" terraform.tfvars | cut -d'"' -f2)
WORKER2_TYPE=$(grep "^worker_2_instance_type" terraform.tfvars | cut -d'"' -f2)

# Simple cost calculation
get_cost() {
    case $1 in
        "t3.small") echo "0.0208" ;;
        "t3.medium") echo "0.0416" ;;
        "t3.large") echo "0.0832" ;;
        *) echo "0.0416" ;;
    esac
}

MASTER_COST=$(get_cost "$MASTER_TYPE")
WORKER1_COST=$(get_cost "$WORKER1_TYPE")
WORKER2_COST=$(get_cost "$WORKER2_TYPE")

TOTAL_HOURLY=$(echo "$MASTER_COST + $WORKER1_COST + $WORKER2_COST" | bc)
TOTAL_DAILY=$(echo "$TOTAL_HOURLY * 24" | bc)
TOTAL_WEEKLY=$(echo "$TOTAL_DAILY * 7" | bc)

echo -e "${BLUE}Estimated Costs:${NC}"
echo "  Hourly:  \$${TOTAL_HOURLY}/hr"
echo "  Daily:   \$${TOTAL_DAILY}/day"
echo "  Weekly:  \$${TOTAL_WEEKLY}/week"
echo ""

# Check if old state exists
if [ -f "terraform.tfstate" ]; then
    echo -e "${YELLOW}⚠ Old Terraform state detected${NC}"
    echo ""
    echo "Your options:"
    echo "  1) Destroy old infrastructure and start fresh (RECOMMENDED)"
    echo "  2) Try to apply changes to existing state"
    echo "  3) Exit and handle manually"
    echo ""
    read -p "Choose option (1/2/3): " choice
    
    case $choice in
        1)
            echo -e "${YELLOW}Destroying old infrastructure...${NC}"
            terraform destroy -auto-approve || {
                echo -e "${RED}Destroy failed (instances may already be gone)${NC}"
                echo -e "${YELLOW}Removing state files...${NC}"
                rm -f terraform.tfstate*
                echo -e "${GREEN}✓ State files removed${NC}"
            }
            echo ""
            ;;
        2)
            echo -e "${YELLOW}Will attempt to update existing infrastructure...${NC}"
            echo ""
            ;;
        3)
            echo -e "${YELLOW}Exiting. Handle state manually then re-run this script.${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice. Exiting.${NC}"
            exit 1
            ;;
    esac
fi

# Initialize Terraform
echo -e "${BLUE}Initializing Terraform...${NC}"
terraform init
echo ""

# Plan
echo -e "${BLUE}Planning deployment...${NC}"
terraform plan -out=tfplan
echo ""

# Confirm
echo -e "${YELLOW}Ready to deploy 3-node K3s cluster to AWS${NC}"
echo ""
read -p "Proceed with deployment? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo -e "${YELLOW}Deployment cancelled${NC}"
    rm -f tfplan
    exit 0
fi

# Apply
echo ""
echo -e "${GREEN}Deploying infrastructure...${NC}"
terraform apply tfplan
rm -f tfplan
echo ""

# Get outputs
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

MASTER_IP=$(terraform output -raw master_public_ip)
WORKER1_IP=$(terraform output -raw worker_1_public_ip)
WORKER2_IP=$(terraform output -raw worker_2_public_ip)

echo -e "${BLUE}Instance Information:${NC}"
echo "  Master:   $MASTER_IP ($MASTER_TYPE)"
echo "  Worker-1: $WORKER1_IP ($WORKER1_TYPE) - Data Services"
echo "  Worker-2: $WORKER2_IP ($WORKER2_TYPE) - App Services"
echo ""

echo -e "${BLUE}SSH Connection Strings:${NC}"
terraform output -json ssh_connection_strings | jq -r 'to_entries[] | "  \(.key): \(.value)"'
echo ""

echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Wait 2-3 minutes for user-data scripts to install K3s"
echo "  2. Run: ./scripts/setup-k3s-cluster.sh"
echo "  3. Deploy applications: kubectl apply -k k8s/base/"
echo "  4. Port-forward Grafana: kubectl port-forward -n ca3-app svc/prometheus-grafana 3000:80"
echo ""

echo -e "${GREEN}Estimated running cost: \$${TOTAL_DAILY}/day${NC}"
echo -e "${YELLOW}Remember to destroy when done: cd terraform && terraform destroy${NC}"
echo ""
