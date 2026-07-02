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
