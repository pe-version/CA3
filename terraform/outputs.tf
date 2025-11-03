output "master_public_ip" {
  description = "Public IP of K3s master node"
  value       = aws_instance.k3s_master.public_ip
}

output "master_private_ip" {
  description = "Private IP of K3s master node"
  value       = aws_instance.k3s_master.private_ip
}

output "worker_1_public_ip" {
  description = "Public IP of worker 1"
  value       = aws_instance.k3s_worker_1.public_ip
}

output "worker_1_private_ip" {
  description = "Private IP of worker 1"
  value       = aws_instance.k3s_worker_1.private_ip
}

output "worker_2_public_ip" {
  description = "Public IP of worker 2"
  value       = aws_instance.k3s_worker_2.public_ip
}

output "worker_2_private_ip" {
  description = "Private IP of worker 2"
  value       = aws_instance.k3s_worker_2.private_ip
}

output "ssh_commands" {
  description = "SSH connection commands"
  value = {
    master  = "ssh -i ~/.ssh/${var.ssh_key_name}.pem ubuntu@${aws_instance.k3s_master.public_ip}"
    worker1 = "ssh -i ~/.ssh/${var.ssh_key_name}.pem ubuntu@${aws_instance.k3s_worker_1.public_ip}"
    worker2 = "ssh -i ~/.ssh/${var.ssh_key_name}.pem ubuntu@${aws_instance.k3s_worker_2.public_ip}"
  }
}

output "kubeconfig_command" {
  description = "Command to get kubeconfig from master"
  value       = "scp -i ~/.ssh/${var.ssh_key_name}.pem ubuntu@${aws_instance.k3s_master.public_ip}:/etc/rancher/k3s/k3s.yaml ~/.kube/config-ca3"
}

output "dashboard_urls" {
  description = "Observability dashboard URLs"
  value = {
    grafana    = "http://${aws_instance.k3s_master.public_ip}:3000"
    prometheus = "http://${aws_instance.k3s_master.public_ip}:9090"
    producer   = "http://${aws_instance.k3s_master.public_ip}:8000/health"
    processor  = "http://${aws_instance.k3s_master.public_ip}:8001/health"
  }
}

output "next_steps" {
  description = "What to do after infrastructure is ready"
  value = <<-EOT

    ===== K3s Cluster Created Successfully =====

    1. Wait 5-10 minutes for K3s installation to complete

    2. SSH to master node:
       ${format("ssh -i ~/.ssh/%s.pem ubuntu@%s", var.ssh_key_name, aws_instance.k3s_master.public_ip)}

    3. Check cluster status:
       sudo k3s kubectl get nodes

    4. Get kubeconfig for local kubectl:
       ${format("scp -i ~/.ssh/%s.pem ubuntu@%s:/etc/rancher/k3s/k3s.yaml ~/.kube/config-ca3", var.ssh_key_name, aws_instance.k3s_master.public_ip)}
       Then edit ~/.kube/config-ca3 and replace 127.0.0.1 with ${aws_instance.k3s_master.public_ip}

    5. Deploy workloads from k8s/ directory

    Dashboard URLs (available after deployment):
    - Grafana: http://${aws_instance.k3s_master.public_ip}:3000
    - Prometheus: http://${aws_instance.k3s_master.public_ip}:9090

    Cost estimate: ~$0.35/day for 3x t3.medium

  EOT
}
