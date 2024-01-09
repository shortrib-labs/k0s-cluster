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
  type = string
  default = 1
}

variable "workers" {
  type = string
  default = 0
}

variable "remote_ovf_url" {
  type = string
}

variable "ssh_authorized_keys" {
  type = list
}

variable "users" {
  type = string
}

variable "control_plane_mac" {
  type = list
}

variable "control_plane_cidr" {
  type = string
}

variable "load_balancer_cidr" {
  type = string
}

variable "enable_gvisor" {
  type = bool
  default = false
}

variable "enable_wasm" {
  type = bool
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

variable "vsphere_server" {
  type = string
}

variable "vsphere_username" {
  type = string
}

variable "vsphere_password" {
  type = string
}

variable "vsphere_datacenter" {
  type = string
}

variable "vsphere_cluster" {
  type = string
}

variable "vsphere_host" {
  type = string
}

variable "vsphere_datastore" {
  type = string
}

variable "kubernetes_network" {
  type = string
}

variable "workload_network" {
  type = string
}

variable "vsphere_resource_pool" {
  type = string
}

variable "vsphere_folder" {
  type = string
}

variable "tailnet" {
  type = string
}

variable "tailscale_api_key" {
  type = string
}

locals {
  vm_prefix      = var.cluster_name
  server_name    = "${var.cluster_name}.${var.domain}"
  vsphere_folder = "${var.vsphere_datacenter}/vm/${var.vsphere_folder}"
  users = jsondecode(var.users)
  directories = {
    secrets   = "${var.project_root}/secrets"
    manifests = "${var.project_root}/manifests"
    templates = "${path.module}/templates"
    work      = "${var.project_root}/work"
  }
}
