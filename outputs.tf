output "application_url" {
  value = "https://${azurerm_container_app.app.ingress[0].fqdn}"
}

output "custom_domain_verification_id" {
  value       = azurerm_container_app.app.custom_domain_verification_id
  sensitive   = true
  description = "Create a TXT record named asuid.<custom-domain> with this value before binding the custom domain."
}

output "container_app_environment_static_ip" {
  value       = azurerm_container_app_environment.environment.static_ip_address
  description = "Use this as the A record value when mapping an apex domain."
}

output "custom_domain_url" {
  value       = var.custom_domain != "" ? "https://${var.custom_domain}" : null
  description = "HTTPS URL for the configured custom domain."
}