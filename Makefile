tfvars := ${SECRETS_DIR}/terrform.tfvars
params_yaml := ${SECRETS_DIR}/params.yaml

cluster_name := $(shell yq .cluster_name $(params_yaml))

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

nutanix_username = "$(shell yq .nutanix.username $(params_yaml))"
nutanix_password = "$(shell sops --decrypt --extract '["nutanix"]["password"]' $(params_yaml))"
nutanix_prism_central = "$(shell yq .nutanix.prism_central $(params_yaml))"
nutanix_cluster_name = "$(shell yq .nutanix.cluster $(params_yaml))"
nutanix_storage_container = "$(shell yq .nutanix.storage_container $(params_yaml))"
kubernetes_subnet = "$(shell yq .nutanix.subnets.kubernetes $(params_yaml))"
workload_subnet = "$(shell yq .nutanix.subnets.workload $(params_yaml))"

tailscale_client_id = "$(shell sops --decrypt --extract '["tailscale"]["client_id"]' $(params_yaml))"
tailscale_client_secret = "$(shell sops --decrypt --extract '["tailscale"]["client_secret"]' $(params_yaml))"
endef

.PHONY: tfvars
tfvars: $(tfvars)

export TFVARS
$(tfvars): $(params_yaml)
	@echo "$$TFVARS" > $@

.PHONY: init
init: $(tfvars)
	@(cd $(SOURCE_DIR)/terraform && terraform init)

.PHONY: nodes
nodes: $(tfvars)
	@(cd ${SOURCE_DIR}/terraform && terraform apply -var-file $(tfvars) --auto-approve)

.PHONY: cluster
cluster: nodes
	@mkdir -p work/manifests
	@sops --decrypt ${SECRETS_DIR}/cloudflare-api-token.yaml > ${WORK_DIR}/manifests/01-cloudflare-api-token.yaml
	@k0sctl apply --config ${SECRETS_DIR}/k0sctl.yaml
	@k0sctl kubeconfig --config ${SECRETS_DIR}/k0sctl.yaml > ${SECRETS_DIR}/kubeconfig
	@export KUBECONFIG=${SECRETS_DIR}/kubeconfig && tailscale configure kubeconfig $(cluster_name)-operator
	@yq -i '.contexts[] |= (select(.name == "$(cluster_name)-operator.walrus-shark.ts.net").name = "tailscale-auth@$(cluster_name)" // .) | .contexts[] |= (select(.name == "$(cluster_name)").name = "$(cluster_name)-admin@$(cluster_name)" // .) | .contexts[] |= (select(.context.user == "admin").context.user = "$(cluster_name)-admin" // .) | .users[] |= (select(.name == "admin").name = "$(cluster_name)-admin" // .) | .current-context = "$(cluster_name)-admin@$(cluster_name)"' ${SECRETS_DIR}/kubeconfig
	@rm -rf work/manifests

.PHONY: test
test: $(tfvars)
	@(cd ${SOURCE_DIR}/terraform && terraform plan -var-file $(tfvars))

.PHONY: destroy
destroy: $(tfvars)
	@(cd ${SOURCE_DIR}/terraform && terraform destroy -var-file $(tfvars) --auto-approve)

clean:
	@rm $(tfvars)

.PHONY: encrypt
encrypt: 
	@sops --encrypt --in-place $(params_yaml)

.PHONY: decrypt
decrypt: 
	@sops --decrypt --in-place $(params_yaml)
