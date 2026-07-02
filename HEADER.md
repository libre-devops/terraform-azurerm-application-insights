<!--
  Keep the title and badges OUTSIDE the centered <div>: the Terraform Registry's markdown renderer
  does not parse markdown inside an HTML block, so a # heading or [![badge]] in the div renders as
  literal text on the registry. Only the logo (HTML) goes in the div.
-->
<div align="center">
  <a href="https://libredevops.org">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://libredevops.org/assets/libre-devops-white.png">
      <img alt="Libre DevOps" src="https://libredevops.org/assets/libre-devops-black.png" width="300">
    </picture>
  </a>
</div>

# Terraform Azure Application Insights

Workspace-based Application Insights with an RBAC-first ingestion posture, publisher grants handled
for you, and the conditional sub-resources (API keys, analytics items, smart detection rules) in the
same map.

[![CI](https://github.com/libre-devops/terraform-azurerm-application-insights/actions/workflows/ci.yml/badge.svg)](https://github.com/libre-devops/terraform-azurerm-application-insights/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/libre-devops/terraform-azurerm-application-insights?sort=semver&label=release)](https://github.com/libre-devops/terraform-azurerm-application-insights/releases/latest)
[![Terraform Registry](https://img.shields.io/badge/registry-libre--devops-7B42BC?logo=terraform&logoColor=white)](https://registry.terraform.io/namespaces/libre-devops)
[![License](https://img.shields.io/github/license/libre-devops/terraform-azurerm-application-insights)](./LICENSE)

---

## Overview

Components keyed by name, always **workspace-based** (classic Application Insights is retired; pass a
module-level Log Analytics `workspace_id` or per-component overrides, pairing naturally with the
`log-analytics-workspace` module).

**RBAC vs instrumentation key, handled**: `local_authentication_enabled` defaults to **false**, so a
leaked connection string or instrumentation key cannot ingest telemetry on its own; senders
authenticate with Entra ID and need the Monitoring Metrics Publisher role on the component. List
their principal ids in `monitoring_publishers` and the module creates those grants (the role GUID is
verified against the platform; grant keys are index-based so identities created in the same plan just
work). Opting back into instrumentation-key ingestion is one attribute, and a plan-time check makes
the opt-in visible rather than silent.

**Conditional sub-resources** per component, each an optional map:

- `api_keys` - read/write scoped keys for the classic REST surfaces; the generated secret (only
  available at creation) is exported in the sensitive `api_keys` output.
- `analytics_items` - saved queries, functions (with aliases), and folders.
- `smart_detection_rules` - tune or disable the built-in rules, keyed by their exact rule names
  (validated against the documented list).

**Easy embedding**: `connection_strings` (what modern SDKs and `APPLICATIONINSIGHTS_CONNECTION_STRING`
app settings consume), `instrumentation_keys`, `app_ids`, `ids`, zipmap, and the full component
objects are all exported (sensitive where they carry secrets), so wiring App Insights into web apps,
function apps, or anything else is one lookup.

## Usage

```hcl
module "application_insights" {
  source  = "libre-devops/application-insights/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids["rg-ldo-uks-prd-001"]
  location          = "uksouth"
  tags              = module.tags.tags

  workspace_id = module.log_analytics.workspace_ids["log-ldo-uks-prd-001"]

  application_insights = {
    "appi-ldo-uks-prd-001" = {
      # RBAC ingestion (the secure default): grant the app's identity the publisher role.
      monitoring_publishers = [module.identity.principal_ids["id-ldo-uks-prd-001"]]

      smart_detection_rules = {
        "Slow server response time" = { additional_email_recipients = ["platform@example.com"] }
      }
    }
  }
}

# Embedding into an app:
#   APPLICATIONINSIGHTS_CONNECTION_STRING = module.application_insights.connection_strings["appi-ldo-uks-prd-001"]
```

## Examples

- [`examples/minimal`](./examples/minimal) - one component with the secure defaults, embedded into a
  Log Analytics workspace.
- [`examples/complete`](./examples/complete) - the full surface: every tuning knob, the publisher
  grant wired to a workload identity created in the same plan, API keys, analytics items (query and
  function), smart detection rule tuning, and a second component deliberately opted into legacy
  instrumentation-key ingestion so the posture check is visible.

## Developing

Local work needs **PowerShell 7+** and **[`just`](https://github.com/casey/just)**, because the recipes
wrap the [LibreDevOpsHelpers](https://www.powershellgallery.com/packages/LibreDevOpsHelpers)
PowerShell module (the same engine the `libre-devops/terraform-azure` action runs in CI). Install
just with `brew install just`, or `uv tool add rust-just` then `uv run just <recipe>`.

Run `just` to list recipes: `just update-ldo-pwsh` (install or force-update LibreDevOpsHelpers from
PSGallery), `just validate`, `just scan` (Trivy only), `just pwsh-analyze` (PSScriptAnalyzer only),
`just plan`, `just apply`, `just destroy`, `just e2e`, `just test`, and `just docs` (the
plan/apply/destroy recipes mirror the action, including the storage firewall dance; `just e2e`
applies an example then always destroys it, defaulting to `minimal`, so nothing is left running).
Releasing is also `just`:
`just increment-release [patch|minor|major]` bumps, tags, and publishes a GitHub release, and the
Terraform Registry picks up the tag.

## Security scan exceptions

This module is scanned with [Trivy](https://github.com/aquasecurity/trivy); HIGH and CRITICAL
findings fail the build. Any waiver is a deliberate, reviewed decision, never a way to quiet a
finding that should be fixed. Waivers live in [`.trivyignore.yaml`](./.trivyignore.yaml) (the
machine-applied source of truth, passed to Trivy with `--ignorefile`) and are mirrored in a table
here so the reason is auditable.

There are currently **no exceptions**: the module and its examples scan clean. The module's default
posture (RBAC-only ingestion) exists to REMOVE the standing-credential risk, so there is nothing to
waive.

To add an exception: add an entry to `.trivyignore.yaml` (`id`, optional `paths` to scope it, and a
`statement` recording why), then add a matching row here recording the reason. Both the file and
the table are reviewed in the pull request.

## Reference

The Requirements, Providers, Inputs, Outputs, and Resources below are generated by `terraform-docs`.
