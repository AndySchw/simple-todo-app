#!/bin/bash
set -e

# Simple Build & Deploy Script für Mac M1/M2/M3
# Baut AMD64-Images lokal und deployed zu EKS

REGION="eu-north-1"
ACCOUNT_ID="539247487622"
BACKEND_REPO="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/todo-backend"
FRONTEND_REPO="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/todo-frontend"

echo "🚀 Simple Todo App - Build & Deploy"
echo "===================================="
echo ""

# Frage was gebaut werden soll
PS3='Was möchtest du bauen? '
options=("Backend" "Frontend" "Beides" "Nur Deploy (kein Build)" "Abbrechen")
select opt in "${options[@]}"
do
    case $opt in
        "Backend")
            BUILD_BACKEND=true
            BUILD_FRONTEND=false
            break
            ;;
        "Frontend")
            BUILD_BACKEND=false
            BUILD_FRONTEND=true
            break
            ;;
        "Beides")
            BUILD_BACKEND=true
            BUILD_FRONTEND=true
            break
            ;;
        "Nur Deploy (kein Build)")
            BUILD_BACKEND=false
            BUILD_FRONTEND=false
            DEPLOY_ONLY=true
            break
            ;;
        "Abbrechen")
            echo "Abgebrochen."
            exit 0
            ;;
        *) echo "Ungültige Option $REPLY";;
    esac
done

echo ""

# ECR Login
if [ "$BUILD_BACKEND" = true ] || [ "$BUILD_FRONTEND" = true ]; then
    echo "🔐 Login zu ECR..."
    aws ecr get-login-password --region ${REGION} | \
        docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com
    echo "✅ ECR Login erfolgreich"
    echo ""
fi

# Backend bauen
if [ "$BUILD_BACKEND" = true ]; then
    echo "🔨 Baue Backend (AMD64)..."
    docker build --platform linux/amd64 \
        -t ${BACKEND_REPO}:latest \
        ./backend

    echo "📤 Pushe Backend zu ECR..."
    docker push ${BACKEND_REPO}:latest
    echo "✅ Backend erfolgreich gebaut und gepusht"
    echo ""
fi

# Frontend bauen
if [ "$BUILD_FRONTEND" = true ]; then
    echo "🔨 Baue Frontend..."
    docker build \
        -t ${FRONTEND_REPO}:latest \
        ./frontend

    echo "📤 Pushe Frontend zu ECR..."
    docker push ${FRONTEND_REPO}:latest
    echo "✅ Frontend erfolgreich gebaut und gepusht"
    echo ""
fi

# Deployment
if [ "$DEPLOY_ONLY" != true ]; then
    read -p "Möchtest du jetzt deployen? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ "$BUILD_BACKEND" = true ]; then
            echo "🚀 Starte Backend neu..."
            kubectl rollout restart deployment backend
            echo "⏳ Warte auf Backend..."
            kubectl rollout status deployment backend --timeout=120s
        fi

        if [ "$BUILD_FRONTEND" = true ]; then
            echo "🚀 Starte Frontend neu..."
            kubectl rollout restart deployment frontend
            echo "⏳ Warte auf Frontend..."
            kubectl rollout status deployment frontend --timeout=60s
        fi

        echo ""
        echo "✅ Deployment erfolgreich!"
        echo ""

        # Status anzeigen
        echo "📊 Pod Status:"
        kubectl get pods -l 'app in (backend,frontend,redis)'
        echo ""

        # Frontend URL anzeigen
        echo "🌐 Frontend URL:"
        kubectl get service frontend-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
        echo ""
    fi
fi

echo ""
echo "✨ Fertig!"
