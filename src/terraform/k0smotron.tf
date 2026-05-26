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
