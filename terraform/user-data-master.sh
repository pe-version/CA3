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
apt-get install -y curl apt-transport-https ca-certificates software-properties-common

# Install K3s as server (master)
curl -sfL https://get.k3s.io | sh -s - server \
  --node-name ${node_name} \
  --write-kubeconfig-mode 644 \
  --disable traefik \
  --disable servicelb \
  --kube-apiserver-arg=feature-gates=MixedProtocolLBService=true

# Wait for K3s to be ready
sleep 30

# Save the node token for workers
cp /var/lib/rancher/k3s/server/node-token /tmp/node-token
chmod 644 /tmp/node-token

# Label the master node for specific workloads
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
/usr/local/bin/kubectl label node ${node_name} node-role.kubernetes.io/master=true --overwrite
/usr/local/bin/kubectl label node ${node_name} workload=control-plane --overwrite

# Create namespace for the application
/usr/local/bin/kubectl create namespace ca3-app || true

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "K3s master installation complete"
