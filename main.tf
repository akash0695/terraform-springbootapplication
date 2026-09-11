terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  required_version = ">= 1.5.0"
}

provider "azurerm" {
  features {}
}

data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

resource "azurerm_log_analytics_workspace" "logs" {
  name                = "akashss-container-logs"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
}

resource "azurerm_container_app_environment" "environment" {
  name                       = "demo-container-environment"
  location                   = data.azurerm_resource_group.rg.location
  resource_group_name        = data.azurerm_resource_group.rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.logs.id
}

resource "azurerm_container_app_environment_certificate" "custom_domain" {
  count                        = var.custom_domain != "" ? 1 : 0
  name                         = replace(var.custom_domain, ".", "-")
  container_app_environment_id = azurerm_container_app_environment.environment.id
  certificate_blob_base64      = filebase64(var.certificate_path)
  certificate_password         = var.certificate_password
}

resource "azurerm_container_app" "app" {
  name                         = "spring-azure-demo"
  container_app_environment_id = azurerm_container_app_environment.environment.id
  resource_group_name          = data.azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    min_replicas = 0
    max_replicas = 1

    container {
      name   = "spring-app"
      image  = var.docker_image
      cpu    = 0.25
      memory = "0.5Gi"

      # ACA terminates public HTTPS and forwards HTTP to the container.
      env {
        name  = "SERVER_PORT"
        value = "8080"
      }
      env {
        name  = "SERVER_SSL_ENABLED"
        value = "false"
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8080
    transport        = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }

  }
}