# Plan-time tests for the module. The azurerm provider is mocked, so no credentials, no features
# block, and no cloud calls are needed:
#   terraform init -backend=false && terraform test

mock_provider "azurerm" {
  # Sub-resources parse application_insights_id, so the mocked component id must be real-shaped.
  mock_resource "azurerm_application_insights" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001/providers/Microsoft.Insights/components/appi-mock"
    }
  }
}

variables {
  resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001"
  location          = "uksouth"
  tags              = { Environment = "tst" }
  workspace_id      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001/providers/Microsoft.OperationalInsights/workspaces/log-ldo-uks-tst-001"
}

# The RBAC-first defaults: local auth off, workspace from the module default, publisher grant wired
# to the verified Monitoring Metrics Publisher role.
run "rbac_defaults" {
  command = apply

  variables {
    application_insights = {
      "appi-app" = {
        monitoring_publishers = ["11111111-1111-1111-1111-111111111111"]
      }
    }
  }

  assert {
    condition     = azurerm_application_insights.this["appi-app"].local_authentication_enabled == false
    error_message = "local_authentication_enabled should default to false (RBAC ingestion)."
  }

  assert {
    condition     = azurerm_application_insights.this["appi-app"].workspace_id != null
    error_message = "The component should inherit the module-level workspace."
  }

  assert {
    condition     = endswith(azurerm_role_assignment.monitoring_publisher["appi-app|p0"].role_definition_id, "3913510d-42f4-4e42-8a64-420c390055eb")
    error_message = "The publisher grant should use the Monitoring Metrics Publisher role."
  }

  assert {
    condition     = azurerm_application_insights.this["appi-app"].retention_in_days == 90
    error_message = "Retention should default to 90 days."
  }
}

# Opting into instrumentation-key ingestion works but the posture check makes it visible.
run "local_auth_optin_is_flagged" {
  command = plan

  variables {
    application_insights = {
      "appi-legacy" = {
        local_authentication_enabled = true
      }
    }
  }

  expect_failures = [check.local_auth_optins_are_visible]
}

# Publishers plus local auth trips both posture checks.
run "publishers_with_local_auth_flagged" {
  command = plan

  variables {
    application_insights = {
      "appi-mixed" = {
        local_authentication_enabled = true
        monitoring_publishers        = ["11111111-1111-1111-1111-111111111111"]
      }
    }
  }

  expect_failures = [
    check.local_auth_optins_are_visible,
    check.publishers_imply_rbac_posture,
  ]
}

# No workspace anywhere fails the plan (classic components are retired).
run "rejects_missing_workspace" {
  command = plan

  variables {
    workspace_id = null
    application_insights = {
      "appi-classic" = {}
    }
  }

  expect_failures = [azurerm_application_insights.this]
}

# The conditional sub-resources: api key, analytics item, and smart detection rule, keyed
# "component|name" and attached to the component id.
run "sub_resources" {
  command = apply

  variables {
    application_insights = {
      "appi-full" = {
        api_keys = {
          reader = { read_permissions = ["api", "search"] }
        }
        analytics_items = {
          slow-requests = {
            content = "requests | where duration > 5s | summarize count() by name"
          }
          parse-errors = {
            type           = "function"
            function_alias = "parseerrors"
            content        = "exceptions | order by timestamp desc"
          }
        }
        smart_detection_rules = {
          "Slow server response time" = {
            enabled                            = false
            send_emails_to_subscription_owners = false
          }
        }
      }
    }
  }

  assert {
    condition     = azurerm_application_insights_api_key.this["appi-full|reader"].read_permissions == toset(["api", "search"])
    error_message = "The api key permissions should pass through."
  }

  assert {
    condition     = azurerm_application_insights_analytics_item.this["appi-full|slow-requests"].type == "query" && azurerm_application_insights_analytics_item.this["appi-full|slow-requests"].scope == "shared"
    error_message = "Analytics items should default to shared queries."
  }

  assert {
    condition     = azurerm_application_insights_analytics_item.this["appi-full|parse-errors"].function_alias == "parseerrors"
    error_message = "Function items should carry their alias."
  }

  assert {
    condition     = azurerm_application_insights_smart_detection_rule.this["appi-full|Slow server response time"].enabled == false
    error_message = "The smart detection rule tuning should pass through."
  }
}

# An unknown smart detection rule name is rejected by variable validation.
run "rejects_unknown_smart_rule" {
  command = plan

  variables {
    application_insights = {
      "appi-bad" = {
        smart_detection_rules = {
          "Made up rule" = {}
        }
      }
    }
  }

  expect_failures = [var.application_insights]
}

# An invalid retention period is rejected by variable validation.
run "rejects_invalid_retention" {
  command = plan

  variables {
    application_insights = {
      "appi-bad" = { retention_in_days = 45 }
    }
  }

  expect_failures = [var.application_insights]
}
