provider "azurerm" {
  features {
    # Azure auto-creates a "Failure Anomalies - <name>" smart detector rule and an
    # "Application Insights Smart Detection" action group alongside every new component;
    # neither is in state, so the resource group delete fails the provider's
    # contains-resources safety check without this (proven live in the monitor-alerts E2E).
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }

  storage_use_azuread = true
  use_oidc            = true
}
