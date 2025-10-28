# Quick Start - Einfachste Methode

## Du hast einen Mac M1/M2/M3? Kein Problem!

Die Docker-Images funktionieren jetzt automatisch auf beiden Architekturen (ARM64 und AMD64).

## 3 Super-Einfache Befehle

### 1. Backend bauen und pushen
```bash
./build-backend.sh
```

Das war's! Das Skript:
- ✅ Loggt dich in ECR ein
- ✅ Baut ein AMD64-Image (funktioniert auf EKS)
- ✅ Pusht es zu ECR

### 2. Frontend bauen und pushen (optional)
```bash
./build-frontend.sh
```

### 3. Deployen
```bash
./deploy.sh
```

## Oder alles manuell (auch super einfach):

### Backend
```bash
# Login
aws ecr get-login-password --region eu-north-1 | \
  docker login --username AWS --password-stdin 539247487622.dkr.ecr.eu-north-1.amazonaws.com

# Build (mit --platform flag!)
docker build --platform linux/amd64 \
  -t 539247487622.dkr.ecr.eu-north-1.amazonaws.com/todo-backend:latest \
  ./backend

# Push
docker push 539247487622.dkr.ecr.eu-north-1.amazonaws.com/todo-backend:latest

# Deploy
kubectl rollout restart deployment backend
```

### Frontend
```bash
# Login (falls noch nicht eingeloggt)
aws ecr get-login-password --region eu-north-1 | \
  docker login --username AWS --password-stdin 539247487622.dkr.ecr.eu-north-1.amazonaws.com

# Build (Frontend ist architektur-unabhängig)
docker build \
  -t 539247487622.dkr.ecr.eu-north-1.amazonaws.com/todo-frontend:latest \
  ./frontend

# Push
docker push 539247487622.dkr.ecr.eu-north-1.amazonaws.com/todo-frontend:latest

# Deploy
kubectl rollout restart deployment frontend
```

## Das Wichtigste: `--platform linux/amd64`

Das ist der einzige Unterschied! Wenn du `docker build` ausführst, füge einfach hinzu:

```bash
--platform linux/amd64
```

**Warum funktioniert das auf deinem ARM64-Mac?**
Docker emuliert automatisch AMD64 via QEMU. Es ist etwas langsamer beim Build, aber funktioniert perfekt!

## GitHub Actions (Alternative)

Wenn du nicht lokal bauen willst:

```bash
# 1. Code ändern und pushen
git add backend/
git commit -m "Update backend"
git push

# 2. GitHub Actions baut automatisch AMD64
# (siehe: https://github.com/AndySchw/simple-todo-app/actions)

# 3. Nach erfolgreichem Build, deployen
kubectl rollout restart deployment backend
```

## Status prüfen

```bash
# Pods anzeigen
kubectl get pods

# Logs anzeigen
kubectl logs -l app=backend --tail=50

# Frontend URL
kubectl get service frontend-service
```

## Troubleshooting

### "exec format error"
→ Du hast `--platform linux/amd64` vergessen!
→ Lösung: Benutze die Build-Skripte oder füge das Flag hinzu

### "denied: User not authenticated"
→ ECR Login abgelaufen
→ Lösung: Nochmal `aws ecr get-login-password ... | docker login ...` ausführen

### "The security token expired"
→ AWS Credentials abgelaufen
→ Lösung: Neue Credentials exportieren:
```bash
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."
```

## Das war's!

Jetzt funktionieren die Images auf EKS (AMD64) auch wenn du auf einem Mac (ARM64) baust!
