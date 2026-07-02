# check blocks run after every plan and apply and warn (without blocking) on configuration that would
# quietly weaken the module's posture.

# The module does nothing without at least one component.
check "creates_at_least_one_component" {
  assert {
    condition     = length(var.application_insights) > 0
    error_message = "No components would be created: set application_insights."
  }
}

# Instrumentation-key (local) auth is the legacy posture; opting into it should be a visible state,
# not a forgotten one.
check "local_auth_optins_are_visible" {
  assert {
    condition     = alltrue([for k, c in var.application_insights : !c.local_authentication_enabled])
    error_message = "These components accept instrumentation-key (local) ingestion: ${join(", ", sort([for k, c in var.application_insights : k if c.local_authentication_enabled]))}. The RBAC posture (local_authentication_enabled = false plus Monitoring Metrics Publisher grants) is the secure default."
  }
}

# A publisher grant on a local-auth component is legal but usually means the caller intended the RBAC
# posture and forgot to keep local auth off.
check "publishers_imply_rbac_posture" {
  assert {
    condition     = alltrue([for k, c in var.application_insights : !(c.local_authentication_enabled && length(c.monitoring_publishers) > 0)])
    error_message = "These components grant Monitoring Metrics Publisher but still accept instrumentation-key ingestion: ${join(", ", sort([for k, c in var.application_insights : k if c.local_authentication_enabled && length(c.monitoring_publishers) > 0]))}. Consider local_authentication_enabled = false so RBAC is the only ingestion path."
  }
}
