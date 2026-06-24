#!/bin/bash
set -e

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║        PROJECT BEDROCK — BRING UP        ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── Config ──────────────────────────────────────
CLUSTER_NAME="project-bedrock-cluster"
REGION="us-east-1"
ACCOUNT_ID="986263532474"
TF_DIR="$(dirname "$0")/terraform"

# ── Step 1: Terraform init ───────────────────────
echo "==> [1/6] Running terraform init..."
cd "$TF_DIR"
terraform init
echo "    ✔ Init complete"
echo ""

# ── Step 2: Terraform apply (first pass) ─────────
echo "==> [2/6] Running terraform apply (first pass - infrastructure)..."
terraform apply -auto-approve -target=module.vpc \
  -target=module.eks \
  -target=module.eks.module.eks_managed_node_group \
  -target=module.eks.module.kms \
  -target=aws_iam_policy.alb_controller_policy \
  -target=aws_iam_role.alb_controller_role \
  -target=aws_iam_role_policy_attachment.alb_controller_attach \
  -target=aws_db_subnet_group.db_subnet_group \
  -target=aws_security_group.db_sg \
  -target=aws_db_instance.mysql \
  -target=aws_db_instance.postgres \
  -target=aws_ssm_parameter.db_password \
  -target=aws_ssm_parameter.db_username \
  -target=aws_dynamodb_table.items \
  -target=aws_eks_addon.cloudwatch_observability || true
echo "    ✔ Infrastructure provisioned"
echo ""

# ── Step 3: Auth - kubeconfig + access entry ─────
echo "==> [3/6] Configuring kubectl and EKS access..."
aws eks update-kubeconfig \
  --name "$CLUSTER_NAME" \
  --region "$REGION"
echo "    ✔ kubeconfig updated"

aws eks create-access-entry \
  --cluster-name "$CLUSTER_NAME" \
  --principal-arn "arn:aws:iam::${ACCOUNT_ID}:user/bedrock-admin" \
  --type STANDARD 2>/dev/null && echo "    ✔ Access entry created" \
  || echo "    ℹ Access entry already exists, skipping."

aws eks associate-access-policy \
  --cluster-name "$CLUSTER_NAME" \
  --principal-arn "arn:aws:iam::${ACCOUNT_ID}:user/bedrock-admin" \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster 2>/dev/null && echo "    ✔ Admin policy associated" \
  || echo "    ℹ Policy already associated, skipping."
echo ""

# ── Step 4: Wait for nodes to be ready ───────────
echo "==> [4/6] Waiting for EKS nodes to be Ready..."
for i in $(seq 1 20); do
  READY=$(kubectl get nodes \
    --no-headers 2>/dev/null | grep -c " Ready" || echo "0")
  if [ "$READY" -gt "0" ]; then
    echo "    ✔ $READY node(s) Ready."
    break
  fi
  echo "    Nodes not ready yet, waiting 15s... ($i/20)"
  sleep 15
done
echo ""

# ── Step 5: Terraform apply (second pass) ────────
echo "==> [5/6] Running terraform apply (second pass - Kubernetes/Helm)..."
terraform apply -auto-approve
echo "    ✔ Full stack deployed"
echo ""

# ── Step 6: Verify ───────────────────────────────
echo "==> [6/6] Verifying deployment..."
echo ""

echo "    — EKS Cluster:"
aws eks describe-cluster \
  --name "$CLUSTER_NAME" \
  --query 'cluster.{Name:name,Version:version,Status:status}' \
  --output table

echo ""
echo "    — Nodes:"
kubectl get nodes

echo ""
echo "    — Pods (retail-app):"
kubectl get pods -n retail-app

echo ""
echo "    — ALB Ingress:"
kubectl get ingress -n retail-app

echo ""
echo "    — HTTP Check:"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  http://altsoe0254423.ddns.net || echo "unreachable")
echo "    Status: $HTTP_CODE"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ⚠  ACTION REQUIRED — UPDATE YOUR DNS                       ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "  New ALB hostname:"
kubectl get ingress retail-store-ingress -n retail-app \
  --output jsonpath='{.status.loadBalancer.ingress[0].hostname}' \
  2>/dev/null || echo "  ALB still provisioning - check again in 2 mins"
echo ""
echo "  Go to: https://www.noip.com/members/dns/"
echo "  Update: altsoe0254423.ddns.net → paste ALB hostname above"
echo ""

echo "╔══════════════════════════════════════════╗"
echo "║     ✔ BEDROCK IS LIVE                    ║"
echo "╚══════════════════════════════════════════╝"
echo ""
