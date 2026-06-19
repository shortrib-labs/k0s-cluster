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
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.3"
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

provider "kubernetes" {
  config_path = var.cluster_k0smotron_kubeconfig != "" ? var.cluster_k0smotron_kubeconfig : null
}

provider "kubectl" {
  config_path      = var.cluster_k0smotron_kubeconfig != "" ? var.cluster_k0smotron_kubeconfig : null
  load_config_file = var.cluster_k0smotron_kubeconfig != ""
}
