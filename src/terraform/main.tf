# Nutanix cluster reference using v1 API (more compatible)
data "nutanix_cluster" "cluster" {
  name = var.nutanix_cluster_name
}

# Kubernetes management network using v1 API
data "nutanix_subnet" "kubernetes_subnet" {
  subnet_name = var.kubernetes_subnet
}

# Workload network using v1 API
data "nutanix_subnet" "workload_subnet" {
  subnet_name = var.workload_subnet
}

# Ubuntu 24.04 Noble cloud image for k0s
# Using v1 resource to download image directly from URL
data "nutanix_image" "ubuntu_cloud_image" {
  image_name = var.cluster_image_name
}

resource "random_pet" "default_password" {
  length = 4
}

locals {
  user_data = templatefile("${local.directories.templates}/user-data.tftpl",
    {
      ssh_authorized_keys = yamlencode(var.ssh_authorized_keys)
      users               = yamlencode(local.users)
    }
  )
}
