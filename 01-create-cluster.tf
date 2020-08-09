resource "packet_reserved_ip_block" "cluster_ip" {
  project_id = packet_project.new_project.id
  facility   = var.facility
  quantity   = 1
}

data "external" "create_cluster" {
  program = ["python3", "${path.module}/scripts/create_cluster.py"]
  query = {
    du_fqdn      = var.platform9_fqdn
    user         = var.platform9_user
    pw           = var.platform9_password
    tenant       = var.platform9_tenant
    region       = var.platform9_region
    cluster_name = var.cluster_name
    k8s_api_fqdn = packet_reserved_ip_block.cluster_ip.address
  }
}

resource "null_resource" "delete_cluster" {
  provisioner "local-exec" {
    when    = "destroy"
    command = "printf '{\"du_fqdn\": \"${var.platform9_fqdn}\", \"user\": \"${var.platform9_user}\", \"pw\": \"${var.platform9_password}\", \"tenant\": \"${var.platform9_tenant}\", \"region\": \"${var.platform9_region}\",  \"cluster_uuid\": \"${lookup(data.external.create_cluster.result, "cluster_id")}\"}' |  python3 ${path.module}/scripts/delete_cluster.py"
    environment = {
      du_fqdn      = var.platform9_fqdn
      user         = var.platform9_user
      pw           = var.platform9_password
      tenant       = var.platform9_tenant
      region       = var.platform9_region
      cluster_uuid = lookup(data.external.create_cluster.result, "cluster_id")
    }
  }
}

