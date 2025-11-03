#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}K3s Cluster Setup Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if terraform outputs are available
if ! terraform -chdir=terraform output > /dev/null 2>&1; then
  echo -e "${RED}Error: Terraform outputs not available. Run 'terraform apply' first.${NC}"
  exit 1
fi

# Get IPs from Terraform
MASTER_IP=$(terraform -chdir=terraform output -raw master_public_ip)
WORKER1_IP=$(terraform -chdir=terraform output -raw worker_1_public_ip)
WORKER2_IP=$(terraform -chdir=terraform output -raw worker_2_public_ip)
SSH_KEY="${HOME}/.ssh/$(terraform -chdir=terraform output -json ssh_commands | jq -r '.master' | grep -oP '(?<=-i )[^ ]+' | sed 's|~|'${HOME}'|')"

echo -e "${YELLOW}Master IP:${NC} $MASTER_IP"
echo -e "${YELLOW}Worker 1 IP:${NC} $WORKER1_IP"
echo -e "${YELLOW}Worker 2 IP:${NC} $WORKER2_IP"
echo ""

# Wait for SSH to be available
echo -e "${YELLOW}Waiting for SSH to be available on all nodes...${NC}"
for ip in $MASTER_IP $WORKER1_IP $WORKER2_IP; do
  while ! ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$ip "echo SSH OK" > /dev/null 2>&1; do
    echo "  Waiting for $ip..."
    sleep 5
  done
  echo -e "${GREEN}  $ip is ready${NC}"
done

# Wait for K3s to be installed on master
echo ""
echo -e "${YELLOW}Waiting for K3s installation on master...${NC}"
while ! ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "sudo test -f /var/lib/rancher/k3s/server/node-token" > /dev/null 2>&1; do
  echo "  K3s still installing on master..."
  sleep 10
done
echo -e "${GREEN}K3s master is ready${NC}"

# Get the node token from master
echo ""
echo -e "${YELLOW}Retrieving cluster token from master...${NC}"
NODE_TOKEN=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "sudo cat /var/lib/rancher/k3s/server/node-token")
echo -e "${GREEN}Token retrieved${NC}"

# Join worker nodes
echo ""
echo -e "${YELLOW}Joining worker nodes to cluster...${NC}"

for worker_ip in $WORKER1_IP $WORKER2_IP; do
  echo "  Joining $worker_ip..."
  ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$worker_ip << EOF
    set -e
    # Stop any existing K3s agent
    sudo systemctl stop k3s-agent || true

    # Install K3s agent with the correct token
    curl -sfL https://get.k3s.io | K3S_URL=https://${MASTER_IP}:6443 \
      K3S_TOKEN=${NODE_TOKEN} \
      sh -s - agent

    echo "Worker joined successfully"
EOF
  echo -e "${GREEN}  $worker_ip joined${NC}"
done

# Wait for nodes to be ready
echo ""
echo -e "${YELLOW}Waiting for all nodes to be Ready...${NC}"
sleep 15

# Check cluster status
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Cluster Status${NC}"
echo -e "${GREEN}========================================${NC}"
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "sudo k3s kubectl get nodes -o wide"

# Label worker nodes
echo ""
echo -e "${YELLOW}Labeling worker nodes...${NC}"
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$MASTER_IP << 'EOF'
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

  # Find worker nodes and label them
  WORKER1=$(sudo k3s kubectl get nodes -o name | grep worker | head -n 1 | cut -d'/' -f2)
  WORKER2=$(sudo k3s kubectl get nodes -o name | grep worker | tail -n 1 | cut -d'/' -f2)

  # Label worker-1 for data services (Kafka, ZooKeeper, MongoDB, Prometheus)
  sudo k3s kubectl label node $WORKER1 workload=data-services --overwrite
  sudo k3s kubectl label node $WORKER1 node-role.kubernetes.io/worker=true --overwrite

  # Label worker-2 for application services (Producer, Processor, Grafana, Loki)
  sudo k3s kubectl label node $WORKER2 workload=application-services --overwrite
  sudo k3s kubectl label node $WORKER2 node-role.kubernetes.io/worker=true --overwrite

  echo "Node labels applied"
EOF

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}K3s Cluster Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Get kubeconfig: scp -i $SSH_KEY ubuntu@$MASTER_IP:/etc/rancher/k3s/k3s.yaml ~/.kube/config-ca3"
echo "2. Edit ~/.kube/config-ca3 and replace 127.0.0.1 with $MASTER_IP"
echo "3. Export KUBECONFIG: export KUBECONFIG=~/.kube/config-ca3"
echo "4. Verify: kubectl get nodes"
echo ""
