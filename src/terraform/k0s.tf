resource "local_sensitive_file" "k0sctl" {
    content  = templatefile("${local.directories.templates}/k0sctl.tftpl",
                            {
                                user = local.users.1.name

                                cluster_name = var.cluster_name

                                cluster_fqdn  = local.server_name
                                controllers = [ for controller in vsphere_virtual_machine.control_plane : controller.default_ip_address ]
                                workers = [ for worker in vsphere_virtual_machine.worker : worker.default_ip_address ]
                            }
               ) 
    filename = "${local.directories.secrets}/k0sctl.yaml"
}

resource "local_sensitive_file" "user-data" {
    content  = local.user_data
    filename = "${local.directories.secrets}/user-data.yaml"
}
