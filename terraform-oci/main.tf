terraform {
  required_version = ">= 1.5.0"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 5.0"
    }
  }
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = local.fingerprint
  private_key_path = pathexpand("~/.oci/oci_api_key.pem")
  region           = var.region
}

# Read fingerprint from config file
locals {
  fingerprint = trimspace(regex("fingerprint\\s*=\\s*(.+)", file(pathexpand("~/.oci/config")))[0])
}

# Get list of availability domains
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

# Get latest Ubuntu 22.04 ARM image
data "oci_core_images" "ubuntu_arm" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                    = var.instance_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# Virtual Cloud Network (VCN) - equivalent to AWS VPC
resource "oci_core_vcn" "ca3_vcn" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.project_name}-vcn"
  cidr_blocks    = ["10.0.0.0/16"]
  dns_label      = "ca3vcn"

  freeform_tags = {
    Project = var.project_name
  }
}

# Internet Gateway
resource "oci_core_internet_gateway" "ca3_igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.ca3_vcn.id
  display_name   = "${var.project_name}-igw"
  enabled        = true

  freeform_tags = {
    Project = var.project_name
  }
}

# Route Table
resource "oci_core_route_table" "ca3_rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.ca3_vcn.id
  display_name   = "${var.project_name}-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.ca3_igw.id
    description       = "Default route to internet"
  }

  freeform_tags = {
    Project = var.project_name
  }
}

# Public Subnet
resource "oci_core_subnet" "ca3_public_subnet" {
  compartment_id      = var.compartment_ocid
  vcn_id              = oci_core_vcn.ca3_vcn.id
  cidr_block          = "10.0.1.0/24"
  display_name        = "${var.project_name}-public-subnet"
  dns_label           = "public"
  route_table_id      = oci_core_route_table.ca3_rt.id
  security_list_ids   = [oci_core_security_list.ca3_seclist.id]
  prohibit_public_ip_on_vnic = false

  freeform_tags = {
    Project = var.project_name
  }
}

# Security List (equivalent to AWS Security Group)
resource "oci_core_security_list" "ca3_seclist" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.ca3_vcn.id
  display_name   = "${var.project_name}-seclist"

  # Egress - allow all outbound
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
    description = "Allow all outbound traffic"
  }

  # Ingress - SSH
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    description = "SSH access"
    tcp_options {
      min = 22
      max = 22
    }
  }

  # Ingress - K3s API Server
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    description = "K3s API server"
    tcp_options {
      min = 6443
      max = 6443
    }
  }

  # Ingress - Grafana
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    description = "Grafana dashboard"
    tcp_options {
      min = 3000
      max = 3000
    }
  }

  # Ingress - Prometheus
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    description = "Prometheus UI"
    tcp_options {
      min = 9090
      max = 9090
    }
  }

  # Ingress - Producer metrics/health
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    description = "Producer metrics endpoint"
    tcp_options {
      min = 8000
      max = 8000
    }
  }

  # Ingress - Processor metrics/health
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    description = "Processor metrics endpoint"
    tcp_options {
      min = 8001
      max = 8001
    }
  }

  # Ingress - Kafka (internal only)
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "10.0.0.0/16"
    description = "Kafka broker"
    tcp_options {
      min = 9092
      max = 9093
    }
  }

  # Ingress - MongoDB (internal only)
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "10.0.0.0/16"
    description = "MongoDB"
    tcp_options {
      min = 27017
      max = 27017
    }
  }

  # Ingress - K3s Kubelet API (internal only)
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "10.0.0.0/16"
    description = "K3s Kubelet API"
    tcp_options {
      min = 10250
      max = 10250
    }
  }

  # Ingress - ICMP (for ping)
  ingress_security_rules {
    protocol    = "1" # ICMP
    source      = "0.0.0.0/0"
    description = "ICMP for ping"
  }

  freeform_tags = {
    Project = var.project_name
  }
}

# Compute Instance - ARM-based Free Tier
resource "oci_core_instance" "ca3_k3s_node" {
  compartment_id      = var.compartment_ocid
  availability_domain = var.availability_domain
  display_name        = "${var.project_name}-k3s-node"
  shape               = var.instance_shape

  # ARM Flex shape config
  shape_config {
    ocpus         = var.instance_ocpus
    memory_in_gbs = var.instance_memory_gb
  }

  # Network configuration
  create_vnic_details {
    subnet_id        = oci_core_subnet.ca3_public_subnet.id
    display_name     = "${var.project_name}-vnic"
    assign_public_ip = true
    hostname_label   = "ca3k3s"
  }

  # Boot volume configuration
  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ubuntu_arm.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_size_gb
  }

  # SSH key
  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
      hostname = "ca3-k3s-node"
    }))
  }

  # Preserve boot volume on instance termination (for safety)
  preserve_boot_volume = false

  freeform_tags = {
    Project = var.project_name
    Role    = "k3s-master"
  }

  # Lifecycle - prevent accidental deletion during development
  lifecycle {
    ignore_changes = [
      source_details[0].source_id, # Don't recreate on image updates
    ]
  }
}
