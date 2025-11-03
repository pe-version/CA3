# Oracle Cloud Infrastructure (OCI) Variables for CA3

variable "tenancy_ocid" {
  description = "OCID of your tenancy (from ~/.oci/config)"
  type        = string
  # Get from: OCI Console → Profile → Tenancy
}

variable "user_ocid" {
  description = "OCID of your user (from ~/.oci/config)"
  type        = string
  # Get from: OCI Console → Profile → User Settings
}

variable "compartment_ocid" {
  description = "OCID of compartment for CA3 resources"
  type        = string
  # Get from: OCI Console → Identity → Compartments → CA3-Metals-Pipeline
}

variable "region" {
  description = "OCI region"
  type        = string
  default     = "us-chicago-1"
  # Common options: us-chicago-1 (Midwest), us-ashburn-1 (East), us-phoenix-1 (West)
}

variable "availability_domain" {
  description = "Availability domain for the instance"
  type        = string
  # Get from: OCI Console → Governance → Limits → Check which AD has ARM capacity
  # Format for us-chicago-1:  YXRh:US-CHICAGO-1-AD-1 (or -AD-2, -AD-3)
  # Format for us-ashburn-1:  iKTz:US-ASHBURN-AD-1
  # Format for us-phoenix-1:  PHX-AD-1
}

variable "ssh_public_key" {
  description = "SSH public key for instance access"
  type        = string
  # Contents of ~/.ssh/oci_ca3.pub
}

variable "instance_shape" {
  description = "Instance shape (Always Free: VM.Standard.A1.Flex)"
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "instance_ocpus" {
  description = "Number of OCPUs (Free tier allows up to 4 total)"
  type        = number
  default     = 4  # Use full free allocation for CA3
}

variable "instance_memory_gb" {
  description = "RAM in GB (Free tier allows up to 24GB total)"
  type        = number
  default     = 12  # Plenty for CA3 stack
}

variable "boot_volume_size_gb" {
  description = "Boot volume size in GB (Free tier allows 200GB total)"
  type        = number
  default     = 50  # Enough for OS + containers + logs
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
  default     = "CA3-Metals-Pipeline"
}
