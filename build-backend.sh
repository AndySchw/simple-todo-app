#!/bin/bash
# Einfaches Build-Skript für Backend (funktioniert auf Mac M1/M2/M3 und Linux)

set -e

REGION="eu-north-1"
ACCOUNT_ID="539247487622"
IMAGE="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/todo-backend:latest"

echo "🔐 Login zu ECR..."
aws ecr get-login-password --region ${REGION} | \
    docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com

echo "🔨 Baue Backend-Image (AMD64)..."
docker build --platform linux/amd64 -t ${IMAGE} ./backend

echo "📤 Pushe zu ECR..."
docker push ${IMAGE}

echo "✅ Fertig! Image: ${IMAGE}"
echo ""
echo "Zum Deployen ausführen:"
echo "  kubectl rollout restart deployment backend"
