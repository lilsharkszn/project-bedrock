#!/bin/bash
set -e

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║        PROJECT BEDROCK — TEARDOWN        ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── Config ──────────────────────────────────────
CLUSTER_NAME="project-bedrock-cluster"
REGION="us-east-1"
NAMESPACE="retail-app"
INGRESS_NAME="retail-store-ingress"
VPC_ID="vpc-0d29ddd7a8a7fc1ee"
TF_DIR="$(dirname "$0")/terraform"

# ── Step 1: kubeconfig ───────────────────────────
echo "==> [1/7] Configuring kubectl..."
aws eks update-kubeconfig \
  --name "$CLUSTER_NAME" \
  --region "$REGION" && echo "    ✔ kubeconfig updated" \
  || echo "    ⚠ kubectl config failed - cluster may be partially down, continuing..."
echo ""

# ── Step 2: Patch finalizers off ingresses ───────
echo "==> [2/7] Removing finalizers from ingresses and targetgroupbindings..."
for ing in $(kubectl get ingress -n "$NAMESPACE" \
  -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
  echo "    Patching ingress: $ing"
  kubectl patch ingress "$ing" -n "$NAMESPACE" \
    --type=json \
    -p='[{"op":"remove","path":"/metadata/finalizers"}]' 2>/dev/null || true
done

for tgb in $(kubectl get targetgroupbinding -n "$NAMESPACE" \
  -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
  echo "    Patching targetgroupbinding: $tgb"
  kubectl patch targetgroupbinding "$tgb" -n "$NAMESPACE" \
    --type=json \
    -p='[{"op":"remove","path":"/metadata/finalizers"}]' 2>/dev/null || true
done
echo "    ✔ Finalizers removed"
echo ""

# ── Step 3: Delete ingress ────────────────────────
echo "==> [3/7] Deleting Kubernetes ingress (triggers ALB deletion)..."
kubectl delete ingress "$INGRESS_NAME" \
  -n "$NAMESPACE" \
  --ignore-not-found=true && echo "    ✔ Ingress deleted" \
  || echo "    ⚠ Could not delete ingress - may already be gone"
echo ""

# ── Step 4: Wait for ALB to be removed ───────────
echo "==> [4/7] Waiting for ALB Controller to remove ALB..."
for i in 1 2 3 4 5 6; do
  COUNT=$(aws elbv2 describe-load-balancers \
    --region "$REGION" \
    --query 'length(LoadBalancers[?contains(LoadBalancerName, `k8s-bedrockretail`)])' \
    --output text 2>/dev/null || echo "0")
  if [ "$COUNT" = "0" ]; then
    echo "    ✔ ALB is gone."
    break
  fi
  echo "    ALB still exists, waiting 30s... ($i/6)"
  sleep 30
done
echo ""

# ── Step 5: Delete leftover ALB security groups ──
echo "==> [5/7] Cleaning up ALB-created security groups..."
SG_IDS=$(aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'SecurityGroups[?starts_with(GroupName, `k8s-`)].GroupId' \
  --output text)

if [ -z "$SG_IDS" ]; then
  echo "    ✔ No leftover security groups found."
else
  for sg in $SG_IDS; do
    echo "    Deleting security group: $sg"
    aws ec2 delete-security-group --group-id "$sg" && \
      echo "    ✔ Deleted $sg" || \
      echo "    ⚠ Could not delete $sg - may already be gone"
  done
fi
echo ""

# ── Step 6: Wait for ENIs to clear ───────────────
echo "==> [6/7] Waiting for ENIs to detach..."
for i in 1 2 3; do
  ENI_COUNT=$(aws ec2 describe-network-interfaces \
    --filters \
      "Name=vpc-id,Values=$VPC_ID" \
      "Name=description,Values=ELB*" \
    --query 'length(NetworkInterfaces)' \
    --output text)
  if [ "$ENI_COUNT" = "0" ]; then
    echo "    ✔ No ALB ENIs remaining."
    break
  fi
  echo "    $ENI_COUNT ALB ENIs still attached, waiting 30s... ($i/3)"
  sleep 30
done
echo ""

# ── Step 7: Terraform destroy ─────────────────────
echo "==> [7/7] Running terraform destroy..."
cd "$TF_DIR"
terraform destroy -auto-approve

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║     ✔ BEDROCK FULLY TORN DOWN            ║"
echo "╚══════════════════════════════════════════╝"
echo ""
