# Project Bedrock - Retail Store EKS Microservices Capstone
............................................................
Highly available, production-grade microservices deployment running on AWS EKS, automated completely through HashiCorp Terraform.

## 🏗️ Architecture Design Overview
* **Network Infrastructure:** VPC isolated across 2 Availability Zones containing explicit public/private subnets and shared NAT Gateway routing.
* **Orchestration:** Managed Amazon EKS Cluster (v1.34) utilizing secure Native Access Entries (`API_AND_CONFIG_MAP`) and CloudWatch control plane log stream visibility.
* **Storage & Application Data Layers:** Relational tier powered by Amazon RDS (MySQL/PostgreSQL) isolated in private subnets, with high-performance state storage handled by Amazon DynamoDB.
* **Ingress Management:** Dynamic external routing via AWS Application Load Balancer (ALB) Controller maps external port `80` traffic to the front-facing UI service layer.

![Project Bedrock Architecture Diagram](./architecture-diagram.png)

## 🛠️ Deployment Configuration Engine
Infrastructure configurations are split across logical files within the `./terraform` directory:
* `vpc.tf` / `eks.tf` - Core structural network and compute tiers
* `rds.tf` / `dynamodb.tf` - Secure storage engines for state and backend components
* `apps.tf` - Automated Helm orchestration blocks for retail sub-services and the ALB ingress controller
* `backend.tf` - Remote state bucket and unified native s3 concurrency locking

## 🚀 CI/CD Pipeline
Fully automated continuous delivery engine configured via GitHub Actions (`.github/workflows/terraform.yml`). On every push event targeting the `main` branch, the pipeline performs:
1. Structural checks and lint validation
2. Remote state tracking evaluation
3. Automated structural compilation and live environment apply execution
4. Dynamic JSON output artifact generation (`grading.json`)

## 🌐 Verification & Testing

### Application Access
The live microservices retail application can be accessed publicly via our configured domain:
* **Production Endpoint:** `http://altsoe0254423.ddns.net/`

### Developer Workspace Audit
The dedicated developer identity (`bedrock-dev-view`) is restricted to read-only infrastructure auditing and explicit programmatic ingestion payloads via their dedicated S3 access keys found within the project delivery artifacts.
## 📦 Application Helm Packaging & Manual Deployment
The retail store front-end and back-end microservices are modularly packaged as Helm charts stored directly within this repository under the `apps/` ecosystem.

While primary deployment automation is managed via Terraform (`apps.tf`), the entire microservices stack can be manually installed, upgraded, or recovered using a single command with our custom configurations (which override data layers to point at managed AWS RDS and DynamoDB instances):

```bash
# Execute from the repository root to deploy the entire stack with your bedrock overrides
helm upgrade --install bedrock-retail ./apps/retail-store-sample-app \
  --namespace retail-app \
  --create-namespace \
  --values ./apps/retail-store-sample-app/bedrock-values.yaml

## 🛠️ Deployment Verification
To audit your running releases across your EKS namespaces, execute:

helm list --all-namespaces

### 🚀 How to Trigger the CI/CD Pipeline

The deployment pipeline is fully automated via GitHub Actions and is configured as a continuous delivery engine. To manually trigger a fresh compilation and deployment execution:

1. **Stage your local alterations** inside your Vagrant control machine:
   ```bash
   git add .

git commit -m "feat: comment"

git push origin main
