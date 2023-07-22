terraform {
  required_providers {
    carvel = {
      source = "vmware-tanzu/carvel"
    }
    tailscale = {
      source = "tailscale/tailscale"
      version = "0.13.7"
    }
  }
}

provider "vsphere" {
  user           = var.vsphere_username
  password       = var.vsphere_password
  vsphere_server = var.vsphere_server

  allow_unverified_ssl = true
}

provider "tailscale" {
  api_key = var.tailscale_api_key
  tailnet = var.tailnet
}
