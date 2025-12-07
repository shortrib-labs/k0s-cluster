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
