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

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0, < 2.0.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.0.0, < 5.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | >= 4.0.0, < 5.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_application_insights.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_insights) | resource |
| [azurerm_application_insights_analytics_item.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_insights_analytics_item) | resource |
| [azurerm_application_insights_api_key.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_insights_api_key) | resource |
| [azurerm_application_insights_smart_detection_rule.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_insights_smart_detection_rule) | resource |
| [azurerm_role_assignment.monitoring_publisher](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_application_insights"></a> [application\_insights](#input\_application\_insights) | The Application Insights components to create, keyed by component name. Every component is<br/>workspace-based (set the module-level workspace\_id or a per-component override; classic components<br/>are retired).<br/><br/>AUTH POSTURE (RBAC vs instrumentation key): local\_authentication\_enabled defaults to FALSE, meaning<br/>ingestion requires Entra ID (RBAC) auth and a bare instrumentation key or connection string is not<br/>enough to send telemetry. Grant senders the Monitoring Metrics Publisher role on the component by<br/>listing their principal ids in monitoring\_publishers (the module creates the role assignments), or<br/>grant it elsewhere. Set local\_authentication\_enabled = true for classic instrumentation-key<br/>ingestion; a plan-time check makes that opt-in visible.<br/><br/>Per-component attributes: application\_type (default web); workspace\_id; retention\_in\_days (default<br/>90); daily\_data\_cap\_in\_gb and daily\_data\_cap\_notifications\_enabled; sampling\_percentage;<br/>ip\_masking\_enabled; internet\_ingestion\_enabled / internet\_query\_enabled;<br/>force\_customer\_storage\_for\_profiler; tags; monitoring\_publishers (list of principal object ids<br/>granted Monitoring Metrics Publisher on the component).<br/><br/>Conditional sub-resources, all keyed by name within the component:<br/><br/>- api\_keys: read\_permissions (agentconfig, aggregate, api, draft, extendqueries, search) and<br/>  write\_permissions (annotations). The generated api\_key secret is only available at creation and is<br/>  exported in the sensitive api\_keys output.<br/>- analytics\_items: saved Log Analytics artefacts. type (query, function, folder, recent; default<br/>  query), scope (shared or user; default shared; functions must be shared), content, function\_alias<br/>  (required for functions).<br/>- smart\_detection\_rules: keyed by the built-in rule name (Slow page load time, Slow server response<br/>  time, Long dependency duration, Degradation in server response time, Degradation in dependency<br/>  duration, Degradation in trace severity ratio, Abnormal rise in exception volume, Abnormal rise in<br/>  daily data volume, Potential memory leak detected, Potential security issue detected). enabled<br/>  (default true), send\_emails\_to\_subscription\_owners (default true), additional\_email\_recipients. | <pre>map(object({<br/>    application_type                     = optional(string, "web")<br/>    workspace_id                         = optional(string)<br/>    retention_in_days                    = optional(number, 90)<br/>    daily_data_cap_in_gb                 = optional(number)<br/>    daily_data_cap_notifications_enabled = optional(bool)<br/>    sampling_percentage                  = optional(number)<br/>    ip_masking_enabled                   = optional(bool)<br/>    local_authentication_enabled         = optional(bool, false)<br/>    internet_ingestion_enabled           = optional(bool, true)<br/>    internet_query_enabled               = optional(bool, true)<br/>    force_customer_storage_for_profiler  = optional(bool, false)<br/>    tags                                 = optional(map(string))<br/><br/>    monitoring_publishers = optional(list(string), [])<br/><br/>    api_keys = optional(map(object({<br/>      read_permissions  = optional(list(string), [])<br/>      write_permissions = optional(list(string), [])<br/>    })), {})<br/><br/>    analytics_items = optional(map(object({<br/>      content        = string<br/>      type           = optional(string, "query")<br/>      scope          = optional(string, "shared")<br/>      function_alias = optional(string)<br/>    })), {})<br/><br/>    smart_detection_rules = optional(map(object({<br/>      enabled                            = optional(bool, true)<br/>      send_emails_to_subscription_owners = optional(bool)<br/>      additional_email_recipients        = optional(list(string))<br/>    })), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region for the components. | `string` | n/a | yes |
| <a name="input_resource_group_id"></a> [resource\_group\_id](#input\_resource\_group\_id) | Resource id of the resource group to create the components in. The name is parsed from it (pass the rg module's ids output). | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every component (merged with any per-component tags). | `map(string)` | `{}` | no |
| <a name="input_workspace_id"></a> [workspace\_id](#input\_workspace\_id) | Default Log Analytics workspace the components are based on (classic Application Insights is retired, so every component must be workspace-based). Overridable per component with its own workspace\_id. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_analytics_items"></a> [analytics\_items](#output\_analytics\_items) | The analytics items, keyed "component\|name". Full resource objects. |
| <a name="output_api_key_ids"></a> [api\_key\_ids](#output\_api\_key\_ids) | Map of "component\|name" to API key resource id (non-sensitive). |
| <a name="output_api_keys"></a> [api\_keys](#output\_api\_keys) | The API keys, keyed "component\|name". Full resource objects; sensitive because the generated api\_key secret (only available at creation) is inside. |
| <a name="output_app_ids"></a> [app\_ids](#output\_app\_ids) | Map of component name to the App Insights application id (used by the query APIs; not the resource id). |
| <a name="output_application_insights"></a> [application\_insights](#output\_application\_insights) | The components, keyed by name: every attribute except the deprecated trio (whose \_enabled twins carry the same information; a full-object output would trip their deprecation warnings). Sensitive because connection\_string and instrumentation\_key are inside. |
| <a name="output_connection_strings"></a> [connection\_strings](#output\_connection\_strings) | Map of component name to connection string: what modern SDKs and app settings (APPLICATIONINSIGHTS\_CONNECTION\_STRING) embed. |
| <a name="output_ids"></a> [ids](#output\_ids) | Map of component name to resource id. |
| <a name="output_ids_zipmap"></a> [ids\_zipmap](#output\_ids\_zipmap) | Map of component name to { name, id }, for easy composition with other modules. |
| <a name="output_instrumentation_keys"></a> [instrumentation\_keys](#output\_instrumentation\_keys) | Map of component name to instrumentation key (legacy embedding; prefer connection\_strings, and note the key alone cannot ingest when local auth is disabled). |
| <a name="output_monitoring_publisher_role_assignment_ids"></a> [monitoring\_publisher\_role\_assignment\_ids](#output\_monitoring\_publisher\_role\_assignment\_ids) | Map of "component\|pN" to the Monitoring Metrics Publisher role assignment id. |
| <a name="output_names"></a> [names](#output\_names) | Map of component name to name (convenience passthrough). |
| <a name="output_resource_group_name"></a> [resource\_group\_name](#output\_resource\_group\_name) | The resource group the components live in, parsed from resource\_group\_id. |
| <a name="output_smart_detection_rule_ids"></a> [smart\_detection\_rule\_ids](#output\_smart\_detection\_rule\_ids) | Map of "component\|rule name" to smart detection rule id. |
| <a name="output_workspace_ids"></a> [workspace\_ids](#output\_workspace\_ids) | Map of component name to the Log Analytics workspace backing it. |
<!-- END_TF_DOCS -->
