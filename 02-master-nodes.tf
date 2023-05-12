data "template_file" "master_bootstrap" {
  template = file("templates/bootstrap.sh")
  vars = {
    is_master                         = true
    du_fqdn                           = var.platform9_fqdn
    keystone_user                     = var.platform9_user
    keystone_password                 = var.platform9_password
    cluster_uuid                      = lookup(data.external.create_cluster.result, "cluster_id")
    node_pool_uuid                    = lookup(data.external.create_cluster.result, "node_pool_uuid")
    hostagent_installer_type          = var.hostagent_installer_type
    hostagent_install_failure_webhook = var.hostagent_install_failure_webhook
    hostagent_install_options         = var.hostagent_install_options
    http_proxy                        = var.http_proxy
    is_spot_instance                  = var.is_spot_instance
  }
}

resource "equinix_metal_device" "k8s_masters" {
  depends_on = [
    equinix_metal_ssh_key.ssh_pub_key
  ]
  count            = var.master_count
  hostname         = format("%s-master%02d", var.cluster_name, count.index + 1)
  plan             = var.master_size
  operating_system = var.operating_system
  billing_cycle    = var.billing_cycle
  project_id       = equinix_metal_project.new_project.id
  user_data        = data.template_file.master_bootstrap.rendered
}

resource "equinix_metal_bgp_session" "master_bgp_session" {
  count          = var.master_count
  device_id      = element(equinix_metal_device.k8s_masters.*.id, count.index)
  address_family = "ipv4"
}

