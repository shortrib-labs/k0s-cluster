---
title: Makefile yq with string defaults requires double-quoted expressions
date: 2026-06-03
category: conventions
module: build-system
problem_type: convention
component: tooling
severity: medium
applies_when:
  - "Using yq inside a Makefile $(shell ...) expansion with a string default like // \"value\""
  - "Defining Makefile macros via define...endef that call yq for TFVARS or similar generated files"
  - "Adding the first string-default yq line next to existing boolean-default lines (// false, // true)"
symptoms:
  - "Generated output silently contains an empty string instead of the default value"
  - "yq stderr (when not suppressed) shows: lexer: invalid input text \"\\\\\\\"value\\\\\\\"\""
root_cause: wrong_api
resolution_type: code_fix
tags:
  - makefile
  - yq
  - shell-escaping
  - tfvars
  - sh-quoting
  - string-default
---

# Makefile yq with string defaults requires double-quoted expressions

## Context

This repo's `Makefile` renders `secrets/terrform.tfvars` from a SOPS-encrypted `params.yaml` via a `define TFVARS ... endef` macro. Each Terraform variable line is built by `$(shell yq ... $(params_yaml))`. Boolean defaults like `// false` were already in place when this convention started:

```makefile
enable_gvisor = "$(shell yq '.cluster.runtimes.gvisor.enabled // false' $(params_yaml))"
```

When the `cluster.mode` and `cluster.k0smotron.*` schema additions landed, the natural-looking string-default extension of that pattern silently broke. The failure is invisible during development because the `@`-prefixed recipe suppresses stderr — the empty output only surfaces when an end-to-end run against a populated fixture produces the wrong tfvars.

## Guidance

When the yq default is a **string literal** (not a bareword like `false` / `true` / a number), wrap the yq expression in **double quotes**, not single quotes, and escape the inner double quotes with `\"`.

**Wrong — single-quoted yq with backslash-escaped inner quotes:**
```makefile
cluster_mode = "$(shell yq '.cluster.mode // \"vm\"' $(params_yaml))"
```

**Correct — double-quoted yq with backslash-escaped inner quotes:**
```makefile
cluster_mode = "$(shell yq ".cluster.mode // \"vm\"" $(params_yaml))"
```

Boolean defaults stay single-quoted because no inner quoting is needed at the yq level:
```makefile
enable_gvisor = "$(shell yq '.cluster.runtimes.gvisor.enabled // false' $(params_yaml))"
```

## Why This Matters

Inside a **single**-quoted shell string, `sh` preserves backslashes literally — `\"` reaches the subprocess as `\"`. `yq` then sees `.cluster.mode // \"vm\"` and rejects it:
```
Error: 1:18: lexer: invalid input text "\\\"vm\\\""
```
`$(shell ...)` captures stdout only, so the empty stdout becomes the variable's value. The generated tfvars contains:
```
cluster_mode = ""
```
…which Terraform happily accepts as an empty-string assignment, silently overriding the variable's declared default.

Inside a **double**-quoted shell string, `\"` *is* unescaped by `sh` to `"`. `yq` receives the syntactically valid expression `.cluster.mode // "vm"` and returns the default when the YAML key is missing.

The boolean pattern (`// false`) lures the next contributor into the wrong convention: it works with single quotes only because `false` is a bareword needing no inner quoting. The break shows up the first time someone copies the boolean shape and adds a string default.

## When to Apply

Apply the double-quoted form whenever:

- The yq `//` default operator's right-hand side is a string literal (e.g., `// "vm"`, `// "clusters"`, `// ""`)
- The yq call lives inside a `define ... endef` Makefile macro whose stderr is suppressed at recipe time
- You are extending the TFVARS macro with a new variable next to existing boolean lines

This rule does **not** apply (single-quoted form is fine) when:

- The default is a bareword: `// false`, `// true`, `// 0`, `// 8080`
- No default is needed (the YAML key is guaranteed present)
- The yq call lives in a recipe line outside `define ... endef` where you can inspect stderr directly

## Examples

### Before — five broken TFVARS lines added in U1

```makefile
define TFVARS
...
cluster_mode                  = "$(shell yq '.cluster.mode // \"vm\"' $(params_yaml))"
cluster_k0smotron_kubeconfig  = "$(shell yq '.cluster.k0smotron.management_kubeconfig // \"\"' $(params_yaml))"
cluster_k0smotron_namespace   = "$(shell yq '.cluster.k0smotron.namespace // \"clusters\"' $(params_yaml))"
cluster_k0smotron_external_ip = "$(shell yq '.cluster.k0smotron.external_ip // \"\"' $(params_yaml))"
cluster_k0smotron_k0s_version = "$(shell yq '.cluster.k0smotron.k0s_version // \"v1.35.2+k0s.0\"' $(params_yaml))"
...
endef
```

Running `make tfvars` against a fixture `params.yaml` with `cluster.mode: k0smotron` and a populated `cluster.k0smotron:` block produced:
```
cluster_mode = ""
cluster_k0smotron_kubeconfig = ""
cluster_k0smotron_namespace = ""
cluster_k0smotron_external_ip = ""
cluster_k0smotron_k0s_version = ""
```

### After — all five lines corrected

```makefile
cluster_mode                  = "$(shell yq ".cluster.mode // \"vm\"" $(params_yaml))"
cluster_k0smotron_kubeconfig  = "$(shell yq ".cluster.k0smotron.management_kubeconfig // \"\"" $(params_yaml))"
cluster_k0smotron_namespace   = "$(shell yq ".cluster.k0smotron.namespace // \"clusters\"" $(params_yaml))"
cluster_k0smotron_external_ip = "$(shell yq ".cluster.k0smotron.external_ip // \"\"" $(params_yaml))"
cluster_k0smotron_k0s_version = "$(shell yq ".cluster.k0smotron.k0s_version // \"v1.35.2+k0s.0\"" $(params_yaml))"
```

Re-running `make tfvars` against the same fixture:
```
cluster_mode = "k0smotron"
cluster_k0smotron_kubeconfig = "/home/u/mgmt-kc"
cluster_k0smotron_namespace = "tenants"
cluster_k0smotron_external_ip = "10.26.0.100"
cluster_k0smotron_k0s_version = "v1.35.5+k0s.0"
```

### Reproducing the bug outside Make

A two-line test isolates the difference:

```bash
$ cat > /tmp/test-makefile <<'EOF'
test:
	@echo "single+backslash: '$(shell yq '.x // \"vm\"' /tmp/empty.yaml)'"
	@echo "double+backslash: '$(shell yq ".x // \"vm\"" /tmp/empty.yaml)'"
EOF
$ echo '{}' > /tmp/empty.yaml
$ make -f /tmp/test-makefile test
Error: 1:7: lexer: invalid input text "\\\"vm\\\""
single+backslash: ''
double+backslash: 'vm'
```

The lexer error confirms `yq` is receiving literal backslashes from the single-quoted form.

## Related

- `Makefile` — current state shows the corrected pattern at the top-level `cluster_mode :=` extraction (lines 16–17) and inside the `TFVARS` macro (lines 42–46).
- `docs/plans/2026-05-26-001-feat-k0smotron-cluster-mode-plan.md` lines 321–325 — the k0smotron implementation plan reproduces the original broken form in its U1 spec. The plan is a frozen decision artifact; the executable convention lives here.
