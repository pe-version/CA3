#!/bin/bash
set -euxo pipefail

# Update system
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y

# Set hostname
hostnamectl set-hostname ${node_name}
echo "127.0.0.1 ${node_name}" >> /etc/hosts

# Configure kernel parameters for Kubernetes
cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
vm.max_map_count                    = 262144
EOF

# Load br_netfilter module
modprobe br_netfilter
echo "br_netfilter" > /etc/modules-load.d/br_netfilter.conf

# Apply sysctl settings
sysctl --system

# Install required packages
apt-get install -y curl apt-transport-https ca-certificates

# Wait for master to be ready and get the token
MAX_RETRIES=60
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  if curl -sf http://${master_ip}:6443/ping > /dev/null 2>&1; then
    echo "Master is ready"
    break
  fi
  echo "Waiting for master to be ready... ($RETRY_COUNT/$MAX_RETRIES)"
  sleep 10
  RETRY_COUNT=$((RETRY_COUNT + 1))
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  echo "Timeout waiting for master"
  exit 1
fi

# Get the node token from master
# Note: In production, use AWS Systems Manager Parameter Store or Secrets Manager
# For this assignment, we'll use a simple retry mechanism
sleep 60  # Give master time to save the token

# Install K3s as agent (worker)
# The token will be fetched via SSH in a post-deployment step
# For now, we prepare the node
curl -sfL https://get.k3s.io | sh -s - agent \
  --server https://${master_ip}:6443 \
  --node-name ${node_name} || echo "Will join cluster after token is provided"

echo "K3s worker node prepared - awaiting cluster join"
