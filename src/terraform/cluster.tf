resource "local_sensitive_file" "k0sctl" {
    content  = templatefile("${local.directories.templates}/k0sctl.tftpl",
                            {
                                user = local.users.1.name

                                cluster_name = var.cluster_name
                                cluster_fqdn  = local.server_name
                                controllers = [ for controller in vsphere_virtual_machine.control_plane : controller.default_ip_address ]
                                first_controller = vsphere_virtual_machine.control_plane.0.default_ip_address
                                workers = [ for worker in vsphere_virtual_machine.worker : worker.default_ip_address ]

                                enable_gvisor = var.enable_gvisor
                                enable_wasm = var.enable_wasm

                                work_dir     = local.directories.work
                                manifest_dir = local.directories.manifests

                                tailscale_client_id     = var.tailscale_client_id
                                tailscale_client_secret = var.tailscale_client_secret
                            }
               ) 
    filename = "${local.directories.secrets}/k0sctl.yaml"
}

resource "local_sensitive_file" "user-data" {
    content  = local.user_data
    filename = "${local.directories.secrets}/user-data.yaml"
}

resource "local_sensitive_file" "vsphere_csi_conf" {
    content  = templatefile("${local.directories.templates}/vsphere-csi-config.yaml.tftpl",
                            {
                                csi_vsphere_conf = base64encode(templatefile("${local.directories.templates}/csi-vsphere.conf.tftpl", { cluster_id = local.server_name }))
                            }
               ) 
    filename = "${local.directories.work}/manifests/01-vsphere-csi-config.yaml"
}

resource "local_sensitive_file" "ip_address_pool" {
    content  = templatefile("${local.directories.templates}/default-ipaddresspool.yaml.tftpl",
                            {
                               load_balancer_cidr  = var.load_balancer_cidr
                            }
               ) 
    filename = "${local.directories.work}/manifests/00-default-ipaddresspool.yaml"
}
