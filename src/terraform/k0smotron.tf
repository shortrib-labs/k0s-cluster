# Bootstrap SSH keypair for k0smotron RemoteMachine worker join.
# Public half is injected into worker cloud-init alongside operator keys.
# Private half is staged as a Secret on the management cluster so the
# k0smotron CAPI infra provider can SSH into workers to install k0s.
resource "tls_private_key" "bootstrap_ssh" {
  count     = var.cluster_mode == "k0smotron" ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "kubernetes_secret" "bootstrap_ssh" {
  count = var.cluster_mode == "k0smotron" ? 1 : 0

  metadata {
    name      = "${var.cluster_name}-bootstrap-ssh"
    namespace = var.cluster_k0smotron_namespace
  }

  data = {
    value = tls_private_key.bootstrap_ssh[0].private_key_pem
  }

  type = "Opaque"
}

# Bootstrap manifests delivered as ConfigMaps/Secret on the management cluster.
# In VM mode these same files are scp'd to /var/lib/k0s/manifests/ on the first
# controller; in k0smotron mode the hosted control plane mounts them via
# K0smotronControlPlane.spec.manifests so the workload cluster gets the same
# bootstrap content (storage classes, MetalLB pool, cert-manager, ACME issuers).

resource "kubernetes_secret" "nutanix_csi" {
  count = var.cluster_mode == "k0smotron" ? 1 : 0

  metadata {
    name      = "${var.cluster_name}-nutanix-csi-secret"
    namespace = var.cluster_k0smotron_namespace
  }

  data = {
    "01-nutanix-csi-secret.yaml" = templatefile("${local.directories.templates}/nutanix-csi-secret.yaml.tftpl", {
      prism_endpoint       = var.nutanix_prism_central
      nutanix_username     = var.nutanix_username
      nutanix_password     = var.nutanix_password
      storage_container    = var.nutanix_storage_container
      file_server_fqdn     = var.nutanix_file_server_fqdn
      file_server_username = var.nutanix_file_server_username
      file_server_password = var.nutanix_file_server_password
    })
  }

  type = "Opaque"
}

resource "kubernetes_config_map" "nutanix_csi_config" {
  count = var.cluster_mode == "k0smotron" ? 1 : 0

  metadata {
    name      = "${var.cluster_name}-nutanix-csi-config"
    namespace = var.cluster_k0smotron_namespace
  }

  data = {
    "02-nutanix-storageclass.yaml" = templatefile("${local.directories.templates}/nutanix-storageclass.yaml.tftpl", {
      storage_container = var.nutanix_storage_container
    })
    "03-nutanix-files-storageclass.yaml" = templatefile("${local.directories.templates}/nutanix-files-storageclass.yaml.tftpl", {
      file_server = var.nutanix_file_server
    })
  }
}

resource "kubernetes_config_map" "metallb_config" {
  count = var.cluster_mode == "k0smotron" ? 1 : 0

  metadata {
    name      = "${var.cluster_name}-metallb-config"
    namespace = var.cluster_k0smotron_namespace
  }

  data = merge(
    {
      "00-default-ipaddresspool.yaml" = templatefile(
        "${local.directories.templates}/default-ipaddresspool.yaml.tftpl",
        { load_balancer_cidr = var.load_balancer_cidr }
      )
    },
    { for f in fileset(local.directories.manifests, "metallb-config/*.yaml") : basename(f) => file("${local.directories.manifests}/${f}") }
  )
}

# Cert-manager CRDs and workload manifests live in separate ConfigMaps because
# the combined upstream YAML (~993 KiB) exceeds the 1 MiB ConfigMap size limit.
resource "kubernetes_config_map" "cert_manager_crds" {
  count = var.cluster_mode == "k0smotron" ? 1 : 0

  metadata {
    name      = "${var.cluster_name}-cert-manager-crds"
    namespace = var.cluster_k0smotron_namespace
  }

  data = {
    "00-cert-manager-crds.yaml" = file("${local.directories.manifests}/cert-manager/00-cert-manager-crds.yaml")
  }
}

resource "kubernetes_config_map" "cert_manager" {
  count = var.cluster_mode == "k0smotron" ? 1 : 0

  metadata {
    name      = "${var.cluster_name}-cert-manager"
    namespace = var.cluster_k0smotron_namespace
  }

  data = {
    "01-cert-manager.yaml" = file("${local.directories.manifests}/cert-manager/01-cert-manager.yaml")
  }
}

resource "kubernetes_config_map" "acme" {
  count = var.cluster_mode == "k0smotron" ? 1 : 0

  metadata {
    name      = "${var.cluster_name}-acme"
    namespace = var.cluster_k0smotron_namespace
  }

  data = { for f in fileset(local.directories.manifests, "acme/*.yaml") : basename(f) => file("${local.directories.manifests}/${f}") }
}

# Optional runtime classes (gvisor, wasmtime-spin) only ship when enabled.
resource "kubernetes_config_map" "runtimes" {
  count = var.cluster_mode == "k0smotron" && (var.enable_gvisor || var.enable_wasm) ? 1 : 0

  metadata {
    name      = "${var.cluster_name}-runtimes"
    namespace = var.cluster_k0smotron_namespace
  }

  data = merge(
    var.enable_gvisor ? { "gvisor.yaml" = file("${local.directories.manifests}/runtimes/gvisor.yaml") } : {},
    var.enable_wasm ? { "wasmtime-spin.yaml" = file("${local.directories.manifests}/runtimes/wasmtime-spin.yaml") } : {}
  )
}
