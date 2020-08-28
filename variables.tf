###############################
# Packet Variables
###############################
variable "packet_api_key" {
}

variable "cluster_name" {
  default = "platform9-on-packet"
}

variable "project_name" {
  default = "platform9-on-packet"
}

variable "packet_org_id" {
}

variable "bgp_asn" {
  default = 65000
}

variable "master_size" {
  default = "c3.small.x86"
}

variable "worker_size" {
  default = "c3.small.x86"
}

variable "facility" {
  default = "sv15"
}

variable "operating_system" {
  default = "ubuntu_18_04"
}

variable "billing_cycle" {
  default = "hourly"
}

variable "master_count" {
  default = 1
}

variable "worker_count" {
  default = 1
}

###############################
# Platform9 Variables
###############################

variable "platform9_fqdn" {
}

variable "platform9_user" {
}

variable "platform9_password" {
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

