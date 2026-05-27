# Project Bedrock - Retail Store EKS Microservices Capstone

Highly available, production-grade microservices deployment running on AWS EKS, automated completely through HashiCorp Terraform.

## 🏗️ Architecture Design Overview
* **Network Infrastructure:** VPC isolated across 2 Availability Zones containing explicit public/private subnets and shared NAT Gateway routing.
* **Orchestration:** Managed Amazon EKS Cluster (v1.34) utilizing secure Native Access Entries (`API_AND_CONFIG_MAP`) and CloudWatch control plane log stream visibility.
* **Storage & Application Data Layers:** Relational tier powered by Amazon RDS (MySQL/PostgreSQL) isolated in private subnets, with high-performance state storage handled by Amazon DynamoDB.
* **Ingress Management:** Dynamic external routing via AWS Application Load Balancer (ALB) Controller maps external port `80` traffic to the front-facing UI service layer.

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
