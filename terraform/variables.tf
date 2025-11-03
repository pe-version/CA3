variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-2"
}

variable "ami_id" {
  description = "Ubuntu 22.04 LTS AMI ID for us-east-2"
  type        = string
  default     = "ami-0ea3c35c5c3284d82" # Ubuntu 22.04 LTS in us-east-2
}

variable "instance_type" {
  description = "EC2 instance type for all nodes"
  type        = string
  default     = "t3.medium"  # CA3: 3-node cluster - addresses CA2 capacity issues
}

variable "node_count" {
  description = "Number of K3s nodes (1 master + workers)"
  type        = number
  default     = 3
}

variable "ssh_key_name" {
  description = "Name of the SSH key pair in AWS"
  type        = string
  # No default - must be provided
}

variable "my_ip" {
  description = "Your IP address for SSH access (CIDR notation)"
  type        = string
  # Example: "1.2.3.4/32"
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
  default     = "CA3-K3s-3Node"
}

variable "ebs_volume_size" {
  description = "Root EBS volume size in GB per instance"
  type        = number
  default     = 20
}
