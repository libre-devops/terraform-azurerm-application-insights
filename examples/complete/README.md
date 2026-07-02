<!--
  Header for the complete example README. Edit this file, then run `just docs`
  (or ./Sort-LdoTerraform.ps1 -IncludeExamples) to regenerate the section between the markers.
  The example's main.tf is embedded into the README automatically (see .terraform-docs.yml).
-->
<div align="center">
  <a href="https://libredevops.org">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://libredevops.org/assets/libre-devops-white.png">
      <img alt="Libre DevOps" src="https://libredevops.org/assets/libre-devops-black.png" width="200">
    </picture>
  </a>
</div>

# Complete example

The full surface of the module: an RBAC-posture component with every tuning knob (retention, daily
cap and notifications, sampling, IP masking, internet toggles, profiler storage), the Monitoring
Metrics Publisher grant wired to a workload identity created in the same plan (proving the
plan-known grant keys), API keys (read and write scoped), analytics items (a saved query and a
function with an alias), smart detection rule tuning, and a second component deliberately opted into
legacy instrumentation-key ingestion so the posture check is visible in the plan output. Run it with
`just e2e complete`, which applies the stack then always destroys it.

[![Terraform Registry](https://img.shields.io/badge/registry-libre--devops-7B42BC?logo=terraform&logoColor=white)](https://registry.terraform.io/namespaces/libre-devops)

<!-- BEGIN_TF_DOCS -->
## Example configuration

```hcl
locals {
  location = lookup(var.regions, var.loc, "uksouth")
  rg_name  = "rg-${var.short}-${var.loc}-${terraform.workspace}-002"
  law_name = "log-${var.short}-${var.loc}-${terraform.workspace}-002"
  uai_name = "id-${var.short}-${var.loc}-${terraform.workspace}-002"
}

module "tags" {
  source  = "libre-devops/tags/azurerm"
  version = "~> 4.0"

  cost_centre     = "1888/67"
  owner           = "platform@example.com"
  deployed_branch = var.deployed_branch
  deployed_repo   = var.deployed_repo
  additional_tags = { Application = "terraform-azurerm-application-insights" }
}

module "rg" {
  source  = "libre-devops/rg/azurerm"
  version = "~> 4.0"

  resource_groups = [{ name = local.rg_name, location = local.location, tags = module.tags.tags }]
}

# The workspace the components are based on (embedding into Log Analytics).
module "log_analytics" {
  source  = "libre-devops/log-analytics-workspace/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  log_analytics_workspaces = { (local.law_name) = {} }
}

# A workload identity whose principal id is only known after apply: it receives the Monitoring
# Metrics Publisher grant, proving the module's plan-known grant keys, and is what an app would run
# as to ingest telemetry with Entra ID auth.
module "user_assigned_managed_identity" {
  source  = "libre-devops/user-assigned-managed-identity/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  user_assigned_identities = {
    (local.uai_name) = {}
  }
}

# Complete call: the full surface. An RBAC-posture component with the publisher grant and every
# tuning knob, the conditional sub-resources (api keys, analytics items, smart detection rules), and
# a second component opted into legacy instrumentation-key ingestion (which the posture check makes
# visible in the plan output).
module "application_insights" {
  source = "../../"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  workspace_id = module.log_analytics.workspace_ids[local.law_name]

  application_insights = {
    "appi-${var.short}-${var.loc}-${terraform.workspace}-002" = {
      application_type                     = "web"
      retention_in_days                    = 30
      daily_data_cap_in_gb                 = 1
      daily_data_cap_notifications_enabled = true
      sampling_percentage                  = 100
      ip_masking_enabled                   = true
      internet_query_enabled               = true
      force_customer_storage_for_profiler  = false
      tags                                 = { Component = "app" }

      # RBAC ingestion: the workload identity gets Monitoring Metrics Publisher on the component.
      monitoring_publishers = [module.user_assigned_managed_identity.principal_ids[local.uai_name]]

      api_keys = {
        reader = { read_permissions = ["api", "search", "aggregate"] }
        writer = { write_permissions = ["annotations"] }
      }

      analytics_items = {
        slow-requests = {
          content = "requests | where duration > 5000 | summarize count() by name"
        }
        recent-exceptions = {
          type           = "function"
          function_alias = "recentexceptions"
          content        = "exceptions | order by timestamp desc | take 100"
        }
      }

      smart_detection_rules = {
        "Slow server response time" = {
          send_emails_to_subscription_owners = false
          additional_email_recipients        = ["platform@example.com"]
        }
        "Abnormal rise in exception volume" = {
          enabled = false
        }
      }
    }

    # Legacy posture, deliberately: instrumentation-key ingestion stays on, and the plan-time check
    # calls it out so the opt-in is visible.
    "appi-${var.short}-legacy-${var.loc}-${terraform.workspace}-002" = {
      local_authentication_enabled = true
      tags                         = { Component = "legacy" }
    }
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0, < 2.0.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.0.0, < 5.0.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_application_insights"></a> [application\_insights](#module\_application\_insights) | ../../ | n/a |
| <a name="module_log_analytics"></a> [log\_analytics](#module\_log\_analytics) | libre-devops/log-analytics-workspace/azurerm | ~> 4.0 |
| <a name="module_rg"></a> [rg](#module\_rg) | libre-devops/rg/azurerm | ~> 4.0 |
| <a name="module_tags"></a> [tags](#module\_tags) | libre-devops/tags/azurerm | ~> 4.0 |
| <a name="module_user_assigned_managed_identity"></a> [user\_assigned\_managed\_identity](#module\_user\_assigned\_managed\_identity) | libre-devops/user-assigned-managed-identity/azurerm | ~> 4.0 |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_deployed_branch"></a> [deployed\_branch](#input\_deployed\_branch) | Git branch the deployment came from. Auto-filled in CI from TF\_VAR\_deployed\_branch. | `string` | `""` | no |
| <a name="input_deployed_repo"></a> [deployed\_repo](#input\_deployed\_repo) | Repository URL the deployment came from. Auto-filled in CI from TF\_VAR\_deployed\_repo. | `string` | `""` | no |
| <a name="input_loc"></a> [loc](#input\_loc) | Outfix: short Azure region code used in resource names (for example uks). | `string` | `"uks"` | no |
| <a name="input_regions"></a> [regions](#input\_regions) | Map of short region codes to Azure region slugs. | `map(string)` | <pre>{<br/>  "eus": "eastus",<br/>  "euw": "westeurope",<br/>  "uks": "uksouth",<br/>  "ukw": "ukwest"<br/>}</pre> | no |
| <a name="input_short"></a> [short](#input\_short) | Infix: short product code used in resource names. | `string` | `"ldo"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_analytics_items"></a> [analytics\_items](#output\_analytics\_items) | The analytics items with their ids and versions. |
| <a name="output_api_key_ids"></a> [api\_key\_ids](#output\_api\_key\_ids) | Map of component\|name to API key resource id. |
| <a name="output_app_ids"></a> [app\_ids](#output\_app\_ids) | Map of component name to App Insights application id. |
| <a name="output_connection_strings"></a> [connection\_strings](#output\_connection\_strings) | Map of component name to connection string (what apps embed). |
| <a name="output_ids"></a> [ids](#output\_ids) | Map of component name to resource id. |
| <a name="output_ids_zipmap"></a> [ids\_zipmap](#output\_ids\_zipmap) | Map of component name to { name, id }. |
| <a name="output_monitoring_publisher_role_assignment_ids"></a> [monitoring\_publisher\_role\_assignment\_ids](#output\_monitoring\_publisher\_role\_assignment\_ids) | The Monitoring Metrics Publisher grants. |
| <a name="output_smart_detection_rule_ids"></a> [smart\_detection\_rule\_ids](#output\_smart\_detection\_rule\_ids) | Map of component\|rule to smart detection rule id. |
| <a name="output_workspace_ids"></a> [workspace\_ids](#output\_workspace\_ids) | Map of component name to the backing Log Analytics workspace. |
<!-- END_TF_DOCS -->
