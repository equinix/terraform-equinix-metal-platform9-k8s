###############################
# Equinix Metal Variables
###############################


variable "metal_api_key" {
  description = "Equinix Metal API Key"
}

variable "cluster_name" {
  description = "Platform 9 Cluster name"
  default     = "platform9-on-equinix-metal"
}

variable "project_name" {
  description = "Equinix Metal Project name"
  default     = "platform9-on-equinix-metal"
}

variable "metal_org_id" {
  description = "Equinix Metal Organization ID (found on the General tab of the Organizations Settings page)"
}

variable "bgp_asn" {
  description = "Equinix Metal BGP ASN"
  default     = 65000
}

variable "master_size" {
  description = "Equinix Metal device plan for the control plane nodes"
  default     = "c3.small.x86"
}

variable "worker_size" {
  description = "Equinix Metal device plan for the control worker nodes"
  default     = "c3.small.x86"
}

variable "facility" {
  description = "Equinix Metal facility for all device nodes"
  default     = "sv15"
}

variable "operating_system" {
  description = "Operating System to be deployed on Equinix Metal device nodes"
  default     = "ubuntu_18_04"
}

variable "billing_cycle" {
  default = "hourly"
}

variable "master_count" {
  description = "Control plan size (3 for HA, 1 minimum)"
  default     = 1
}

variable "worker_count" {
  description = "Worker node pool size (0 minimum, the control plane can act as workers with allow_workloads_on_master enabled)"
  default     = 0
}

###############################
# Platform9 Variables
###############################

variable "platform9_fqdn" {
  description = "Platform9 FQDN (example: pmkft-1234567890-09876.platform9.io)"
}

variable "platform9_user" {
  description = "Platform9 account email"
}

variable "platform9_password" {
  description = "Platform9 account password"
}

variable "platform9_tenant" {
  default = "service"
}

variable "platform9_region" {
  default = "RegionOne"
}

variable "hostagent_installer_type" {
  default = ""
}

variable "hostagent_install_failure_webhook" {
  default = ""
}

variable "hostagent_install_options" {
  default = ""
}

variable "http_proxy" {
  default = ""
}

variable "is_spot_instance" {
  default = false
}

variable "allow_workloads_on_master" {
  description = "Wether or not the control plane nodes should run workloads"
  default     = true
}

