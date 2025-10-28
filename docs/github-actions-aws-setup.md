# GitHub Actions AWS Setup

## Problem
Deine AWS-Credentials sind abgelaufen. GitHub Actions benötigt permanente (nicht temporäre) Credentials.

## Lösung: IAM User für CI/CD erstellen

### Schritt 1: IAM User erstellen (über AWS Console)

1. Gehe zu AWS Console → IAM → Users
2. Klicke "Add users"
3. Username: `github-actions-simple-todo`
4. Wähle: "Access key - Programmatic access"
5. Klicke "Next: Permissions"

### Schritt 2: Permissions zuweisen

Wähle eine der Optionen:

**Option A: Minimale Permissions (Empfohlen)**
Erstelle eine Policy mit nur den benötigten Rechten:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    }
  ]
}
```

**Option B: Schnelle Lösung (weniger sicher)**
Attach Policy: `AmazonEC2ContainerRegistryPowerUser`

### Schritt 3: Access Keys speichern

1. Nach dem Erstellen bekommst du:
   - Access Key ID
   - Secret Access Key
2. **WICHTIG**: Speichere diese sofort, sie werden nur einmal angezeigt!

### Schritt 4: In GitHub Secrets einfügen

1. Gehe zu: https://github.com/AndySchw/simple-todo-app/settings/secrets/actions

2. Füge hinzu:
   ```
   Name: AWS_ACCESS_KEY_ID
   Value: [Dein Access Key ID]

   Name: AWS_SECRET_ACCESS_KEY
   Value: [Dein Secret Access Key]
   ```

### Schritt 5: Workflow testen

1. Gehe zu: https://github.com/AndySchw/simple-todo-app/actions/workflows/build-backend.yml
2. Klicke "Run workflow"
3. Warte bis das AMD64-Image gebaut und zu ECR gepusht wurde

### Schritt 6: Backend neu starten

```bash
# Stelle sicher, dass kubectl funktioniert
kubectl get pods

# Restart Backend-Deployment
kubectl rollout restart deployment backend

# Überwache den Status
kubectl rollout status deployment backend
kubectl get pods -l app=backend
```

## Alternative: AWS OIDC (Fortgeschritten)

Statt Access Keys kannst du auch OIDC verwenden (keine Secrets nötig):
- Sicherer
- Keine permanenten Credentials
- Erfordert IAM Role Setup

Siehe: https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services

## Troubleshooting

### "The security token included in the request is invalid"
→ Credentials sind falsch oder abgelaufen
→ Erstelle neue permanente Credentials (siehe oben)

### "Access Denied"
→ IAM User hat nicht genug Permissions
→ Füge ECR-Permissions hinzu (siehe Schritt 2)

### Build funktioniert, aber Push schlägt fehl
→ ECR Repository existiert nicht oder falsche Region
→ Prüfe: `aws ecr describe-repositories --region eu-north-1`
