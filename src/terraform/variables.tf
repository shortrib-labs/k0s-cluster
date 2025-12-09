variable "project_root" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "domain" {
  type = string
}

variable "controllers" {
  type    = string
  default = 1
}

variable "workers" {
  type    = string
  default = 0
}

variable "cluster_image_name" {
  type = string
}

variable "ssh_authorized_keys" {
  type = list(any)
}

variable "users" {
  type = string
}

variable "control_plane_cidr" {
  type = string
}

variable "load_balancer_cidr" {
  type = string
}

variable "enable_gvisor" {
  type    = bool
  default = false
}

variable "enable_wasm" {
  type    = bool
  default = false
}

variable "cpus" {
  type    = number
  default = 4
}

variable "memory" {
  type    = number
  default = 8192
}

variable "disk_size" {
  type    = number
  default = 52
}

# Nutanix Authentication
variable "nutanix_username" {
  type        = string
  description = "Nutanix Prism Central username"
}

variable "nutanix_password" {
  type        = string
  description = "Nutanix Prism Central password"
  sensitive   = true
}

variable "nutanix_prism_central" {
  type        = string
  description = "Nutanix Prism Central endpoint (IP or FQDN)"
}

# Nutanix Infrastructure
variable "nutanix_cluster_name" {
  type        = string
  description = "Nutanix cluster name for VM placement"
}

variable "nutanix_storage_container" {
  type        = string
  description = "Storage container for VM disks"
}

variable "kubernetes_subnet" {
  type        = string
  description = "Nutanix subnet for Kubernetes management network"
}

variable "workload_subnet" {
  type        = string
  description = "Nutanix subnet for workload network"
}

variable "control_plane_mac" {
  type        = list(string)
  description = "MAC addresses for control plane nodes"
}

variable "tailscale_client_id" {
  type = string
}

variable "tailscale_client_secret" {
  type = string
}


locals {
  vm_prefix   = var.cluster_name
  server_name = "${var.cluster_name}.${var.domain}"
  users       = jsondecode(var.users)
  directories = {
    secrets   = "${var.project_root}/secrets"
    manifests = "${var.project_root}/manifests"
    templates = "${path.module}/templates"
    work      = "${var.project_root}/work"
  }
}
