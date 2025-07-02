output "password" {
  value     = random_pet.default_password.id
  sensitive = true
}

output "control_plane_ips" {
  value     = [ for controller in vsphere_virtual_machine.control_plane : controller.guest_ip_addresses.0 ]
}

output "worker_ips" {
  value     = [ for worker in vsphere_virtual_machine.worker : worker.guest_ip_addresses.0 ]
}

output "manual_worker_ids" {
  value     = random_id.manual_workers.*.hex
}
