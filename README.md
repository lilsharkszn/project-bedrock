# Project Bedrock - Retail Store EKS Microservices Capstone

Highly available, production-grade microservices deployment running on AWS EKS, automated completely through HashiCorp Terraform.

## Architecture Overview

- **Network:** VPC across 2 AZs with public/private subnets and NAT Gateway
- **Orchestration:** Amazon EKS Cluster v1.34 with CloudWatch control plane logging
- **Data Layer:** RDS PostgreSQL (catalog), RDS MySQL (orders), DynamoDB (carts)
- **Ingress:** AWS ALB Controller routing traffic to UI service
- **TLS/HTTPS:** cert-manager + Let's Encrypt via HTTP-01 challenge
- **Observability:** FluentBit + CloudWatch Agent on all nodes
- **Serverless:** S3 upload triggers Lambda to CloudWatch Logs
- **CI/CD:** GitHub Actions — terraform plan on PR, terraform apply on merge

![Architecture Diagram](./bedrock-screenshots/bedrockarchitecture.png)

---

## Terraform File Structure

| File | Purpose |
|------|---------|
| vpc.tf | VPC, 2 AZ subnets, NAT Gateway |
| eks.tf | EKS cluster v1.34, managed node groups |
| rds.tf | MySQL and PostgreSQL in private subnets |
| dynamodb.tf | Cart service DynamoDB table |
| apps.tf | Helm deployments, ALB Controller, ingress |
| tls.tf | cert-manager, Let's Encrypt, TLS ingress |
| backend.tf | S3 remote state, encryption |
| iam_developer.tf | Developer IAM user, RBAC, S3 permissions |
| monitoring.tf | CloudWatch Observability Add-on |
| serverless.tf | S3 bucket, Lambda, S3 event trigger |
| helm_provider.tf | Helm auth via EKS OIDC |
| kubernetes_provider.tf | Kubernetes auth via EKS OIDC |
| providers.tf | AWS, Kubernetes, Helm, Time providers |
| outputs.tf | Terraform outputs for grading.json |
| variables.tf | Input variable definitions |

---

## Infrastructure Details

- Region: us-east-1
- VPC: project-bedrock-vpc — 10.0.0.0/16
- EKS: project-bedrock-cluster — v1.34 — t3.small nodes
- RDS MySQL: bedrock-mysql (orders)
- RDS PostgreSQL: bedrock-postgres (catalog)
- DynamoDB: items table (carts)
- S3 Assets: bedrock-assets-adejare-alt-soe-025-4423
- Lambda: bedrock-asset-processor (Python)
- Tag: Project: karatu-2025-capstone

---

## Application Access

| Endpoint | URL |
|----------|-----|
| HTTP | http://altsoe0254423.ddns.net |
| HTTPS | https://altsoe0254423.ddns.net |
| ALB | k8s-retailap-retailst-17d19cf248-753918446.us-east-1.elb.amazonaws.com |

### Running Pods (retail-app namespace)

| Pod | Database |
|-----|----------|
| ui | N/A |
| catalog | RDS PostgreSQL |
| orders | RDS MySQL |
| carts | DynamoDB |
| checkout | N/A |
| checkout-redis | N/A |

---

## CI/CD Pipeline

Workflow: .github/workflows/CI_CD.yml

- Pull Request triggers terraform plan (output posted as PR comment)
- Merge to Main triggers kubectl setup then terraform apply then grading.json auto-committed

GitHub Secrets Required:
- AWS_ACCESS_KEY_ID
- AWS_SECRET_ACCESS_KEY

### Trigger Methods

Push to Main:
git add .
git commit -m "feat: description"
git push origin main


GitHub UI: Actions → Terraform CI/CD → Run workflow → main

GitHub CLI:

gh workflow run CI_CD.yml --ref main


---

## Terraform Remote State

- bucket: bedrock-tf-state-alt-soe-025-4423
- key: stage/bedrock-infra/terraform.tfstate
- region: us-east-1
- encrypt: true

Initialize:

cd terraform && terraform init


---

## Developer Access — bedrock-dev-view

| Access Type | Permission |
|-------------|-----------|
| AWS Console | ReadOnlyAccess |
| S3 Bucket | s3:PutObject on assets bucket |
| Kubernetes | ClusterRole/view (read-only) |

RBAC Verification:

kubectl auth can-i get pods -n retail-app --as bedrock-dev-view # yes kubectl auth can-i delete pods -n retail-app --as bedrock-dev-view # no


---

## Observability

Control Plane Logs enabled: API, Audit, Authenticator, ControllerManager, Scheduler

kubectl get pods -n amazon-cloudwatch aws logs tail /aws/lambda/bedrock-asset-processor --since 5m


---

## Serverless — S3 + Lambda

- Bucket: bedrock-assets-adejare-alt-soe-025-4423
- Lambda: bedrock-asset-processor (Python)
- Trigger: S3 PutObject → Lambda → logs "Image received: [filename]"

Note on S3 Bucket Naming: The required bucket name was previously created on an older AWS
account that was disabled due to a payment failure. Since S3 bucket names are globally unique
and cannot be reclaimed across accounts, the bucket was renamed with an adejare prefix while
retaining the student ID suffix. All functionality is fully operational.

Test:

aws s3 cp /etc/hostname s3://bedrock-assets-adejare-alt-soe-025-4423/test.txt aws logs tail /aws/lambda/bedrock-asset-processor --since 1m


---

## TLS / HTTPS

- cert-manager installed via Helm in cert-manager namespace
- Let's Encrypt production ACME (HTTP-01 via ALB)

kubectl get pods -n cert-manager kubectl get certificate -n retail-app kubectl get clusterissuer


---

## Helm Manual Deployment

helm upgrade --install bedrock-retail ./apps/retail-store-sample-app
--namespace retail-app
--create-namespace
--values ./apps/retail-store-sample-app/bedrock-values.yaml


---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Pods pending | kubectl describe pod name -n retail-app |
| DB connection fails | Check RDS security group allows EKS nodes |
| Ingress pending | Check aws-load-balancer-controller in kube-system |
| TLS cert not ready | kubectl describe certificate retail-store-tls -n retail-app |
| State lock stuck | terraform force-unlock LOCK_ID |
| CI/CD kubectl error | Ensure kubeconfig step runs before terraform apply |

---

## Screenshots and Proof of Deployment

### Architecture Diagram
![Architecture](./bedrock-screenshots/bedrockarchitecture.png)

### All Pods Running
![Pods](./bedrock-screenshots/kubectl%20get%20pods.png)

### App Live in Browser
![Browser](./bedrock-screenshots/altsoe0254423ddnsnet.png)

### HTTP 200 Response
![HTTP 200](./bedrock-screenshots/HTTP%20200.png)

### EKS Cluster
![EKS](./bedrock-screenshots/project-bedrock-cluster.png)

### VPC
![VPC](./bedrock-screenshots/vpc-04c53b138a32c4cf6.png)

### IAM User Policies
![IAM](./bedrock-screenshots/IAM%20User%20Policies.png)

### RBAC Verification
![RBAC](./bedrock-screenshots/RBAC%20Verification.png)

### Control Plane Logging
![Logging](./bedrock-screenshots/Control%20Plane%20Logging.png)

### FluentBit and CloudWatch Pods
![FluentBit](./bedrock-screenshots/FluentBit%20+%20CloudWatch%20Pods.png)

### Lambda Trigger Working
![Lambda](./bedrock-screenshots/Lambda%20Trigger%20Working.png)

### Resource Tagging
![Tagging](./bedrock-screenshots/Resource%20Tagging.png)

### CI/CD Pipeline
![CICD](./bedrock-screenshots/cicd%20github.png)

### grading.json
![Grading](./bedrock-screenshots/grading-json.png)

---

Last Updated: 2026-06-07 | Project: karatu-2025-capstone | Student ID: adejare-alt-soe-025-4423
