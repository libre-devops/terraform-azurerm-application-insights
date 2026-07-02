output "ids" {
  description = "Map of component name to resource id."
  value       = module.application_insights.ids
}

output "app_ids" {
  description = "Map of component name to App Insights application id."
  value       = module.application_insights.app_ids
}

output "connection_strings" {
  description = "Map of component name to connection string (what apps embed)."
  value       = module.application_insights.connection_strings
  sensitive   = true
}
