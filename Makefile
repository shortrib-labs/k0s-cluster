tfvars := ${SECRETS_DIR}/terrform.tfvars
params_yaml := ${SECRETS_DIR}/params.yaml

cluster_name := $(shell yq .cluster_name $(params_yaml))

define TFVARS
cluster_name				 = "$(cluster_name)"
domain					 = "$(shell yq e .domain $(params_yaml))"
project_root		 = "$(PROJECT_DIR)"

remote_ovf_url	 = "$(shell yq .remote_ovf_url $(params_yaml))"

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

vsphere_server    = "$(shell yq .vsphere.server $(params_yaml))"
vsphere_username  = "$(shell yq .vsphere.username $(params_yaml))"
vsphere_password  = "$(shell sops --decrypt --extract '["vsphere"]["password"]' $(params_yaml))"

vsphere_datacenter		= "$(shell yq .vsphere.datacenter $(params_yaml))"
vsphere_cluster				= "$(shell yq .vsphere.cluster $(params_yaml))"
vsphere_host					= "$(shell yq .vsphere.host $(params_yaml))"
vsphere_resource_pool = "$(shell yq .vsphere.resource_pool $(params_yaml))"

kubernetes_network	  = "$(shell yq .vsphere.kubernetes_network $(params_yaml))"
workload_network	  = "$(shell yq .vsphere.workload_network $(params_yaml))"
vsphere_datastore = "$(shell yq .vsphere.datastore $(params_yaml))"
vsphere_folder	  = "$(shell yq .vsphere.folder $(params_yaml))"

tailnet           = "$(shell yq .tailscale.tailnet $(params_yaml))"
tailscale_api_key = "$(shell sops --decrypt --extract '["tailscale"]["api-key"]' $(params_yaml))"
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
	@sops --decrypt ${SECRETS_DIR}/tailscale-authkey.yaml > ${WORK_DIR}/manifests/01-tailscale-authkey.yaml
	@k0sctl apply --disable-telemetry --config ${SECRETS_DIR}/k0sctl.yaml
	@k0sctl kubeconfig --disable-telemetry --config ${SECRETS_DIR}/k0sctl.yaml > ${SECRETS_DIR}/kubeconfig
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
