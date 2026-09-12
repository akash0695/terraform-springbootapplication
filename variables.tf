variable "resource_group_name" {
  type    = string
  default = "akash"
}

variable "location" {
  type    = string
  default = "Central India"
}

variable "docker_image" {
  type    = string
  default = "docker.io/akashshyam101/spring-azure-demo:v1"
}

variable "custom_domain" {
  type        = string
  description = "Custom hostname for the Container App. Leave empty to disable custom-domain configuration."
  default     = ""
}

variable "certificate_path" {
  type        = string
  description = "Path to the password-protected PFX certificate for the custom domain."
  default     = ""
}

variable "certificate_password" {
  type        = string
  description = "Password for the custom-domain PFX certificate."
  sensitive   = true
  default     = ""
}