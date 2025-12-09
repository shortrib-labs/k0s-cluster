resource "random_id" "worker" {
  count       = var.workers
  byte_length = 4
}

resource "random_uuid" "worker" {
  count = var.workers
}

resource "nutanix_virtual_machine" "worker" {
  count       = var.workers
  name        = "${local.vm_prefix}-worker-${random_id.worker[count.index].hex}"
  description = "k0s worker node"

  # CPU and memory configuration
  num_sockets          = 1
  num_vcpus_per_socket = var.cpus
  memory_size_mib      = var.memory

  # Cluster placement
  cluster_uuid = data.nutanix_cluster.cluster.id

  # Boot type - Ubuntu cloud images use UEFI
  boot_type = "UEFI"

  # Boot disk cloned from cloud image
  disk_list {
    data_source_reference = {
      kind = "image"
      uuid = data.nutanix_image.ubuntu_cloud_image.id
    }
    disk_size_bytes = var.disk_size * 1024 * 1024 * 1024
  }

  # Primary NIC - Kubernetes network with DHCP
  nic_list {
    subnet_uuid = data.nutanix_subnet.kubernetes_subnet.id
  }

  # Secondary NIC - Workload network with DHCP
  nic_list {
    subnet_uuid = data.nutanix_subnet.workload_subnet.id
  }

  # Cloud-init configuration
  guest_customization_cloud_init_meta_data = base64encode(jsonencode({
    "instance-id"    = random_uuid.worker[count.index].result
    "uuid"           = random_uuid.worker[count.index].result
    "local-hostname" = "${local.vm_prefix}-worker-${random_id.worker[count.index].hex}"
  }))
  guest_customization_cloud_init_user_data = base64encode(local.user_data)

  lifecycle {
    ignore_changes = [
      # Allow Nutanix to manage power state
      power_state,
    ]
  }
}

data "nutanix_virtual_machine" "worker" {
  count = var.workers
  vm_id = nutanix_virtual_machine.worker[count.index].id
}
