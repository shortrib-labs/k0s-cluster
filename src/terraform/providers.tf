terraform {
  required_providers {
    carvel = {
      source = "vmware-tanzu/carvel"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = "0.13.7"
    }
    nutanix = {
      source  = "nutanix/nutanix"
      version = "~> 2.3"
    }
  }
}

provider "nutanix" {
  username     = var.nutanix_username
  password     = var.nutanix_password
  endpoint     = var.nutanix_prism_central
  port         = 9440
  insecure     = true # For self-signed certificates
  wait_timeout = 60
}

