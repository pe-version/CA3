terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC
resource "aws_vpc" "k3s_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name    = "${var.project_name}-vpc"
    Project = var.project_name
  }
}

# Internet Gateway
resource "aws_internet_gateway" "k3s_igw" {
  vpc_id = aws_vpc.k3s_vpc.id

  tags = {
    Name    = "${var.project_name}-igw"
    Project = var.project_name
  }
}

# Public Subnet
resource "aws_subnet" "k3s_public_subnet" {
  vpc_id                  = aws_vpc.k3s_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.project_name}-public-subnet"
    Project = var.project_name
  }
}

# Route Table
resource "aws_route_table" "k3s_public_rt" {
  vpc_id = aws_vpc.k3s_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.k3s_igw.id
  }

  tags = {
    Name    = "${var.project_name}-public-rt"
    Project = var.project_name
  }
}

# Route Table Association
resource "aws_route_table_association" "k3s_public_rta" {
  subnet_id      = aws_subnet.k3s_public_subnet.id
  route_table_id = aws_route_table.k3s_public_rt.id
}

# Security Group
resource "aws_security_group" "k3s_sg" {
  name        = "${var.project_name}-sg"
  description = "Security group for K3s cluster"
  vpc_id      = aws_vpc.k3s_vpc.id

  # SSH - Restrict to your IP
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
    description = "SSH access from your IP"
  }

  # K3s API Server
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.my_ip, "10.0.0.0/16"]
    description = "K3s API server"
  }

  # K3s internal - kubelet
  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "K3s kubelet API"
  }

  # K3s internal - flannel VXLAN
  ingress {
    from_port   = 8472
    to_port     = 8472
    protocol    = "udp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "K3s flannel VXLAN"
  }

  # K3s internal - flannel Wireguard
  ingress {
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "K3s flannel Wireguard"
  }

  # Grafana Dashboard
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Grafana web UI"
  }

  # Prometheus
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Prometheus web UI"
  }

  # Producer Health Endpoint
  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Producer health endpoint"
  }

  # Processor Health Endpoint
  ingress {
    from_port   = 8001
    to_port     = 8001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Processor health endpoint"
  }

  # Allow all internal traffic between nodes
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    description = "Allow all traffic between cluster nodes"
  }

  # Egress - allow all
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name    = "${var.project_name}-sg"
    Project = var.project_name
  }
}

# K3s Master Node
resource "aws_instance" "k3s_master" {
  ami                    = var.ami_id
  instance_type          = var.master_instance_type
  key_name               = var.ssh_key_name
  subnet_id              = aws_subnet.k3s_public_subnet.id
  vpc_security_group_ids = [aws_security_group.k3s_sg.id]

  root_block_device {
    volume_size = var.ebs_volume_size
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/user-data-master.sh", {
    node_name = "k3s-master"
  })

  tags = {
    Name    = "${var.project_name}-master"
    Role    = "master"
    Project = var.project_name
    NodeType = "control-plane"
  }
}

# K3s Worker Node 1
resource "aws_instance" "k3s_worker_1" {
  ami                    = var.ami_id
  instance_type          = var.worker_1_instance_type
  key_name               = var.ssh_key_name
  subnet_id              = aws_subnet.k3s_public_subnet.id
  vpc_security_group_ids = [aws_security_group.k3s_sg.id]

  root_block_device {
    volume_size = var.ebs_volume_size
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/user-data-worker.sh", {
    node_name = "k3s-worker-1"
    master_ip = aws_instance.k3s_master.private_ip
  })

  tags = {
    Name    = "${var.project_name}-worker-1"
    Role    = "worker"
    Project = var.project_name
    NodeType = "data-services"
  }

  depends_on = [aws_instance.k3s_master]
}

# K3s Worker Node 2
resource "aws_instance" "k3s_worker_2" {
  ami                    = var.ami_id
  instance_type          = var.worker_2_instance_type
  key_name               = var.ssh_key_name
  subnet_id              = aws_subnet.k3s_public_subnet.id
  vpc_security_group_ids = [aws_security_group.k3s_sg.id]

  root_block_device {
    volume_size = var.ebs_volume_size
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/user-data-worker.sh", {
    node_name = "k3s-worker-2"
    master_ip = aws_instance.k3s_master.private_ip
  })

  tags = {
    Name    = "${var.project_name}-worker-2"
    Role    = "worker"
    Project = var.project_name
    NodeType = "application-services"
  }

  depends_on = [aws_instance.k3s_master]
}