# Terraform and Custom Domain Setup

This document describes the final deployment for the Spring Boot application on Azure Container Apps using `akashcreations.com` as a custom domain. The domain registration and DNS hosting are handled through Google Cloud DNS.

## Architecture

```text
akashcreations.com
        |
        | Google Cloud DNS
        | A record -> Azure Container Apps environment IP
        v
Azure Container App Environment
        |
        v
spring-azure-demo Container App
        |
        v
Docker Hub image
```

Azure Container Apps terminates public HTTPS and forwards HTTP traffic to the container on port `8080`.

## Terraform-managed resources

The Terraform configuration in `main.tf` manages:

- The existing Azure resource group through a data source.
- Log Analytics workspace: `akashss-container-logs`.
- Container Apps environment: `demo-container-environment`.
- Container Apps environment certificate: `akashcreations-com`.
- Container App: `spring-azure-demo`.

The Container App is configured with:

- Consumption-style scaling with `min_replicas = 0` and `max_replicas = 1`.
- `0.25` vCPU and `0.5Gi` memory.
- External ingress on target port `8080`.
- The Docker image from `var.docker_image`.
- `SERVER_PORT=8080`.
- `SERVER_SSL_ENABLED=false`.

The application must use HTTP inside the container because Azure handles the public HTTPS connection.

## Required files and variables

The example values are in `terraform.tfvars.example`:

```hcl
custom_domain    = "akashcreations.com"
certificate_path = "C:/secure-certificates/akashcreations-clean.p12"
```

Supply the PKCS12 password securely at apply time. Do not put it in a committed `.tfvars` file:

```powershell
terraform apply `
  -var-file="terraform.tfvars.example" `
  -var="certificate_password=YOUR_P12_PASSWORD"
```

The certificate must:

- Be a PKCS12/PFX file.
- Contain the private key.
- Contain a certificate whose SAN includes `akashcreations.com`.
- Be unexpired.
- Preferably contain one private-key entry and the required certificate chain.
- Use a certificate issued by a trusted CA for production browser access.

A self-signed certificate can be imported and bound, but browsers will display a certificate warning.

## Initialize and validate Terraform

From `C:\terraform-azure-demo`:

```powershell
az login
terraform init
terraform fmt -check
terraform validate
```

Review the deployment before applying:

```powershell
terraform plan `
  -var-file="terraform.tfvars.example" `
  -var="certificate_password=YOUR_P12_PASSWORD"
```

Apply the infrastructure:

```powershell
terraform apply `
  -var-file="terraform.tfvars.example" `
  -var="certificate_password=YOUR_P12_PASSWORD"
```

Useful outputs:

```powershell
terraform output application_url
terraform output -raw container_app_environment_static_ip
terraform output -raw custom_domain_verification_id
```

The verification output is sensitive and should not be posted publicly.

## Google Cloud DNS configuration

The Google Cloud DNS managed zone must be public and must use the exact nameservers assigned to that zone. The nameservers are not always the same for every zone. Retrieve the current values with:

```bash
gcloud dns managed-zones describe akashcreations \
  --format="yaml(name,dnsName,visibility,nameServers)"
```

For this deployment, the zone was assigned nameservers in the `ns-cloud-b1` through `ns-cloud-b4` group. Use the exact nameservers returned by the command above.

### Update registrar nameservers

At the registrar where `akashcreations.com` was purchased:

1. Open the domain's nameserver settings.
2. Remove the old nameservers.
3. Add all four nameservers shown by the Cloud DNS zone.
4. Save the change.

Do not add the Google nameservers as ordinary records inside the zone. They must be configured at the registrar.

Keep DNSSEC disabled unless DNSSEC is also configured correctly in Google Cloud DNS and the generated DS record is published at the registrar. A stale or mismatched DS record can cause `SERVFAIL`.

### Add DNS records

In the public Cloud DNS zone for `akashcreations.com`, add:

| Type | DNS name | Value | TTL |
|---|---|---|---:|
| TXT | `asuid` | The value from `custom_domain_verification_id` | 300 |
| A | `@` or blank | The value from `container_app_environment_static_ip` | 300 |

For the deployed environment, the values were:

```text
TXT name:  asuid.akashcreations.com
TXT value: F3D37EC19A50E2C62BB20FA3B8CC5A23E5F922FE5864913DF4D2D23A68283723
A name:    akashcreations.com
A value:   20.44.62.236
```

The verification token is environment-specific. Use the current Terraform output if the environment is recreated.

### Verify DNS

From Cloud Shell or another machine with `dig`:

```bash
dig NS akashcreations.com @8.8.8.8
dig TXT asuid.akashcreations.com @8.8.8.8
dig A akashcreations.com @8.8.8.8
```

Expected results:

```text
TXT: F3D37EC19A50E2C62BB20FA3B8CC5A23E5F922FE5864913DF4D2D23A68283723
A:   20.44.62.236
```

If Google nameservers return `REFUSED` or public DNS returns `SERVFAIL`, check that:

- The registrar uses the nameservers assigned to the current Cloud DNS zone.
- The zone is `public`.
- The domain has no stale DNSSEC DS record.
- The DNS records exist in the correct zone.

## Bind the hostname in Azure

The AzureRM provider version used in this project exposes `ingress.custom_domain` as a computed-only attribute. Therefore, the certificate is managed by Terraform, but the hostname binding is completed with Azure CLI after DNS propagation.

Use the certificate resource ID:

```powershell
az containerapp hostname bind `
  --name spring-azure-demo `
  --resource-group akash `
  --hostname akashcreations.com `
  --certificate "/subscriptions/c8cc91d8-eb93-4053-859a-1e14aa00ec98/resourceGroups/akash/providers/Microsoft.App/managedEnvironments/demo-container-environment/certificates/akashcreations-com"
```

A successful response contains:

```json
[
  {
    "bindingType": "SniEnabled",
    "name": "akashcreations.com"
  }
]
```

Verify the binding:

```powershell
az containerapp hostname list `
  --name spring-azure-demo `
  --resource-group akash `
  --output table
```

## Test the application

Test the Azure-provided hostname first:

```powershell
curl.exe -I https://spring-azure-demo.wonderfulwater-b55ecb5f.southindia.azurecontainerapps.io
```

Then test the custom domain:

```powershell
curl.exe -I https://akashcreations.com
```

If the certificate is self-signed, use `-k` only for testing:

```powershell
curl.exe -k -I https://akashcreations.com
```

If the custom domain works with `--resolve` but not in the browser, the Azure app is working and the local DNS resolver/cache needs attention:

```powershell
curl.exe -k -I --resolve akashcreations.com:443:20.44.62.236 https://akashcreations.com
ipconfig /flushdns
```

Changing the local DNS server to `8.8.8.8` or `1.1.1.1` is only a client-side workaround for a failing local resolver; it does not change Azure or Google Cloud DNS.

## Rollback and cleanup

Always review a destroy plan before deleting resources:

```powershell
terraform plan -destroy `
  -var-file="terraform.tfvars.example" `
  -var="certificate_password=YOUR_P12_PASSWORD"
```

To remove Terraform-managed Azure resources:

```powershell
terraform destroy `
  -var-file="terraform.tfvars.example" `
  -var="certificate_password=YOUR_P12_PASSWORD"
```

Removing the Terraform certificate resource does not automatically remove a DNS record at Google Cloud DNS. Remove DNS records separately if the domain is no longer used.

## Security notes

- Do not commit certificate passwords, private keys, PKCS12 files, or Terraform state files.
- Terraform state can contain certificate metadata and sensitive infrastructure values. Store it securely.
- Rotate any password that has been exposed in source files, terminal history, or chat.
- Use a trusted, renewable certificate such as Let’s Encrypt for production.
- Do not use the development script `generate-ssl-certificate.bat` as a production certificate generator; it creates a self-signed certificate.
