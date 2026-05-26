output "password" {
  value     = random_pet.default_password.id
  sensitive = true
}

output "control_plane_ips" {
  value = [
    for controller in data.nutanix_virtual_machine.control_plane :
    controller.nic_list[0].ip_endpoint_list[0].ip
  ]
  description = "IP addresses of control plane nodes"
}

output "worker_ips" {
  value = [
    for worker in data.nutanix_virtual_machine.worker :
    worker.nic_list[0].ip_endpoint_list[0].ip
  ]
  description = "IP addresses of worker nodes"
}

output "k0smotron_endpoint" {
  value       = var.cluster_k0smotron_external_ip
  description = "External IP for the workload apiserver in k0smotron mode; empty in VM mode."
}

output "workload_kubeconfig_secret" {
  value = var.cluster_mode == "k0smotron" ? {
    name      = "${var.cluster_name}-kubeconfig"
    namespace = var.cluster_k0smotron_namespace
  } : null
  description = "Mgmt-cluster Secret holding the workload cluster's admin kubeconfig (k0smotron mode only)."
}
