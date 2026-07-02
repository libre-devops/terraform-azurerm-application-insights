output "ids" {
  description = "Map of component name to resource id."
  value       = module.application_insights.ids
}

output "ids_zipmap" {
  description = "Map of component name to { name, id }."
  value       = module.application_insights.ids_zipmap
}

output "app_ids" {
  description = "Map of component name to App Insights application id."
  value       = module.application_insights.app_ids
}

output "workspace_ids" {
  description = "Map of component name to the backing Log Analytics workspace."
  value       = module.application_insights.workspace_ids
}

output "connection_strings" {
  description = "Map of component name to connection string (what apps embed)."
  value       = module.application_insights.connection_strings
  sensitive   = true
}

output "api_key_ids" {
  description = "Map of component|name to API key resource id."
  value       = module.application_insights.api_key_ids
}

output "analytics_items" {
  description = "The analytics items with their ids and versions."
  value       = module.application_insights.analytics_items
}

output "smart_detection_rule_ids" {
  description = "Map of component|rule to smart detection rule id."
  value       = module.application_insights.smart_detection_rule_ids
}

output "monitoring_publisher_role_assignment_ids" {
  description = "The Monitoring Metrics Publisher grants."
  value       = module.application_insights.monitoring_publisher_role_assignment_ids
}
