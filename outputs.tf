output "Master_IPs" {
  value = packet_device.k8s_masters.*.access_public_ipv4
}

output "Worker_IPs" {
  value = packet_device.k8s_workers.*.access_public_ipv4
}

output "Master_LB_IP" {
  value = packet_reserved_ip_block.cluster_ip.address
}