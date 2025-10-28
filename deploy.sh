#!/bin/bash
# Einfaches Deploy-Skript - startet Pods mit neuen Images neu

set -e

echo "🚀 Deploying Todo App..."
echo ""

# Backend neu starten
echo "📦 Starte Backend neu..."
kubectl rollout restart deployment backend
kubectl rollout status deployment backend --timeout=120s

# Frontend neu starten
echo "📦 Starte Frontend neu..."
kubectl rollout restart deployment frontend
kubectl rollout status deployment frontend --timeout=60s

echo ""
echo "✅ Deployment erfolgreich!"
echo ""

# Status anzeigen
echo "📊 Pod Status:"
kubectl get pods

echo ""
echo "🌐 Frontend URL:"
FRONTEND_URL=$(kubectl get service frontend-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "LoadBalancer noch nicht bereit")
echo "http://${FRONTEND_URL}"
