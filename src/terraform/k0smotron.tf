# Fail-fast guards: confirm the management cluster has the namespaces where
# this cluster's CRs (clusters/), per-cluster MetalLB pool (metallb/) and
# bootstrap ConfigMaps will live. Capybara owns the namespaces' lifecycle, not
# this terraform — plan errors here mean capybara isn't ready.
data "kubernetes_namespace" "k0smotron" {
  count = local.k0smotron ? 1 : 0
  metadata {
    name = var.cluster_k0smotron_namespace
  }
}

data "kubernetes_namespace" "metallb" {
  count = local.k0smotron ? 1 : 0
  metadata {
    name = "metallb"
  }
}

# Per-cluster MetalLB IPAddressPool and L2Advertisement on the mgmt cluster.
# A single /32 pool scoped (by namespace + cluster-name label) to this workload
# cluster's hosted apiserver LB Service, so the LB lands deterministically on
# var.cluster_k0smotron_external_ip rather than whatever the default pool picks.
# Pool must exist before k0smotron creates the LB Service.
resource "kubectl_manifest" "metallb_ipaddresspool" {
  count = local.k0smotron ? 1 : 0
  yaml_body = templatefile("${local.directories.templates}/metallb-ipaddresspool.yaml.tftpl", {
    cluster_name        = var.cluster_name
    namespace           = data.kubernetes_namespace.metallb[0].metadata[0].name
    external_ip         = var.cluster_k0smotron_external_ip
    k0smotron_namespace = data.kubernetes_namespace.k0smotron[0].metadata[0].name
  })
}

resource "kubectl_manifest" "metallb_l2advertisement" {
  count = local.k0smotron ? 1 : 0
  yaml_body = templatefile("${local.directories.templates}/metallb-l2advertisement.yaml.tftpl", {
    cluster_name = var.cluster_name
    namespace    = data.kubernetes_namespace.metallb[0].metadata[0].name
  })
  depends_on = [kubectl_manifest.metallb_ipaddresspool]
}

# Bootstrap SSH keypair for k0smotron RemoteMachine worker join.
# Public half is injected into worker cloud-init alongside operator keys.
# Private half is staged as a Secret on the management cluster so the
# k0smotron CAPI infra provider can SSH into workers to install k0s.
resource "tls_private_key" "bootstrap_ssh" {
  count     = local.k0smotron ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "kubernetes_secret" "bootstrap_ssh" {
  count = local.k0smotron ? 1 : 0

  metadata {
    name      = "${var.cluster_name}-bootstrap-ssh"
    namespace = data.kubernetes_namespace.k0smotron[0].metadata[0].name
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
  count = local.k0smotron ? 1 : 0

  metadata {
    name      = "${var.cluster_name}-nutanix-csi-secret"
    namespace = data.kubernetes_namespace.k0smotron[0].metadata[0].name
  }

  data = {
    "01-nutanix-csi-secret.yaml" = local.nutanix_csi_secret_yaml
  }

  type = "Opaque"
}

resource "kubernetes_config_map" "nutanix_csi_config" {
  count = local.k0smotron ? 1 : 0

  metadata {
    name      = "${var.cluster_name}-nutanix-csi-config"
    namespace = data.kubernetes_namespace.k0smotron[0].metadata[0].name
  }

  data = {
    "02-nutanix-storageclass.yaml"       = local.nutanix_storageclass_yaml
    "03-nutanix-files-storageclass.yaml" = local.nutanix_files_storageclass_yaml
  }
}

resource "kubernetes_config_map" "metallb_config" {
  count = local.k0smotron ? 1 : 0

  metadata {
    name      = "${var.cluster_name}-metallb-config"
    namespace = data.kubernetes_namespace.k0smotron[0].metadata[0].name
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

# Cert-manager CRDs are split by API group (cert-manager.io core vs
# acme.cert-manager.io) because the combined upstream bundle exceeds the 1 MiB
# ConfigMap size limit. The workload manifest is a third ConfigMap reconciled
# after the CRDs.
resource "kubernetes_config_map" "cert_manager_crds_core" {
  count = local.k0smotron ? 1 : 0

  metadata {
    name      = "${var.cluster_name}-cert-manager-crds-core"
    namespace = data.kubernetes_namespace.k0smotron[0].metadata[0].name
  }

  data = {
    "00-cert-manager-crds-core.yaml" = file("${local.directories.manifests}/cert-manager/00-cert-manager-crds-core.yaml")
  }

  lifecycle {
    precondition {
      condition     = length(file("${local.directories.manifests}/cert-manager/00-cert-manager-crds-core.yaml")) < 950000
      error_message = "manifests/cert-manager/00-cert-manager-crds-core.yaml exceeds 950000 bytes — too close to the 1 MiB ConfigMap limit. Re-split the bundle."
    }
  }
}

resource "kubernetes_config_map" "cert_manager_crds_acme" {
  count = local.k0smotron ? 1 : 0

  metadata {
    name      = "${var.cluster_name}-cert-manager-crds-acme"
    namespace = data.kubernetes_namespace.k0smotron[0].metadata[0].name
  }

  data = {
    "01-cert-manager-crds-acme.yaml" = file("${local.directories.manifests}/cert-manager/01-cert-manager-crds-acme.yaml")
  }

  lifecycle {
    precondition {
      condition     = length(file("${local.directories.manifests}/cert-manager/01-cert-manager-crds-acme.yaml")) < 950000
      error_message = "manifests/cert-manager/01-cert-manager-crds-acme.yaml exceeds 950000 bytes — too close to the 1 MiB ConfigMap limit. Re-split the bundle."
    }
  }
}

resource "kubernetes_config_map" "cert_manager" {
  count = local.k0smotron ? 1 : 0

  metadata {
    name      = "${var.cluster_name}-cert-manager"
    namespace = data.kubernetes_namespace.k0smotron[0].metadata[0].name
  }

  data = {
    "02-cert-manager.yaml" = file("${local.directories.manifests}/cert-manager/02-cert-manager.yaml")
  }
}

resource "kubernetes_secret" "cloudflare_api_token" {
  count = local.k0smotron ? 1 : 0

  metadata {
    name      = "${var.cluster_name}-cloudflare-api-token"
    namespace = data.kubernetes_namespace.k0smotron[0].metadata[0].name
  }

  data = {
    "01-cloudflare-api-token.yaml" = local.cloudflare_api_token_yaml
  }

  type = "Opaque"
}

resource "kubernetes_config_map" "acme" {
  count = local.k0smotron ? 1 : 0

  metadata {
    name      = "${var.cluster_name}-acme"
    namespace = data.kubernetes_namespace.k0smotron[0].metadata[0].name
  }

  data = { for f in fileset(local.directories.manifests, "acme/*.yaml") : basename(f) => file("${local.directories.manifests}/${f}") }
}

# Optional runtime classes (gvisor, wasmtime-spin) only ship when enabled.
resource "kubernetes_config_map" "runtimes" {
  count = local.k0smotron && (var.enable_gvisor || var.enable_wasm) ? 1 : 0

  metadata {
    name      = "${var.cluster_name}-runtimes"
    namespace = data.kubernetes_namespace.k0smotron[0].metadata[0].name
  }

  data = merge(
    var.enable_gvisor ? { "gvisor.yaml" = file("${local.directories.manifests}/runtimes/gvisor.yaml") } : {},
    var.enable_wasm ? { "wasmtime-spin.yaml" = file("${local.directories.manifests}/runtimes/wasmtime-spin.yaml") } : {}
  )
}

# CAPI Cluster + sibling RemoteCluster establish the workload-cluster identity
# on the mgmt cluster. K0smotronControlPlane reconciles the hosted apiserver
# pods. Per-worker Machine/RemoteMachine/K0sWorkerConfig triplets cause the
# k0smotron CAPI infra provider to SSH into each worker VM and install k0s.
#
# These use kubectl_manifest (alekc/kubectl) rather than kubernetes_manifest so
# that resources referencing values known-after-apply (e.g. worker IPs from the
# nutanix data source) don't fail plan-time schema validation.
resource "kubectl_manifest" "k0smotron_cluster" {
  count = local.k0smotron ? 1 : 0
  yaml_body = templatefile("${local.directories.templates}/k0smotron-cluster.yaml.tftpl", {
    cluster_name = var.cluster_name
    namespace    = data.kubernetes_namespace.k0smotron[0].metadata[0].name
  })
}

resource "kubectl_manifest" "k0smotron_remotecluster" {
  count = local.k0smotron ? 1 : 0
  yaml_body = templatefile("${local.directories.templates}/k0smotron-remotecluster.yaml.tftpl", {
    cluster_name = var.cluster_name
    namespace    = data.kubernetes_namespace.k0smotron[0].metadata[0].name
  })
}

resource "kubectl_manifest" "k0smotron_controlplane" {
  count = local.k0smotron ? 1 : 0
  yaml_body = templatefile("${local.directories.templates}/k0smotron-controlplane.yaml.tftpl", {
    cluster_name            = var.cluster_name
    namespace               = data.kubernetes_namespace.k0smotron[0].metadata[0].name
    external_ip             = var.cluster_k0smotron_external_ip
    k0s_version             = "v${var.cluster_version}"
    cluster_fqdn            = local.server_name
    tailscale_client_id     = var.tailscale_client_id
    tailscale_client_secret = var.tailscale_client_secret
    enable_runtimes         = var.enable_gvisor || var.enable_wasm
  })
  depends_on = [
    kubernetes_secret.nutanix_csi,
    kubernetes_secret.cloudflare_api_token,
    kubernetes_config_map.nutanix_csi_config,
    kubernetes_config_map.metallb_config,
    kubernetes_config_map.cert_manager,
    kubernetes_config_map.cert_manager_crds_core,
    kubernetes_config_map.cert_manager_crds_acme,
    kubernetes_config_map.acme,
    kubernetes_config_map.runtimes,
    kubectl_manifest.metallb_ipaddresspool,
    kubectl_manifest.metallb_l2advertisement,
  ]
}

resource "kubectl_manifest" "k0smotron_machine" {
  for_each = local.k0smotron ? { for i, w in data.nutanix_virtual_machine.worker : tostring(i) => w } : {}
  yaml_body = templatefile("${local.directories.templates}/k0smotron-machine.yaml.tftpl", {
    cluster_name = var.cluster_name
    namespace    = data.kubernetes_namespace.k0smotron[0].metadata[0].name
    index        = each.key
  })
  depends_on = [kubectl_manifest.k0smotron_cluster]
}

resource "kubectl_manifest" "k0smotron_remotemachine" {
  for_each = local.k0smotron ? { for i, w in data.nutanix_virtual_machine.worker : tostring(i) => w } : {}
  yaml_body = templatefile("${local.directories.templates}/k0smotron-remotemachine.yaml.tftpl", {
    cluster_name = var.cluster_name
    namespace    = data.kubernetes_namespace.k0smotron[0].metadata[0].name
    index        = each.key
    worker_ip    = each.value.nic_list[0].ip_endpoint_list[0].ip
    ssh_user     = "ubuntu"
  })
  depends_on = [
    kubernetes_secret.bootstrap_ssh,
    kubectl_manifest.k0smotron_controlplane,
  ]
}

resource "kubectl_manifest" "k0smotron_workerconfig" {
  for_each = local.k0smotron ? { for i, w in data.nutanix_virtual_machine.worker : tostring(i) => w } : {}
  yaml_body = templatefile("${local.directories.templates}/k0smotron-workerconfig.yaml.tftpl", {
    cluster_name = var.cluster_name
    namespace    = data.kubernetes_namespace.k0smotron[0].metadata[0].name
    index        = each.key
    k0s_version  = "v${var.cluster_version}"
  })
}

# Wait for the hosted control plane to come up before reading its kubeconfig.
# 15-minute timeout accommodates cold-start image pulls on a fresh mgmt cluster.
resource "null_resource" "wait_control_plane" {
  count = local.k0smotron ? 1 : 0

  triggers = {
    cluster_name = var.cluster_name
  }

  provisioner "local-exec" {
    command = "kubectl --kubeconfig=${var.cluster_k0smotron_kubeconfig} -n ${var.cluster_k0smotron_namespace} wait --for=condition=ControlPlaneAvailable --timeout=15m cluster/${var.cluster_name}"
  }

  depends_on = [kubectl_manifest.k0smotron_controlplane]
}

data "kubernetes_secret" "workload_kubeconfig" {
  count = local.k0smotron ? 1 : 0

  metadata {
    name      = "${var.cluster_name}-kubeconfig"
    namespace = data.kubernetes_namespace.k0smotron[0].metadata[0].name
  }

  depends_on = [null_resource.wait_control_plane]
}

resource "local_sensitive_file" "workload_kubeconfig" {
  count           = local.k0smotron ? 1 : 0
  content         = data.kubernetes_secret.workload_kubeconfig[0].data["value"]
  filename        = "${local.directories.secrets}/kubeconfig"
  file_permission = "0600"
}
