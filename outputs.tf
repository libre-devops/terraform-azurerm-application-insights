# ALL attributes are exported: the full component objects (sensitive, because they carry the
# connection string and instrumentation key) plus non-sensitive curated maps for everything a caller
# usually embeds, so composition rarely needs the sensitive output at all.

output "application_insights" {
  description = "The components, keyed by name: every attribute except the deprecated trio (whose _enabled twins carry the same information; a full-object output would trip their deprecation warnings). Sensitive because connection_string and instrumentation_key are inside."
  value = {
    for k, c in azurerm_application_insights.this : k => {
      id                                   = c.id
      name                                 = c.name
      resource_group_name                  = c.resource_group_name
      location                             = c.location
      tags                                 = c.tags
      application_type                     = c.application_type
      workspace_id                         = c.workspace_id
      app_id                               = c.app_id
      connection_string                    = c.connection_string
      instrumentation_key                  = c.instrumentation_key
      retention_in_days                    = c.retention_in_days
      daily_data_cap_in_gb                 = c.daily_data_cap_in_gb
      daily_data_cap_notifications_enabled = c.daily_data_cap_notifications_enabled
      sampling_percentage                  = c.sampling_percentage
      ip_masking_enabled                   = c.ip_masking_enabled
      local_authentication_enabled         = c.local_authentication_enabled
      internet_ingestion_enabled           = c.internet_ingestion_enabled
      internet_query_enabled               = c.internet_query_enabled
      force_customer_storage_for_profiler  = c.force_customer_storage_for_profiler
    }
  }
  sensitive = true
}

output "ids" {
  description = "Map of component name to resource id."
  value       = { for k, c in azurerm_application_insights.this : k => c.id }
}

output "ids_zipmap" {
  description = "Map of component name to { name, id }, for easy composition with other modules."
  value       = { for k, c in azurerm_application_insights.this : k => { name = c.name, id = c.id } }
}

output "names" {
  description = "Map of component name to name (convenience passthrough)."
  value       = { for k, c in azurerm_application_insights.this : k => c.name }
}

output "app_ids" {
  description = "Map of component name to the App Insights application id (used by the query APIs; not the resource id)."
  value       = { for k, c in azurerm_application_insights.this : k => c.app_id }
}

output "connection_strings" {
  description = "Map of component name to connection string: what modern SDKs and app settings (APPLICATIONINSIGHTS_CONNECTION_STRING) embed."
  value       = { for k, c in azurerm_application_insights.this : k => c.connection_string }
  sensitive   = true
}

output "instrumentation_keys" {
  description = "Map of component name to instrumentation key (legacy embedding; prefer connection_strings, and note the key alone cannot ingest when local auth is disabled)."
  value       = { for k, c in azurerm_application_insights.this : k => c.instrumentation_key }
  sensitive   = true
}

output "workspace_ids" {
  description = "Map of component name to the Log Analytics workspace backing it."
  value       = { for k, c in azurerm_application_insights.this : k => c.workspace_id }
}

output "api_keys" {
  description = "The API keys, keyed \"component|name\". Full resource objects; sensitive because the generated api_key secret (only available at creation) is inside."
  value       = azurerm_application_insights_api_key.this
  sensitive   = true
}

output "api_key_ids" {
  description = "Map of \"component|name\" to API key resource id (non-sensitive)."
  value       = { for k, a in azurerm_application_insights_api_key.this : k => a.id }
}

output "analytics_items" {
  description = "The analytics items, keyed \"component|name\". Full resource objects."
  value       = azurerm_application_insights_analytics_item.this
}

output "smart_detection_rule_ids" {
  description = "Map of \"component|rule name\" to smart detection rule id."
  value       = { for k, r in azurerm_application_insights_smart_detection_rule.this : k => r.id }
}

output "monitoring_publisher_role_assignment_ids" {
  description = "Map of \"component|pN\" to the Monitoring Metrics Publisher role assignment id."
  value       = { for k, r in azurerm_role_assignment.monitoring_publisher : k => r.id }
}

output "resource_group_name" {
  description = "The resource group the components live in, parsed from resource_group_id."
  value       = local.rg_name
}
