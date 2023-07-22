data "vsphere_datacenter" "datacenter" {
  name = var.vsphere_datacenter
}

data "vsphere_datastore" "datastore" {
  name          = var.vsphere_datastore
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_compute_cluster" "cluster" {
  name          = var.vsphere_cluster
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_resource_pool" "resource_pool" {
  name          = var.vsphere_resource_pool
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_host" "host" {
  name          = var.vsphere_host
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_network" "kubernetes_network" {
  name          = var.kubernetes_network
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_network" "workload_network" {
  name          = var.workload_network
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

resource "random_pet" "default_password" {
  length = 4
}

locals {
  user_data = templatefile("${local.directories.templates}/user-data.tftpl",
                             {
                               ssh_authorized_keys = yamlencode(var.ssh_authorized_keys)
                               users = yamlencode(local.users)
                             }
                          )
}

resource "random_id" "control_plane" {
  byte_length = 4
  
}

resource "vsphere_virtual_machine" "control_plane" {
  name     = "${local.vm_prefix}-control-plane-${random_id.control_plane.hex}"
  count    = var.controllers

  datacenter_id    = data.vsphere_datacenter.datacenter.id
  datastore_id     = data.vsphere_datastore.datastore.id
  resource_pool_id = data.vsphere_resource_pool.resource_pool.id
  host_system_id   = data.vsphere_host.host.id
  folder           = var.vsphere_folder

  num_cpus = var.cpus
  memory   = var.memory
  guest_id = "ubuntu64Guest"
  hardware_version = 19

  network_interface {
    network_id     = data.vsphere_network.kubernetes_network.id
    use_static_mac = true
    mac_address    = var.control_plane_mac[count.index]
  }

  network_interface {
    network_id     = data.vsphere_network.workload_network.id
  }

  disk {
    label            = "disk0"
    size             = var.disk_size
    unit_number      = 0

    io_share_count   = 1000

    thin_provisioned = true
  }
  enable_disk_uuid = true


  cdrom {
    client_device = true
  }

  vapp {
    properties = {
      "instance-id" = "id-${local.vm_prefix}-control-plane-${random_id.control_plane.hex}"
      "hostname"    = local.vm_prefix
      "password"    = random_pet.default_password.id
      "user-data"   = base64encode(local.user_data)
    }
  }

  ovf_deploy { 
    remote_ovf_url = var.remote_ovf_url 
    allow_unverified_ssl_cert = true

    ip_protocol          = "IPV4"
    ip_allocation_policy = "STATIC_MANUAL"
    disk_provisioning    = "thin"
  }

  extra_config = {
    "isolation.tools.copy.disable"         = "FALSE"
    "isolation.tools.paste.disable"        = "FALSE"
    "isolation.tools.SetGUIOptions.enable" = "TRUE"
  }

}

resource "random_id" "worker" {
  count       = var.workers
  byte_length = 4
}

resource "vsphere_virtual_machine" "worker" {
  name     = "${local.vm_prefix}-worker-${random_id.worker[count.index].hex}"
  count    = var.workers

  datacenter_id    = data.vsphere_datacenter.datacenter.id
  datastore_id     = data.vsphere_datastore.datastore.id
  resource_pool_id = data.vsphere_resource_pool.resource_pool.id
  host_system_id   = data.vsphere_host.host.id
  folder           = var.vsphere_folder

  num_cpus = var.cpus
  memory   = var.memory
  guest_id = "ubuntu64Guest"
  hardware_version = 19

  network_interface {
    network_id     = data.vsphere_network.kubernetes_network.id
  }

  network_interface {
    network_id     = data.vsphere_network.workload_network.id
  }

  disk {
    label            = "disk0"
    size             = var.disk_size
    unit_number      = 0

    io_share_count   = 1000

    thin_provisioned = true
  }
  enable_disk_uuid = true

  cdrom {
    client_device = true
  }

  vapp {
    properties = {
      "instance-id" = "id-${local.vm_prefix}-worker-${random_id.worker[count.index].hex}"
      "hostname"    = "${local.vm_prefix}-worker-${random_id.worker[count.index].hex}"
      "password"    = random_pet.default_password.id
      "user-data"   = base64encode(local.user_data)
    }
  }

  ovf_deploy { 
    remote_ovf_url = var.remote_ovf_url 
    allow_unverified_ssl_cert = true

    ip_protocol          = "IPV4"
    ip_allocation_policy = "DHCP"
    disk_provisioning    = "thin"
  }

  extra_config = {
    "isolation.tools.copy.disable"         = "FALSE"
    "isolation.tools.paste.disable"        = "FALSE"
    "isolation.tools.SetGUIOptions.enable" = "TRUE"
  }

}

