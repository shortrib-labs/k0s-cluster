tfvars := ${SECRETS_DIR}/terrform.tfvars
params_yaml := ${SECRETS_DIR}/params.yaml

# Set VERBOSE=1 to echo every recipe line (useful for debugging Make targets).
# By default recipes run silently (each line prefixed with $(Q) which expands
# to "@").
ifeq ($(VERBOSE),1)
Q :=
else
Q := @
endif

cluster_name := $(shell yq .cluster_name $(params_yaml))
domain := $(shell yq .domain $(params_yaml))
cluster_fqdn := $(cluster_name).$(domain)
cluster_mode := $(shell yq ".cluster.mode // \"vm\"" $(params_yaml))
cluster_k0smotron_kubeconfig := $(shell yq ".cluster.k0smotron.management_kubeconfig // \"\"" $(params_yaml))

define TFVARS
cluster_name				 = "$(cluster_name)"
domain					 = "$(shell yq e .domain $(params_yaml))"
project_root		 = "$(PROJECT_DIR)"

cluster_image_name	 = "$(shell yq .cluster_image_name $(params_yaml))"

ssh_authorized_keys = $(shell yq --output-format json .ssh.authorized_keys $(params_yaml))
users = "$(shell yq --output-format json .users $(params_yaml) | sed 's/"/\\"/g')"

controllers = "$(shell yq .cluster.controllers $(params_yaml))"
workers     = "$(shell yq .cluster.workers $(params_yaml))"

cpus			= "$(shell yq .node.cpus $(params_yaml))"
memory		= "$(shell yq .node.memory $(params_yaml))"
disk_size = "$(shell yq .node.disk_size $(params_yaml))"
control_plane_cidr	  = "$(shell yq .cluster.control_plane_cidr $(params_yaml))"
control_plane_mac     = $(shell yq --output-format json .cluster.control_plane_mac $(params_yaml))
load_balancer_cidr	  = "$(shell yq .cluster.load_balancer_cidr $(params_yaml))"

enable_gvisor = "$(shell yq '.cluster.runtimes.gvisor.enabled // false' $(params_yaml))"
enable_wasm = "$(shell yq '.cluster.runtimes.wasm.enabled // false' $(params_yaml))"

cluster_mode = "$(shell yq ".cluster.mode // \"vm\"" $(params_yaml))"
cluster_k0smotron_kubeconfig = "$(shell yq ".cluster.k0smotron.management_kubeconfig // \"\"" $(params_yaml))"
cluster_k0smotron_namespace = "$(shell yq ".cluster.k0smotron.namespace // \"clusters\"" $(params_yaml))"
cluster_k0smotron_external_ip = "$(shell yq ".cluster.k0smotron.external_ip // \"\"" $(params_yaml))"
cluster_version = "$(shell yq ".cluster.version // \"1.35.2+k0s.0\"" $(params_yaml))"

nutanix_username = "$(shell yq .nutanix.username $(params_yaml))"
nutanix_password = "$(shell sops --decrypt --extract '["nutanix"]["password"]' $(params_yaml))"
nutanix_prism_central = "$(shell yq .nutanix.prism_central $(params_yaml))"
nutanix_cluster_name = "$(shell yq .nutanix.cluster $(params_yaml))"
nutanix_storage_container = "$(shell yq .nutanix.storage_container $(params_yaml))"
nutanix_file_server = "$(shell yq .nutanix.files.server $(params_yaml))"
nutanix_file_server_fqdn = "$(shell yq .nutanix.files.fqdn $(params_yaml))"
nutanix_file_server_username = "$(shell yq .nutanix.files.username $(params_yaml))"
nutanix_file_server_password = "$(shell sops --decrypt --extract '["nutanix"]["files"]["password"]' $(params_yaml))"
kubernetes_subnet = "$(shell yq .nutanix.subnets.kubernetes $(params_yaml))"
workload_subnet = "$(shell yq .nutanix.subnets.workload $(params_yaml))"

tailscale_client_id = "$(shell sops --decrypt --extract '["tailscale"]["client_id"]' $(params_yaml))"
tailscale_client_secret = "$(shell sops --decrypt --extract '["tailscale"]["client_secret"]' $(params_yaml))"
endef

.PHONY: tfvars
tfvars: $(tfvars)

export TFVARS
$(tfvars): $(params_yaml)
	$(Q)echo "$$TFVARS" > $@

.PHONY: init
init: $(tfvars)
	$(Q)(cd $(SOURCE_DIR)/terraform && terraform init)

.PHONY: check-mode-switch
check-mode-switch:
	$(Q)$(PROJECT_DIR)/bin/check-mode-switch.sh "$(cluster_mode)" "$(SOURCE_DIR)/terraform"

.PHONY: nodes
nodes: $(tfvars) check-mode-switch
	$(Q)(cd ${SOURCE_DIR}/terraform && terraform apply -var-file $(tfvars) --auto-approve)

ifeq ($(cluster_mode),k0smotron)
.PHONY: cluster
cluster: nodes
	$(Q)until kubectl --kubeconfig=$(SECRETS_DIR)/kubeconfig get namespace cert-manager >/dev/null 2>&1; do echo "[cluster] waiting for cert-manager namespace..."; sleep 10; done
	$(Q)sops --decrypt ${SECRETS_DIR}/cloudflare-api-token.yaml | kubectl --kubeconfig=$(SECRETS_DIR)/kubeconfig apply -n cert-manager -f -
	$(Q)$(MAKE) post-cluster
else
.PHONY: cluster
cluster: nodes
	$(Q)mkdir -p work/manifests
	$(Q)sops --decrypt ${SECRETS_DIR}/cloudflare-api-token.yaml > ${WORK_DIR}/manifests/01-cloudflare-api-token.yaml
	$(Q)k0sctl apply --config ${SECRETS_DIR}/k0sctl.yaml
	$(Q)k0sctl kubeconfig --config ${SECRETS_DIR}/k0sctl.yaml > ${SECRETS_DIR}/kubeconfig
	$(Q)$(MAKE) post-cluster
	$(Q)rm -rf work/manifests
endif

.PHONY: post-cluster
post-cluster:
	$(Q)export KUBECONFIG=${SECRETS_DIR}/kubeconfig && tailscale configure kubeconfig $(cluster_name)-operator
	$(Q)yq -i '.contexts[] |= (select(.name == "$(cluster_name)-operator.walrus-shark.ts.net").name = "tailscale-auth@$(cluster_name)" // .) | .contexts[] |= (select(.name == "$(cluster_name)").name = "$(cluster_name)-admin@$(cluster_name)" // .) | .contexts[] |= (select(.context.user == "admin").context.user = "$(cluster_name)-admin" // .) | .users[] |= (select(.name == "admin").name = "$(cluster_name)-admin" // .) | .current-context = "$(cluster_name)-admin@$(cluster_name)"' ${SECRETS_DIR}/kubeconfig

.PHONY: test
test: $(tfvars)
	$(Q)if [ "$(cluster_mode)" = "k0smotron" ]; then \
	  test -n "$(cluster_k0smotron_kubeconfig)" || (echo "ERROR: cluster.k0smotron.management_kubeconfig is unset"; exit 1); \
	  kubectl --kubeconfig=$(cluster_k0smotron_kubeconfig) cluster-info; \
	fi
	$(Q)(cd ${SOURCE_DIR}/terraform && terraform plan -var-file $(tfvars))

.PHONY: destroy
destroy: $(tfvars)
	$(Q)# Remove worker host keys before destroying (IPs will be gone after)
	$(Q)(cd ${SOURCE_DIR}/terraform && terraform state list 2>/dev/null | grep nutanix_virtual_machine | xargs -I{} terraform state show {} 2>/dev/null | grep -oP 'ip\s*=\s*"\K[^"]+' | xargs -I{} ssh-keygen -R {} 2>/dev/null || true)
	$(Q)if [ "$(cluster_mode)" = "vm" ]; then ssh-keygen -R $(cluster_fqdn) 2>/dev/null || true; fi
	$(Q)if [ "$(cluster_mode)" = "k0smotron" ]; then (cd ${SOURCE_DIR}/terraform && terraform destroy -var-file $(tfvars) --auto-approve -target='kubernetes_manifest.k0smotron_remotemachine'); fi
	$(Q)(cd ${SOURCE_DIR}/terraform && terraform destroy -var-file $(tfvars) --auto-approve)

clean:
	$(Q)rm $(tfvars)

.PHONY: encrypt
encrypt:
	$(Q)sops --encrypt --in-place $(params_yaml)

.PHONY: decrypt
decrypt:
	$(Q)sops --decrypt --in-place $(params_yaml)
