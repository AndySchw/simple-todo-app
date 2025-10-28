#!/bin/bash
# Einfaches Build-Skript für Frontend

set -e

REGION="eu-north-1"
ACCOUNT_ID="539247487622"
IMAGE="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/todo-frontend:latest"

echo "🔐 Login zu ECR..."
aws ecr get-login-password --region ${REGION} | \
    docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com

echo "🔨 Baue Frontend-Image..."
docker build -t ${IMAGE} ./frontend

echo "📤 Pushe zu ECR..."
docker push ${IMAGE}

echo "✅ Fertig! Image: ${IMAGE}"
echo ""
echo "Zum Deployen ausführen:"
echo "  kubectl rollout restart deployment frontend"
