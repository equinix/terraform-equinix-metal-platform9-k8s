provider "metal" {
  auth_token = var.metal_api_key
}

resource "random_string" "bgp_password" {
  length      = 18
  upper       = true
  min_upper   = 1
  lower       = true
  min_lower   = 1
  number      = true
  min_numeric = 1
  special     = false
}

resource "metal_project" "new_project" {
  name            = var.project_name
  organization_id = var.metal_org_id
  bgp_config {
    deployment_type = "local"
    md5             = random_string.bgp_password.result
    asn             = var.bgp_asn
  }
}

resource "tls_private_key" "ssh_key_pair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "metal_ssh_key" "ssh_pub_key" {
  name       = var.project_name
  public_key = chomp(tls_private_key.ssh_key_pair.public_key_openssh)
}

