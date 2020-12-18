resource "metal_reserved_ip_block" "cluster_ip" {
  project_id = metal_project.new_project.id
  facility   = var.facility
  quantity   = 1
}

data "external" "create_cluster" {
  program = ["python3", "${path.module}/scripts/create_cluster.py"]
  query = {
    du_fqdn                   = var.platform9_fqdn
    user                      = var.platform9_user
    pw                        = var.platform9_password
    tenant                    = var.platform9_tenant
    region                    = var.platform9_region
    cluster_name              = var.cluster_name
    k8s_api_fqdn              = metal_reserved_ip_block.cluster_ip.address
    allow_workloads_on_master = var.allow_workloads_on_master
  }
}

resource "null_resource" "delete_cluster" {

  triggers = {
    cluster_uuid       = lookup(data.external.create_cluster.result, "cluster_id")
    platform9_fqdn     = var.platform9_fqdn
    platform9_user     = var.platform9_user
    platform9_password = var.platform9_password
    platform9_tenant   = var.platform9_tenant
    platform9_region   = var.platform9_region
  }

  provisioner "local-exec" {
    when    = destroy
    command = "printf '{\"du_fqdn\": \"${self.triggers.platform9_fqdn}\", \"user\": \"${self.triggers.platform9_user}\", \"pw\": \"${self.triggers.platform9_password}\", \"tenant\": \"${self.triggers.platform9_tenant}\", \"region\": \"${self.triggers.platform9_region}\",  \"cluster_uuid\": \"${self.triggers.cluster_uuid}\"}' |  python3 ${path.module}/scripts/delete_cluster.py"
    environment = {
      du_fqdn      = self.triggers.platform9_fqdn
      user         = self.triggers.platform9_user
      pw           = self.triggers.platform9_password
      tenant       = self.triggers.platform9_tenant
      region       = self.triggers.platform9_region
      cluster_uuid = self.triggers.cluster_uuid
    }
  }
}

