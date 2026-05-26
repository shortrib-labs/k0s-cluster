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

variable "cluster_mode" {
  type    = string
  default = "vm"
  validation {
    condition     = contains(["vm", "k0smotron"], var.cluster_mode)
    error_message = "cluster_mode must be \"vm\" or \"k0smotron\"."
  }
}

variable "cluster_k0smotron_kubeconfig" {
  type        = string
  default     = ""
  description = "Path to kubeconfig for the management cluster hosting the k0smotron control plane. Required when cluster_mode = k0smotron."
  validation {
    condition     = var.cluster_mode != "k0smotron" || var.cluster_k0smotron_kubeconfig != ""
    error_message = "cluster_k0smotron_kubeconfig must be set when cluster_mode is \"k0smotron\"."
  }
}

variable "cluster_k0smotron_namespace" {
  type    = string
  default = "clusters"
}

variable "cluster_k0smotron_external_ip" {
  type        = string
  default     = ""
  description = "Pre-reserved MetalLB IP on the mgmt cluster for the hosted apiserver. Required when cluster_mode = k0smotron."
  validation {
    condition     = var.cluster_mode != "k0smotron" || var.cluster_k0smotron_external_ip != ""
    error_message = "cluster_k0smotron_external_ip must be set when cluster_mode is \"k0smotron\"."
  }
}

variable "cluster_k0smotron_k0s_version" {
  type    = string
  default = "v1.35.2+k0s.0"
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

variable "nutanix_file_server" {
  type        = string
  description = "Nutanix Files server name for RWX storage"
}

variable "nutanix_file_server_fqdn" {
  type        = string
  description = "Nutanix Files server FQDN for CSI authentication"
}

variable "nutanix_file_server_username" {
  type        = string
  description = "Username for Nutanix Files server"
}

variable "nutanix_file_server_password" {
  type        = string
  sensitive   = true
  description = "Password for Nutanix Files server"
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
