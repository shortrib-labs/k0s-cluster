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

variable "vsphere_network" {
  type = string
}

variable "vsphere_resource_pool" {
  type = string
}

variable "vsphere_folder" {
  type = string
}

locals {
  vm_prefix      = var.cluster_name
  server_name    = "${var.cluster_name}.${var.domain}"
  vsphere_folder = "${var.vsphere_datacenter}/vm/${var.vsphere_folder}"
  users = jsondecode(var.users)
  directories = {
    work = "${var.project_root}/work"
    secrets = "${var.project_root}/secrets"
    templates = "${path.module}/templates"
  }
}
