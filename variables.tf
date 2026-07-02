variable "resource_group_id" {
  description = "Resource id of the resource group to create the components in. The name is parsed from it (pass the rg module's ids output)."
  type        = string

  validation {
    condition     = try(provider::azurerm::parse_resource_id(var.resource_group_id).resource_type, "") == "resourceGroups"
    error_message = "resource_group_id must be a resource group id of the form /subscriptions/<sub>/resourceGroups/<name>."
  }
}

variable "location" {
  description = "Azure region for the components."
  type        = string
}

variable "tags" {
  description = "Tags applied to every component (merged with any per-component tags)."
  type        = map(string)
  default     = {}
}

variable "workspace_id" {
  description = "Default Log Analytics workspace the components are based on (classic Application Insights is retired, so every component must be workspace-based). Overridable per component with its own workspace_id."
  type        = string
  default     = null
}

variable "application_insights" {
  description = <<DESC
The Application Insights components to create, keyed by component name. Every component is
workspace-based (set the module-level workspace_id or a per-component override; classic components
are retired).

AUTH POSTURE (RBAC vs instrumentation key): local_authentication_enabled defaults to FALSE, meaning
ingestion requires Entra ID (RBAC) auth and a bare instrumentation key or connection string is not
enough to send telemetry. Grant senders the Monitoring Metrics Publisher role on the component by
listing their principal ids in monitoring_publishers (the module creates the role assignments), or
grant it elsewhere. Set local_authentication_enabled = true for classic instrumentation-key
ingestion; a plan-time check makes that opt-in visible.

Per-component attributes: application_type (default web); workspace_id; retention_in_days (default
90); daily_data_cap_in_gb and daily_data_cap_notifications_enabled; sampling_percentage;
ip_masking_enabled; internet_ingestion_enabled / internet_query_enabled;
force_customer_storage_for_profiler; tags; monitoring_publishers (list of principal object ids
granted Monitoring Metrics Publisher on the component).

Conditional sub-resources, all keyed by name within the component:

- api_keys: read_permissions (agentconfig, aggregate, api, draft, extendqueries, search) and
  write_permissions (annotations). The generated api_key secret is only available at creation and is
  exported in the sensitive api_keys output.
- analytics_items: saved Log Analytics artefacts. type (query, function, folder, recent; default
  query), scope (shared or user; default shared; functions must be shared), content, function_alias
  (required for functions).
- smart_detection_rules: keyed by the built-in rule name (Slow page load time, Slow server response
  time, Long dependency duration, Degradation in server response time, Degradation in dependency
  duration, Degradation in trace severity ratio, Abnormal rise in exception volume, Abnormal rise in
  daily data volume, Potential memory leak detected, Potential security issue detected). enabled
  (default true), send_emails_to_subscription_owners (default true), additional_email_recipients.
DESC

  type = map(object({
    application_type                     = optional(string, "web")
    workspace_id                         = optional(string)
    retention_in_days                    = optional(number, 90)
    daily_data_cap_in_gb                 = optional(number)
    daily_data_cap_notifications_enabled = optional(bool)
    sampling_percentage                  = optional(number)
    ip_masking_enabled                   = optional(bool)
    local_authentication_enabled         = optional(bool, false)
    internet_ingestion_enabled           = optional(bool, true)
    internet_query_enabled               = optional(bool, true)
    force_customer_storage_for_profiler  = optional(bool, false)
    tags                                 = optional(map(string))

    monitoring_publishers = optional(list(string), [])

    api_keys = optional(map(object({
      read_permissions  = optional(list(string), [])
      write_permissions = optional(list(string), [])
    })), {})

    analytics_items = optional(map(object({
      content        = string
      type           = optional(string, "query")
      scope          = optional(string, "shared")
      function_alias = optional(string)
    })), {})

    smart_detection_rules = optional(map(object({
      enabled                            = optional(bool, true)
      send_emails_to_subscription_owners = optional(bool)
      additional_email_recipients        = optional(list(string))
    })), {})
  }))
  default = {}

  validation {
    condition     = alltrue([for c in values(var.application_insights) : contains(["ios", "java", "MobileCenter", "Node.JS", "other", "phone", "store", "web"], c.application_type)])
    error_message = "application_type must be one of: ios, java, MobileCenter, Node.JS, other, phone, store, web."
  }

  validation {
    condition     = alltrue([for c in values(var.application_insights) : contains([30, 60, 90, 120, 180, 270, 365, 550, 730], c.retention_in_days)])
    error_message = "retention_in_days must be one of: 30, 60, 90, 120, 180, 270, 365, 550, 730."
  }

  validation {
    condition = alltrue(flatten([
      for c in values(var.application_insights) : [
        for k in values(c.api_keys) : (
          alltrue([for p in k.read_permissions : contains(["agentconfig", "aggregate", "api", "draft", "extendqueries", "search"], p)]) &&
          alltrue([for p in k.write_permissions : contains(["annotations"], p)]) &&
          length(k.read_permissions) + length(k.write_permissions) > 0
        )
      ]
    ]))
    error_message = "Each api_keys entry needs at least one permission; read_permissions from agentconfig/aggregate/api/draft/extendqueries/search, write_permissions only annotations."
  }

  validation {
    condition = alltrue(flatten([
      for c in values(var.application_insights) : [
        for i in values(c.analytics_items) : (
          contains(["query", "function", "folder", "recent"], i.type) &&
          contains(["shared", "user"], i.scope) &&
          (i.type != "function" || (i.function_alias != null && i.scope == "shared"))
        )
      ]
    ]))
    error_message = "analytics_items: type must be query/function/folder/recent, scope shared/user, and functions need a function_alias with shared scope."
  }

  validation {
    condition = alltrue(flatten([
      for c in values(var.application_insights) : [
        for name, r in c.smart_detection_rules : contains([
          "Slow page load time", "Slow server response time", "Long dependency duration",
          "Degradation in server response time", "Degradation in dependency duration",
          "Degradation in trace severity ratio", "Abnormal rise in exception volume",
          "Abnormal rise in daily data volume", "Potential memory leak detected",
          "Potential security issue detected",
        ], name)
      ]
    ]))
    error_message = "smart_detection_rules keys must be the built-in rule names (for example \"Slow server response time\"); see the variable description for the full list."
  }

  validation {
    condition     = alltrue([for c in values(var.application_insights) : c.sampling_percentage == null || (coalesce(c.sampling_percentage, 100) > 0 && coalesce(c.sampling_percentage, 100) <= 100)])
    error_message = "sampling_percentage, when set, must be between 0 (exclusive) and 100 (inclusive)."
  }
}
