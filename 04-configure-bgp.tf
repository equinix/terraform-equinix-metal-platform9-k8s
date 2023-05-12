data "template_file" "bird_conf" {
  template = file("templates/bird_conf.sh")

  vars = {
    floating_ip      = equinix_metal_reserved_ip_block.cluster_ip.address
    floating_cidr    = equinix_metal_reserved_ip_block.cluster_ip.cidr
    floating_netmask = equinix_metal_reserved_ip_block.cluster_ip.netmask
  }
}

resource "null_resource" "configure_bird" {
  count = var.master_count
  connection {
    type        = "ssh"
    user        = "root"
    private_key = chomp(tls_private_key.ssh_key_pair.private_key_pem)
    host        = element(equinix_metal_device.k8s_masters.*.access_public_ipv4, count.index)
  }

  provisioner "file" {
    content     = data.template_file.bird_conf.rendered
    destination = "/root/bird_conf.sh"
  }

  provisioner "remote-exec" {
    inline = ["bash /root/bird_conf.sh"]
  }
}
