You can use **Terraform + Azure** to create and deploy containerized applications in a repeatable way.

A common architecture is:

**Spring Boot application → Docker image → Azure Container Registry (ACR) → Azure Container Apps**

## 1. Overall flow

```text
Java/Spring Boot App
        ↓
Build JAR
        ↓
Create Docker Image
        ↓
Push to Azure Container Registry
        ↓
Terraform creates Azure infrastructure
        ↓
Azure Container App runs the container
```

---

## 2. Project structure

```text
my-project/
│
├── src/
├── Dockerfile
├── pom.xml
│
└── terraform/
    ├── main.tf
    ├── variables.tf
    └── outputs.tf
```

---

## 3. Create Docker image for Spring Boot

Example `Dockerfile`:

```dockerfile
FROM eclipse-temurin:17-jre

WORKDIR /app

COPY target/my-app.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
```

Build your application:

```bash
mvn clean package
```

Build the Docker image:

```bash
docker build -t my-spring-app:v1 .
```

---

## 4. Terraform configuration for Azure

### `main.tf`

```hcl
provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "my-app-rg"
  location = "Central India"
}

resource "azurerm_container_registry" "acr" {
  name                = "myuniqueacr123"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true
}

resource "azurerm_log_analytics_workspace" "logs" {
  name                = "my-app-logs"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
}

resource "azurerm_container_app_environment" "env" {
  name                       = "my-container-env"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.logs.id
}

resource "azurerm_container_app" "app" {
  name                         = "my-spring-app"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name

  revision_mode = "Single"

  template {
    container {
      name   = "spring-app"
      image  = "myuniqueacr123.azurecr.io/my-spring-app:v1"
      cpu    = 0.5
      memory = "1Gi"
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8080

    traffic_weight {
      latest_revision = true
      percentage       = 100
    }
  }
}
```

---

## 5. Terraform commands

First, authenticate with Azure:

```bash
az login
```

Initialize Terraform:

```bash
terraform init
```

Check what resources will be created:

```bash
terraform plan
```

Create the Azure infrastructure:

```bash
terraform apply
```

Terraform will create:

* Resource Group
* Azure Container Registry
* Log Analytics Workspace
* Container App Environment
* Azure Container App

---

## 6. Push your Docker image to ACR

After Terraform creates ACR:

```bash
az acr login --name myuniqueacr123
```

Tag the image:

```bash
docker tag my-spring-app:v1 \
myuniqueacr123.azurecr.io/my-spring-app:v1
```

Push it:

```bash
docker push myuniqueacr123.azurecr.io/my-spring-app:v1
```

Then your Azure Container App can run this image.

---

## Interview answer

You can explain it like this:

> **"We containerize the Spring Boot application using a Dockerfile. Terraform is then used to create Azure infrastructure such as the Resource Group, Azure Container Registry, and Azure Container App. The Docker image is pushed to ACR, and the Azure Container App pulls the image from ACR and runs the application. Terraform makes the infrastructure repeatable and allows us to manage infrastructure using Infrastructure as Code."**

### Important point

**Terraform usually manages the Azure infrastructure. Docker builds the container image. A CI/CD pipeline can automate both the Docker image deployment and Terraform execution.**

For example:

```text
Developer pushes code
        ↓
GitHub Actions / Azure DevOps
        ↓
Build Spring Boot JAR
        ↓
Docker build
        ↓
Push image to ACR
        ↓
Terraform apply
        ↓
Deploy new image to Azure Container App
```

For your **Java/Spring Boot interview preparation**, this is a very good real-world example because you can explain both **Docker containerization and Terraform infrastructure provisioning** together.



Yes. Since you are a beginner and using a personal Azure account, I recommend starting with the **simplest and lowest-risk setup**:

> **Local Spring Boot app → Docker image → Docker Hub → Terraform → Azure Container Apps**

For the first learning deployment, **do not use Azure Kubernetes Service or Azure Container Registry**. They add complexity and can create unexpected costs. Azure Container Apps has a free monthly grant and can scale to zero when idle, though you should still monitor your subscription and set a budget alert. ([Microsoft Azure][1])

I assume you are using **Windows**, based on your recent setup.

---

# Step 0: What we are going to create

```text
Your Computer
│
├── Java / Spring Boot
├── Maven
├── Docker Desktop
├── Terraform
└── Azure CLI
        │
        ▼
    Docker Image
        │
        ▼
    Docker Hub
        │
        ▼
Terraform creates Azure resources
        │
        ▼
Azure Container Apps
        │
        ▼
Public URL
```

For the first deployment, we will use a **public Docker image**, so Azure does not need credentials to pull the image.

---

# Step 1: Check your Azure subscription

Open **PowerShell** and install Azure CLI if it is not already installed. Microsoft provides the official Windows installation instructions here:

[Install Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest&utm_source=chatgpt.com)

After installation, close and reopen PowerShell.

Run:

```powershell
az version
```

You should see Azure CLI version information.

Now log in:

```powershell
az login
```

A browser will open. Log in using your personal Azure account.

Check your subscription:

```powershell
az account show
```

Check all subscriptions:

```powershell
az account list --output table
```

You should see your personal subscription.

Terraform can use your Azure CLI login for local authentication, which is the recommended approach for local Terraform work. ([Microsoft Learn][2])

---

# Step 2: Install Terraform

Install Terraform from the official HashiCorp installation page:

[Install Terraform](https://developer.hashicorp.com/terraform/install?utm_source=chatgpt.com)

After installation, open a new PowerShell window and run:

```powershell
terraform -version
```

You should get output similar to:

```text
Terraform v1.x.x
```

If you get:

```text
terraform is not recognized
```

then Terraform was not added correctly to your Windows `PATH`. Microsoft's Azure Terraform guide also describes adding the Terraform executable directory to `PATH`. ([Microsoft Learn][3])

---

# Step 3: Install Docker Desktop

You need Docker Desktop because we will containerize your Spring Boot application.

After installation, verify:

```powershell
docker --version
```

Then check:

```powershell
docker ps
```

If Docker Desktop is not running, start it first.

---

# Step 4: Create a simple Spring Boot application

If you already have a Spring Boot application, you can use that.

Your project may look like this:

```text
spring-azure-demo/
│
├── src/
├── pom.xml
└── Dockerfile
```

For a simple REST API, create:

```text
src/main/java/com/example/demo/HelloController.java
```

```java
package com.example.demo;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HelloController {

    @GetMapping("/")
    public String hello() {
        return "Hello! My Spring Boot application is running on Azure.";
    }
}
```

Make sure your application runs locally:

```powershell
mvn spring-boot:run
```

Open:

```text
http://localhost:8080
```

You should see:

```text
Hello! My Spring Boot application is running on Azure.
```

Stop the application with:

```text
Ctrl + C
```

---

# Step 5: Create the Dockerfile

In the root of your Spring Boot project, create:

```text
Dockerfile
```

Add:

```dockerfile
FROM eclipse-temurin:17-jre

WORKDIR /app

COPY target/*.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
```

Now build your Spring Boot JAR:

```powershell
mvn clean package
```

You should see a file inside:

```text
target/
```

For example:

```text
target/demo-0.0.1-SNAPSHOT.jar
```

---

# Step 6: Build and test the Docker container locally

Build the Docker image:

```powershell
docker build -t spring-azure-demo:v1 .
```

Check:

```powershell
docker images
```

Run it:

```powershell
docker run -p 8080:8080 spring-azure-demo:v1
```

Open:

```text
http://localhost:8080
```

If everything works, stop the container:

```text
Ctrl + C
```

At this point, you have successfully containerized your application.

---

# Step 7: Create a Docker Hub account

For the beginner setup, I recommend using Docker Hub instead of Azure Container Registry.

Create a free Docker Hub account and create a public repository named:

```text
spring-azure-demo
```

Suppose your Docker Hub username is:

```text
akashgupta
```

Tag your image:

```powershell
docker tag spring-azure-demo:v1 akashgupta/spring-azure-demo:v1
```

Log in:

```powershell
docker login
```

Push the image:

```powershell
docker push akashgupta/spring-azure-demo:v1
```

Your image will then be available publicly as:

```text
docker.io/akashgupta/spring-azure-demo:v1
```

---

# Step 8: Create the Terraform project

Create a separate folder:

```text
terraform-azure-demo/
│
├── main.tf
├── variables.tf
└── outputs.tf
```

Open this folder in VS Code.

---

# Step 9: Create `main.tf`

Add:

```hcl
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

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_log_analytics_workspace" "logs" {
  name                = "demo-logs-12345"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
}

resource "azurerm_container_app_environment" "environment" {
  name                       = "demo-container-environment"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.logs.id
}

resource "azurerm_container_app" "app" {
  name                         = "spring-azure-demo"
  container_app_environment_id = azurerm_container_app_environment.environment.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    min_replicas = 0
    max_replicas = 1

    container {
      name   = "spring-app"
      image  = var.docker_image
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8080

    traffic_weight {
      latest_revision = true
      percentage       = 100
    }
  }
}
```

The `min_replicas = 0` setting is important for a low-cost learning environment because Container Apps can scale to zero when there is no active work. Azure also currently advertises a monthly free grant for a certain amount of Container Apps usage. ([Microsoft Azure][1])

---

# Step 10: Create `variables.tf`

```hcl
variable "resource_group_name" {
  type    = string
  default = "rg-terraform-learning"
}

variable "location" {
  type    = string
  default = "Central India"
}

variable "docker_image" {
  type    = string
  default = "docker.io/YOUR_DOCKER_USERNAME/spring-azure-demo:v1"
}
```

Replace:

```text
YOUR_DOCKER_USERNAME
```

with your actual Docker Hub username.

Example:

```hcl
default = "docker.io/akashgupta/spring-azure-demo:v1"
```

---

# Step 11: Create `outputs.tf`

```hcl
output "application_url" {
  value = "https://${azurerm_container_app.app.ingress[0].fqdn}"
}
```

After deployment, Terraform will print your application URL.

---

# Step 12: Register Azure resource providers

Before running Terraform, execute:

```powershell
az provider register --namespace Microsoft.App
```

Then:

```powershell
az provider register --namespace Microsoft.OperationalInsights
```

These are commonly required for Azure Container Apps and the associated logging resources. Microsoft documents these provider registrations in its Container Apps setup guidance. ([Microsoft Learn][4])

You can check the status:

```powershell
az provider show --namespace Microsoft.App --query registrationState
```

Wait until it shows:

```text
Registered
```

---

# Step 13: Initialize Terraform

Open PowerShell inside your Terraform folder:

```powershell
cd terraform-azure-demo
```

Run:

```powershell
terraform init
```

Terraform will download the Azure provider.

You should see something similar to:

```text
Terraform has been successfully initialized!
```

---

# Step 14: Validate the Terraform code

Run:

```powershell
terraform validate
```

Then format your files:

```powershell
terraform fmt
```

---

# Step 15: Check what Terraform will create

Run:

```powershell
terraform plan
```

Terraform should show resources similar to:

```text
+ Resource Group
+ Log Analytics Workspace
+ Container App Environment
+ Container App
```

**Nothing is created yet.**

This command is safe for checking the configuration.

---

# Step 16: Deploy to Azure

Now run:

```powershell
terraform apply
```

Terraform will ask:

```text
Do you want to perform these actions?
```

Type:

```text
yes
```

Terraform will create the resources.

The deployment may take a few minutes.

---

# Step 17: Get the application URL

After successful deployment:

```text
Outputs:

application_url = "https://..."
```

Copy that URL and open it in your browser.

You should see:

```text
Hello! My Spring Boot application is running on Azure.
```

Congratulations — you have deployed a Dockerized Spring Boot application using Terraform.

---

# Step 18: Check your resources in Azure Portal

Go to the Azure Portal and search for:

```text
Resource groups
```

Open:

```text
rg-terraform-learning
```

You should see your Terraform-created resources.

---

# Step 19: Very important — destroy resources after testing

Since this is your personal Azure account, after testing, run:

```powershell
terraform destroy
```

Type:

```text
yes
```

Terraform will delete all resources that it created.

This is one of the biggest advantages of Terraform:

```text
terraform apply
        ↓
Creates infrastructure

terraform destroy
        ↓
Deletes infrastructure
```

You can check your Azure bill afterward to make sure no unexpected resources remain.

---

## Your beginner learning order

I recommend learning in exactly this sequence:

### Day 1: Terraform basics

Learn:

```text
main.tf
variables.tf
outputs.tf

terraform init
terraform validate
terraform plan
terraform apply
terraform destroy
```

### Day 2: Azure authentication

Practice:

```powershell
az login
az account show
az account list
```

### Day 3: Docker

Practice:

```powershell
docker build
docker images
docker run
docker ps
docker stop
```

### Day 4: Containerize Spring Boot

Practice:

```text
Spring Boot
    ↓
Maven package
    ↓
JAR
    ↓
Docker image
    ↓
Run locally
```

### Day 5: Deploy using Terraform

Practice:

```text
Docker Hub
    ↓
Terraform
    ↓
Azure Container Apps
```

---

## One important note about “free”

I would not call the deployment **guaranteed permanently free**. Azure pricing and free-account entitlements can change, and other resources such as logging can potentially incur charges. For your personal learning environment, use **small resource settings, `min_replicas = 0`, `max_replicas = 1`, and delete resources with `terraform destroy` when finished**. Azure currently advertises a monthly Container Apps free grant and scale-to-zero behavior. ([Microsoft Azure][1])

**My recommendation:** First complete the deployment above using the public Docker Hub image. Once that works, the next step should be **using Terraform to create an Azure Container Registry and deploying your private Docker image from ACR**.

[1]: https://acom-sandbox.azure.net/en-us/products/container-apps/?utm_source=chatgpt.com "Azure Container Apps | Microsoft Azure"
[2]: https://learn.microsoft.com/en-us/azure/developer/terraform/authenticate-to-azure?utm_source=chatgpt.com "Authenticate Terraform to Azure | Microsoft Learn"
[3]: https://learn.microsoft.com/en-us/azure/developer/terraform/get-started-windows-powershell?utm_source=chatgpt.com "Install Terraform on Windows with Azure PowerShell | Microsoft Learn"
[4]: https://learn.microsoft.com/en-us/azure/container-apps/get-started?utm_source=chatgpt.com "Quickstart: Deploy your first container app with containerapp up | Microsoft Learn"
