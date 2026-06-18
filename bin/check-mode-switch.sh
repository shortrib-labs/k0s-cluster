#!/usr/bin/env bash
# check-mode-switch.sh — guard against accidental cluster mode flips.
#
# When the operator changes `cluster.mode` in params.yaml between `vm` and
# `k0smotron`, a plain `terraform apply` would silently destroy the previous
# mode's resources (VM control plane or k0smotron CRs). This script aborts
# unless CONFIRM_MODE_SWITCH=1 is set.
#
# Usage:
#   check-mode-switch.sh <cluster_mode> <terraform_dir>
#
# Behavior:
#   - If <terraform_dir>/.terraform/ does not exist, the workspace has never
#     been initialized and there is no prior state to switch from — skip.
#   - Otherwise run `terraform state list` (no stderr suppression — real errors
#     should surface). Count resources tied to each mode and compare against
#     the requested mode.

set -euo pipefail

cluster_mode="${1:?cluster_mode required as first argument}"
tf_dir="${2:?terraform directory required as second argument}"

if [ ! -d "${tf_dir}/.terraform" ]; then
  echo "[check-mode-switch] state uninitialized; skipping"
  exit 0
fi

# Try to read state. The "no state file was found" exit is a first-apply
# situation, not an error — there are no resources to switch from. Distinguish
# that case from real failures (corrupt state, locked backend, etc.).
if state=$(cd "${tf_dir}" && terraform state list 2>&1); then
  : # state populated; fall through to the count check
elif echo "$state" | grep -qE "No state file was found|state file does not exist|Backend reinitialization required"; then
  echo "[check-mode-switch] no state yet; skipping"
  exit 0
else
  echo "ERROR: terraform state list failed in ${tf_dir}" >&2
  echo "$state" >&2
  exit 1
fi

# `grep -c` on no match exits non-zero, but the state was already proven
# readable above, so `|| true` here only swallows the empty-match case.
has_vm_cp=$(echo "${state}" | grep -c 'nutanix_virtual_machine.control_plane' || true)
has_k0s=$(echo "${state}" | grep -c 'kubernetes_manifest.k0smotron_controlplane' || true)

if [ "${has_vm_cp}" -gt 0 ] && [ "${cluster_mode}" = "k0smotron" ]; then
  if [ "${CONFIRM_MODE_SWITCH:-}" != "1" ]; then
    echo "ERROR: state has VM control-plane resources but cluster.mode is k0smotron." >&2
    echo "       This will DESTROY your VM control plane. Set CONFIRM_MODE_SWITCH=1 to proceed." >&2
    exit 1
  fi
fi

if [ "${has_k0s}" -gt 0 ] && [ "${cluster_mode}" = "vm" ]; then
  if [ "${CONFIRM_MODE_SWITCH:-}" != "1" ]; then
    echo "ERROR: state has k0smotron CRs but cluster.mode is vm." >&2
    echo "       This will DESTROY your k0smotron control plane. Set CONFIRM_MODE_SWITCH=1 to proceed." >&2
    exit 1
  fi
fi
