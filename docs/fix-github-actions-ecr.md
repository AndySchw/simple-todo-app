# Fix: GitHub Actions ECR Push Fehler (401 Unauthorized)

## Problem
```
ERROR: failed to push 539247487622.dkr.ecr.eu-north-1.amazonaws.com/todo-backend:latest: 401 Unauthorized
```

**Ursache:** Der IAM User `AdminAndy` hat keine ECR-Push-Berechtigungen.

## Lösung: ECR-Permissions hinzufügen

### Option 1: Über AWS Console (Empfohlen)

#### Schritt 1: Gehe zur IAM Console
1. Öffne: https://console.aws.amazon.com/iam/
2. Klicke auf "Users" in der linken Seitenleiste
3. Suche und klicke auf User: `AdminAndy`

#### Schritt 2: Policy hinzufügen
1. Klicke auf den Tab "Permissions"
2. Klicke "Add permissions" → "Attach policies directly"

**Option A - Einfach (Managed Policy):**
- Suche nach: `AmazonEC2ContainerRegistryPowerUser`
- Wähle die Policy aus
- Klicke "Next" → "Add permissions"

**Option B - Sicherer (Custom Policy):**
1. Klicke "Create policy"
2. Wähle JSON-Tab
3. Kopiere den Inhalt von `docs/ecr-iam-policy.json`
4. Paste in das JSON-Feld
5. Klicke "Next"
6. Name: `GitHubActions-ECR-TodoBackend`
7. Klicke "Create policy"
8. Gehe zurück zu User `AdminAndy` → "Add permissions"
9. Suche die neue Policy und füge sie hinzu

### Option 2: Via AWS CLI

```bash
# Erstelle Policy
aws iam create-policy \
  --policy-name GitHubActions-ECR-TodoBackend \
  --policy-document file://docs/ecr-iam-policy.json

# Füge Policy zum User hinzu (ersetze ACCOUNT_ID)
aws iam attach-user-policy \
  --user-name AdminAndy \
  --policy-arn arn:aws:iam::729638402721:policy/GitHubActions-ECR-TodoBackend
```

**ODER** verwende Managed Policy (einfacher):
```bash
aws iam attach-user-policy \
  --user-name AdminAndy \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser
```

### Option 3: ECR Repository Policy anpassen

Falls du die IAM User Permissions nicht ändern kannst, passe die ECR Repository Policy an:

1. Gehe zu: https://console.aws.amazon.com/ecr/repositories
2. Region: `eu-north-1`
3. Klicke auf Repository: `todo-backend`
4. Klicke auf "Permissions" Tab
5. Klicke "Edit policy JSON"
6. Füge hinzu:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowPushPull",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::729638402721:user/AdminAndy"
      },
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:CompleteLayerUpload",
        "ecr:GetDownloadUrlForLayer",
        "ecr:InitiateLayerUpload",
        "ecr:PutImage",
        "ecr:UploadLayerPart"
      ]
    }
  ]
}
```

## Nach dem Hinzufügen der Permissions

### 1. Teste lokal (optional)
```bash
# Login zu ECR
aws ecr get-login-password --region eu-north-1 | \
  docker login --username AWS --password-stdin 539247487622.dkr.ecr.eu-north-1.amazonaws.com

# Test Push
docker tag 539247487622.dkr.ecr.eu-north-1.amazonaws.com/todo-backend:latest \
  539247487622.dkr.ecr.eu-north-1.amazonaws.com/todo-backend:test
docker push 539247487622.dkr.ecr.eu-north-1.amazonaws.com/todo-backend:test
```

### 2. Triggere GitHub Actions erneut
```bash
gh workflow run build-backend.yml
```

Oder über Web UI:
https://github.com/AndySchw/simple-todo-app/actions/workflows/build-backend.yml
→ Klicke "Run workflow"

### 3. Überwache den Build
https://github.com/AndySchw/simple-todo-app/actions

### 4. Nach erfolgreichem Build
```bash
# Restart Backend Deployment
kubectl rollout restart deployment backend

# Überwache Status
kubectl rollout status deployment backend
kubectl get pods -l app=backend
```

## Troubleshooting

### Fehler bleibt nach Policy-Hinzufügung
→ Warte 1-2 Minuten (IAM-Propagierung)
→ Triggere Workflow erneut

### "Access Denied" beim Policy erstellen
→ Du hast keine IAM-Admin-Rechte
→ Bitte Admin, die Policy hinzuzufügen
→ Oder verwende Option 3 (Repository Policy)

### ECR Repository existiert nicht
```bash
# Erstelle Repository
aws ecr create-repository \
  --repository-name todo-backend \
  --region eu-north-1
```

## Verifizierung

Nach erfolgreicher Policy-Zuweisung solltest du sehen:

**In GitHub Actions:**
```
✅ Login to Amazon ECR
✅ Build and push Docker image (AMD64)
✅ Image pushed to: 539247487622.dkr.ecr.eu-north-1.amazonaws.com/todo-backend:latest
```

**In kubectl:**
```bash
$ kubectl get pods -l app=backend
NAME                       READY   STATUS    RESTARTS   AGE
backend-76dcfb859c-abc12   1/1     Running   0          2m
backend-76dcfb859c-def34   1/1     Running   0          2m
```
