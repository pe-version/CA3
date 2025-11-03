# Outputs for CA3 Oracle Cloud Infrastructure

output "instance_public_ip" {
  description = "Public IP address of the K3s node"
  value       = oci_core_instance.ca3_k3s_node.public_ip
}

output "instance_private_ip" {
  description = "Private IP address of the K3s node"
  value       = oci_core_instance.ca3_k3s_node.private_ip
}

output "instance_id" {
  description = "OCID of the instance"
  value       = oci_core_instance.ca3_k3s_node.id
}

output "instance_state" {
  description = "Current state of the instance"
  value       = oci_core_instance.ca3_k3s_node.state
}

output "ssh_command" {
  description = "SSH connection command"
  value       = "ssh -i ~/.ssh/oci_ca3 ubuntu@${oci_core_instance.ca3_k3s_node.public_ip}"
}

output "grafana_url" {
  description = "Grafana dashboard URL (after deployment)"
  value       = "http://${oci_core_instance.ca3_k3s_node.public_ip}:3000"
}

output "prometheus_url" {
  description = "Prometheus UI URL (after deployment)"
  value       = "http://${oci_core_instance.ca3_k3s_node.public_ip}:9090"
}

output "producer_metrics_url" {
  description = "Producer metrics endpoint"
  value       = "http://${oci_core_instance.ca3_k3s_node.public_ip}:8000/metrics"
}

output "processor_metrics_url" {
  description = "Processor metrics endpoint"
  value       = "http://${oci_core_instance.ca3_k3s_node.public_ip}:8001/metrics"
}

output "k3s_api_endpoint" {
  description = "K3s API server endpoint"
  value       = "https://${oci_core_instance.ca3_k3s_node.public_ip}:6443"
}

output "instance_specs" {
  description = "Instance specifications"
  value = {
    shape      = oci_core_instance.ca3_k3s_node.shape
    ocpus      = oci_core_instance.ca3_k3s_node.shape_config[0].ocpus
    memory_gb  = oci_core_instance.ca3_k3s_node.shape_config[0].memory_in_gbs
    boot_volume_size_gb = var.boot_volume_size_gb
  }
}

output "cost_estimate" {
  description = "Monthly cost estimate"
  value       = "$0.00 (Oracle Cloud Always Free Tier)"
}

output "next_steps" {
  description = "What to do next"
  value = <<-EOT

  ✅ Instance provisioned successfully!

  1. SSH into instance:
     ${self.ssh_command}

  2. Install K3s:
     curl -sfL https://get.k3s.io | sh -

  3. Verify K3s:
     sudo kubectl get nodes

  4. Copy kubeconfig to local machine:
     mkdir -p ~/.kube
     scp -i ~/.ssh/oci_ca3 ubuntu@${oci_core_instance.ca3_k3s_node.public_ip}:/etc/rancher/k3s/k3s.yaml ~/.kube/oci-k3s.yaml

     # Edit ~/.kube/oci-k3s.yaml and replace 127.0.0.1 with ${oci_core_instance.ca3_k3s_node.public_ip}
     sed -i.bak 's/127.0.0.1/${oci_core_instance.ca3_k3s_node.public_ip}/g' ~/.kube/oci-k3s.yaml

     export KUBECONFIG=~/.kube/oci-k3s.yaml
     kubectl get nodes

  5. Access dashboards (after deployment):
     - Grafana:    ${self.grafana_url}
     - Prometheus: ${self.prometheus_url}

  Cost: $0.00/month (FREE FOREVER)
  EOT
}
