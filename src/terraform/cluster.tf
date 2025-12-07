resource "local_sensitive_file" "k0sctl" {
  content = templatefile("${local.directories.templates}/k0sctl.tftpl",
    {
      user = local.users.1.name

      cluster_name     = var.cluster_name
      cluster_fqdn     = local.server_name
      controllers      = [for controller in data.nutanix_virtual_machine.control_plane : controller.nic_list[0].ip_endpoint_list[0].ip]
      first_controller = data.nutanix_virtual_machine.control_plane.0.nic_list[0].ip_endpoint_list[0].ip
      workers          = [for worker in data.nutanix_virtual_machine.worker : worker.nic_list[0].ip_endpoint_list[0].ip]

      enable_gvisor = var.enable_gvisor
      enable_wasm   = var.enable_wasm

      work_dir     = local.directories.work
      manifest_dir = local.directories.manifests

      nutanix_prism_central     = var.nutanix_prism_central
      nutanix_username          = var.nutanix_username
      nutanix_password          = var.nutanix_password
      nutanix_storage_container = var.nutanix_storage_container

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

resource "local_sensitive_file" "nutanix_csi_secret" {
  content = templatefile("${local.directories.templates}/nutanix-csi-secret.yaml.tftpl", {
    prism_endpoint    = var.nutanix_prism_central
    nutanix_username  = var.nutanix_username
    nutanix_password  = var.nutanix_password
    storage_container = var.nutanix_storage_container
  })
  filename        = "${local.directories.work}/manifests/01-nutanix-csi-secret.yaml"
  file_permission = "0600"
}

resource "local_sensitive_file" "nutanix_storageclass" {
  content = templatefile("${local.directories.templates}/nutanix-storageclass.yaml.tftpl", {
    storage_container = var.nutanix_storage_container
  })
  filename        = "${local.directories.work}/manifests/02-nutanix-storageclass.yaml"
  file_permission = "0600"
}

resource "local_sensitive_file" "ip_address_pool" {
  content = templatefile("${local.directories.templates}/default-ipaddresspool.yaml.tftpl",
    {
      load_balancer_cidr = var.load_balancer_cidr
    }
  )
  filename = "${local.directories.work}/manifests/00-default-ipaddresspool.yaml"
}
