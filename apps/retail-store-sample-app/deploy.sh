#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

NAMESPACE="retail-app"
VALUES_FILE="bedrock-values.yaml"

echo "🚀 Starting deployment to namespace: $NAMESPACE"

# Ensure namespace
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

for chart_path in $(find src -name "chart" -type d); do
    service_name=$(basename $(dirname $chart_path))
    
    echo "----------------------------------------------------"
    echo "📦 Preparing and deploying service: $service_name"
    
    # NEW: Build dependencies before installing
    # This command resolves the Chart.yaml dependencies 
    # and fixes the "missing in charts/ directory" error
    if [ -f "$chart_path/Chart.yaml" ]; then
        helm dependency build "$chart_path"
    fi

    # Execute Helm upgrade
    helm upgrade --install "$service_name" "$chart_path" \
        -n "$NAMESPACE" \
        -f "$VALUES_FILE"
done

echo "----------------------------------------------------"
echo "✅ Deployment complete. Checking status..."
kubectl get pods -n "$NAMESPACE"
