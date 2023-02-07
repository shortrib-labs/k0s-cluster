output "password" {
  value     = random_pet.default_password.id
  sensitive = true
}

output "control_plane_ips" {
  value     = [ for controller in vsphere_virtual_machine.control_plane : controller.default_ip_address ]
}

output "worker_ips" {
  value     = [ for worker in vsphere_virtual_machine.worker : worker.default_ip_address ]
}
