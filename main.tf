locals {
  rg      = provider::azurerm::parse_resource_id(var.resource_group_id)
  rg_name = local.rg.resource_group_name

  # Flattened sub-resource instances, keyed "component|name". Keys derive from input map keys only,
  # so they stay known at plan time; principals for the RBAC grants are keyed by INDEX because a
  # principal id is routinely computed (an identity created in the same plan).
  api_keys = {
    for item in flatten([
      for comp, c in var.application_insights : [
        for name, k in c.api_keys : {
          key              = "${comp}|${name}", component = comp, name = name
          read_permissions = k.read_permissions, write_permissions = k.write_permissions
        }
      ]
    ]) : item.key => item
  }

  analytics_items = {
    for item in flatten([
      for comp, c in var.application_insights : [
        for name, i in c.analytics_items : {
          key     = "${comp}|${name}", component = comp, name = name
          content = i.content, type = i.type, scope = i.scope, function_alias = i.function_alias
        }
      ]
    ]) : item.key => item
  }

  smart_detection_rules = {
    for item in flatten([
      for comp, c in var.application_insights : [
        for name, r in c.smart_detection_rules : {
          key                                = "${comp}|${name}", component = comp, name = name
          enabled                            = r.enabled
          send_emails_to_subscription_owners = r.send_emails_to_subscription_owners
          additional_email_recipients        = r.additional_email_recipients
        }
      ]
    ]) : item.key => item
  }

  monitoring_publishers = {
    for item in flatten([
      for comp, c in var.application_insights : [
        for idx, principal in c.monitoring_publishers : {
          key = "${comp}|p${idx}", component = comp, principal_id = principal
        }
      ]
    ]) : item.key => item
  }
}

# Workspace-based Application Insights (classic is retired, so a workspace is required: the module
# default or a per-component override). local_authentication_enabled defaults to false, the RBAC-first
# posture: telemetry senders authenticate with Entra ID and need Monitoring Metrics Publisher on the
# component (see azurerm_role_assignment.monitoring_publisher below).
resource "azurerm_application_insights" "this" {
  for_each = var.application_insights

  resource_group_name = local.rg_name
  location            = var.location
  tags                = merge(var.tags, coalesce(each.value.tags, {}))
  name                = each.key

  application_type = each.value.application_type
  workspace_id     = coalesce(each.value.workspace_id, var.workspace_id)

  retention_in_days                    = each.value.retention_in_days
  daily_data_cap_in_gb                 = each.value.daily_data_cap_in_gb
  daily_data_cap_notifications_enabled = each.value.daily_data_cap_notifications_enabled
  sampling_percentage                  = each.value.sampling_percentage
  ip_masking_enabled                   = each.value.ip_masking_enabled

  local_authentication_enabled        = each.value.local_authentication_enabled
  internet_ingestion_enabled          = each.value.internet_ingestion_enabled
  internet_query_enabled              = each.value.internet_query_enabled
  force_customer_storage_for_profiler = each.value.force_customer_storage_for_profiler

  lifecycle {
    precondition {
      condition     = each.value.workspace_id != null || var.workspace_id != null
      error_message = "Component \"${each.key}\" has no Log Analytics workspace: set the module-level workspace_id or a per-component workspace_id (classic Application Insights is retired)."
    }
  }
}

# The RBAC half of the auth story: Monitoring Metrics Publisher on the component lets the listed
# principals ingest telemetry with Entra ID auth (the GUID is the built-in role's id, verified
# against the platform).
resource "azurerm_role_assignment" "monitoring_publisher" {
  for_each = local.monitoring_publishers

  scope              = azurerm_application_insights.this[each.value.component].id
  role_definition_id = "/providers/Microsoft.Authorization/roleDefinitions/3913510d-42f4-4e42-8a64-420c390055eb"
  principal_id       = each.value.principal_id

  skip_service_principal_aad_check = true
  description                      = "Monitoring Metrics Publisher: Entra ID (RBAC) telemetry ingestion for this Application Insights component."
}

# API keys for the classic REST surfaces. The generated secret is only available at creation and is
# exported via the sensitive api_keys output.
resource "azurerm_application_insights_api_key" "this" {
  for_each = local.api_keys

  name                    = each.value.name
  application_insights_id = azurerm_application_insights.this[each.value.component].id

  read_permissions  = each.value.read_permissions
  write_permissions = each.value.write_permissions
}

# Saved analytics artefacts (queries, functions, folders).
resource "azurerm_application_insights_analytics_item" "this" {
  for_each = local.analytics_items

  name                    = each.value.name
  application_insights_id = azurerm_application_insights.this[each.value.component].id

  type           = each.value.type
  scope          = each.value.scope
  content        = each.value.content
  function_alias = each.value.function_alias
}

# Smart detection rule tuning (the rules themselves are built in; entries configure or disable them).
resource "azurerm_application_insights_smart_detection_rule" "this" {
  for_each = local.smart_detection_rules

  name                    = each.value.name
  application_insights_id = azurerm_application_insights.this[each.value.component].id

  enabled                            = each.value.enabled
  send_emails_to_subscription_owners = each.value.send_emails_to_subscription_owners
  additional_email_recipients        = each.value.additional_email_recipients
}
