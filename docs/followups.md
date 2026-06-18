# Follow-ups: k0smotron cluster mode

Items deferred during ce-code-review on refactor/crdant/enables-k0smotron.

## F5: Worker IP read race in RemoteMachine address

**File:** `src/terraform/k0smotron.tf:205`

Nutanix provider `wait_timeout: 60` may be too short for DHCP + cloud-init before the data source resolves the worker IP. A RemoteMachine with `address: ""` causes silent SSH-bootstrap failure (K0smotronControlPlane reports Ready regardless).

Pick one after observing actual Nutanix DHCP timing:
- Bump `wait_timeout` to 300s on the nutanix provider
- Add `precondition` on `kubernetes_manifest.k0smotron_remotemachine` asserting IP is non-empty
- Add an interstitial `null_resource` that polls until IP is present

## F7: yq context-rename assumes k0sctl kubeconfig shape

**File:** `Makefile:95` (cluster target post-cluster yq block)

Selectors target user `admin` and context `<cluster_name>`. k0smotron-generated kubeconfig may use CAPI conventions (`<cluster>-admin` user, `<cluster>-admin@<cluster>` context). Need to verify against actual output from a real apply and update the yq pipeline.

Acceptance: extract `<cluster>-kubeconfig` Secret from a real k0smotron apply, document the user/context names, update the yq pipeline (or make it shape-tolerant via `select(.name | test("admin"))`).

## F8: No committed fixture params.yaml for verification

**Scope:** repo-wide

Plan U1-U6 verification scenarios require fixture params.yaml files and expected TFVARS output. None are committed; `make tfvars` cannot be re-run by a contributor or CI without constructing fixtures from scratch.

Acceptance: `tests/fixtures/` with three params.yaml files (vm-default, k0smotron-full, vm-with-k0smotron-leftover), expected TFVARS snapshots, and a `make test-fixtures` target.

## F10: kubectl wait observability and triggers refresh

**File:** `src/terraform/k0smotron.tf` (null_resource.wait_control_plane)

The 15-minute kubectl wait produces no heartbeat. On taint-and-retry the entire wait re-runs even when the controlplane is already Ready. Triggers map only contains `cluster_name`.

Acceptance:
- Replace `kubectl wait` with a polling loop emitting a timestamped line every 30 seconds
- Add K0smotronControlPlane resource version or generation to `triggers` so updates re-run the wait deterministically

## F11: Tailscale OAuth credentials visible in K0smotronControlPlane CR spec

**File:** `src/terraform/templates/k0smotron-controlplane.yaml.tftpl` (helm chart values block for tailscale-operator)

OAuth `clientId` and `clientSecret` are rendered inline into the K0smotronControlPlane CR on the mgmt cluster, where anyone with `get k0smotroncontrolplane` permission in the namespace can read them. Confirmed via k0s docs that the helm extension supports only inline `values:` strings — `configFrom.secretRef` covers chart repository credentials, not chart values, so an in-place Secret-mount refactor is not possible against the current k0s release.

Acceptance: design a follow-up that either (a) waits for upstream k0s to add `valuesFrom` support to the helm extension, (b) switches Tailscale operator config delivery to a workload-cluster Secret applied after kubeconfig fetch, or (c) accepts the current visibility and documents the mgmt-cluster namespace RBAC requirement in the README's k0smotron prerequisites section.

## Resolved items

- **F3 (cloudflare-api-token race vs cert-manager namespace)** — resolved by promoting the Cloudflare API token to `acme.cloudflare.api_key` in params.yaml. The token now ships as a `local_sensitive_file` in vm mode and as a mgmt-cluster `kubernetes_secret` referenced from `K0smotronControlPlane.spec.manifests` in k0smotron mode. The Makefile no longer runs `sops --decrypt | kubectl apply -n cert-manager`, so the cert-manager-namespace-not-yet-created race condition cannot occur.
