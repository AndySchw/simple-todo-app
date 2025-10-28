# Complete Deployment Guide - Simple Todo App auf EKS

## Übersicht

Dieses Guide führt dich durch das komplette Deployment der Todo-App auf AWS EKS mit RDS PostgreSQL und Redis.

## Architektur

```
┌─────────────────────────────────────────────────────────┐
│                    AWS Cloud                             │
│                                                          │
│  ┌────────────────────────────────────────────────┐    │
│  │              EKS Cluster (VPC)                 │    │
│  │                                                 │    │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐    │    │
│  │  │ Frontend │  │ Backend  │  │  Redis   │    │    │
│  │  │  (Nginx) │→│ (Spring) │→│ (Cache)  │    │    │
│  │  └──────────┘  └──────────┘  └──────────┘    │    │
│  │                      ↓                         │    │
│  └─────────────────────|─────────────────────────┘    │
│                         ↓                               │
│                   ┌──────────┐                         │
│                   │   RDS    │                         │
│                   │PostgreSQL│                         │
│                   └──────────┘                         │
└─────────────────────────────────────────────────────────┘
```

## Voraussetzungen

- AWS Account mit entsprechenden Berechtigungen
- AWS CLI installiert und konfiguriert
- kubectl installiert
- eksctl installiert
- Docker installiert
- GitHub Account (für CI/CD)

## Teil 1: RDS Datenbank erstellen

### 1.1 RDS PostgreSQL-Instance erstellen

```bash
aws rds create-db-instance \
  --db-instance-identifier todo-app-db \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --engine-version 15.4 \
  --master-username postgres \
  --master-user-password 'YourSecurePassword123!' \
  --allocated-storage 20 \
  --vpc-security-group-ids sg-XXXXXXXX \
  --db-subnet-group-name default \
  --publicly-accessible \
  --backup-retention-period 7 \
  --region eu-north-1
```

**Wichtig:** Notiere dir:
- RDS Endpoint (z.B. `todo-app-db.c98ky8au2kit.eu-north-1.rds.amazonaws.com`)
- Security Group ID (z.B. `sg-0afce072db758f08e`)
- VPC ID

### 1.2 Datenbank initialisieren

Verbinde dich zur RDS und erstelle die Datenbank:

```bash
psql -h todo-app-db.c98ky8au2kit.eu-north-1.rds.amazonaws.com \
     -U postgres \
     -d postgres

CREATE DATABASE tododb;
\q
```

## Teil 2: EKS Cluster erstellen

### 2.1 Cluster mit eksctl erstellen

```bash
eksctl create cluster -f kubernetes/cluster-config.yaml
```

Das dauert ca. 15-20 Minuten.

### 2.2 kubectl konfigurieren

```bash
aws eks update-kubeconfig --region eu-north-1 --name todo-app-cluster
```

### 2.3 Cluster verifizieren

```bash
kubectl get nodes
kubectl get pods --all-namespaces
```

## Teil 3: Networking - RDS und EKS verbinden

**KRITISCH:** EKS-Pods müssen auf RDS zugreifen können!

### 3.1 VPCs und Security Groups identifizieren

```bash
# EKS VPC und Security Group
aws eks describe-cluster --name todo-app-cluster --region eu-north-1 \
  --query 'cluster.resourcesVpcConfig.{VPC:vpcId,SecurityGroups:securityGroupIds}'

# RDS Security Group
aws rds describe-db-instances --db-instance-identifier todo-app-db --region eu-north-1 \
  --query 'DBInstances[0].{VPC:DBSubnetGroup.VpcId,SecurityGroup:VpcSecurityGroups[0].VpcSecurityGroupId}'
```

### 3.2 Security Group Rule hinzufügen

**Problem:** RDS Security Group blockiert standardmäßig Traffic von EKS.

**Lösung:** Füge Inbound-Rule hinzu:

```bash
aws ec2 authorize-security-group-ingress \
  --group-id <RDS-SECURITY-GROUP-ID> \
  --protocol tcp \
  --port 5432 \
  --source-group <EKS-SECURITY-GROUP-ID> \
  --region eu-north-1
```

**Beispiel:**
```bash
aws ec2 authorize-security-group-ingress \
  --group-id sg-0afce072db758f08e \
  --protocol tcp \
  --port 5432 \
  --source-group sg-08c76e92f4fdccfa4 \
  --region eu-north-1
```

## Teil 4: Docker Images bauen und zu ECR pushen

### 4.1 ECR Repositories erstellen

```bash
aws ecr create-repository --repository-name todo-frontend --region eu-north-1
aws ecr create-repository --repository-name todo-backend --region eu-north-1
```

### 4.2 GitHub Actions für automatische Builds

**Problem:** Lokale Mac M1/M2/M3 bauen ARM64-Images, aber EKS läuft auf AMD64!

**Lösung:** Verwende GitHub Actions für AMD64-Builds.

#### 4.2.1 GitHub Repository verbinden

```bash
cd /path/to/simple-todo-app
git init
git add .
git commit -m "Initial commit"
gh repo create simple-todo-app --public --source=. --remote=origin --push
```

#### 4.2.2 AWS Credentials als GitHub Secrets hinzufügen

1. Gehe zu: `https://github.com/<USERNAME>/simple-todo-app/settings/secrets/actions`
2. Füge hinzu:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_SESSION_TOKEN` (falls temporäre Credentials)

#### 4.2.3 Workflow triggern

```bash
gh workflow run build-backend.yml
```

Oder über Web UI: https://github.com/<USERNAME>/simple-todo-app/actions

### 4.3 Frontend-Image bauen (lokal möglich)

```bash
cd frontend
aws ecr get-login-password --region eu-north-1 | \
  docker login --username AWS --password-stdin <ACCOUNT-ID>.dkr.ecr.eu-north-1.amazonaws.com

docker build -t <ACCOUNT-ID>.dkr.ecr.eu-north-1.amazonaws.com/todo-frontend:latest .
docker push <ACCOUNT-ID>.dkr.ecr.eu-north-1.amazonaws.com/todo-frontend:latest
```

## Teil 5: Kubernetes Manifests anpassen

### 5.1 Backend-Deployment aktualisieren

Bearbeite `kubernetes/02-backend.yaml`:

```yaml
# Zeile 22: ECR Image
image: <ACCOUNT-ID>.dkr.ecr.eu-north-1.amazonaws.com/todo-backend:latest

# Zeile 29: RDS Endpoint
- name: DB_HOST
  value: "todo-app-db.c98ky8au2kit.eu-north-1.rds.amazonaws.com"

# Zeile 91: Datenbank-Passwort
stringData:
  password: "YourSecurePassword123!"
```

### 5.2 Frontend-Deployment aktualisieren

Bearbeite `kubernetes/03-frontend.yaml`:

```yaml
# Zeile 20: ECR Image
image: <ACCOUNT-ID>.dkr.ecr.eu-north-1.amazonaws.com/todo-frontend:latest
```

## Teil 6: Anwendung deployen

### 6.1 Redis deployen

```bash
kubectl apply -f kubernetes/01-redis.yaml
kubectl get pods -l app=redis
```

### 6.2 Backend deployen

```bash
kubectl apply -f kubernetes/02-backend.yaml
kubectl get pods -l app=backend
```

**Logs prüfen:**
```bash
kubectl logs -l app=backend --tail=50
```

### 6.3 Frontend deployen

```bash
kubectl apply -f kubernetes/03-frontend.yaml
kubectl get pods -l app=frontend
```

## Teil 7: Zugriff auf die Anwendung

### 7.1 LoadBalancer-IP ermitteln

```bash
kubectl get service frontend-service -o wide
```

Warte bis `EXTERNAL-IP` verfügbar ist (kann 2-3 Minuten dauern).

### 7.2 Anwendung öffnen

```bash
FRONTEND_URL=$(kubectl get service frontend-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Öffne: http://$FRONTEND_URL"
open "http://$FRONTEND_URL"
```

## Teil 8: Überwachung und Logs

### Alle Pods anzeigen
```bash
kubectl get pods --all-namespaces
```

### Pod-Logs anzeigen
```bash
kubectl logs <POD-NAME> --tail=100 -f
```

### Pod-Details
```bash
kubectl describe pod <POD-NAME>
```

### Service-Status
```bash
kubectl get services
kubectl get endpoints
```

## Troubleshooting

### Problem: Backend-Pods starten nicht (exec format error)

**Symptom:**
```
exec /usr/bin/java: exec format error
```

**Ursache:** Image wurde für falsche Architektur gebaut (ARM64 statt AMD64)

**Lösung:**
1. Verwende GitHub Actions für AMD64-Builds (siehe Teil 4.2)
2. Oder verwende `docker buildx` mit `--platform linux/amd64`

### Problem: Backend kann RDS nicht erreichen

**Symptom:**
```
org.postgresql.util.PSQLException: The connection attempt failed.
Caused by: java.net.SocketTimeoutException: Connect timed out
```

**Ursache:** RDS Security Group blockiert EKS

**Lösung:** Siehe Teil 3.2 - Security Group Rule hinzufügen

### Problem: GitHub Actions - 401 Unauthorized bei ECR Push

**Symptom:**
```
ERROR: failed to push: 401 Unauthorized
```

**Ursache:** IAM User hat keine ECR-Permissions

**Lösung:**
```bash
aws iam attach-user-policy \
  --user-name <IAM-USER> \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser
```

### Problem: kubectl kann nicht verbinden

**Symptom:**
```
Unable to connect to the server: dial tcp: i/o timeout
```

**Lösung:**
```bash
aws eks update-kubeconfig --region eu-north-1 --name todo-app-cluster
kubectl config get-contexts
kubectl config use-context arn:aws:eks:eu-north-1:<ACCOUNT-ID>:cluster/todo-app-cluster
```

## Wartung

### Updates deployen

```bash
# Nach Code-Änderungen
git add .
git commit -m "Update backend"
git push

# Workflow triggern
gh workflow run build-backend.yml

# Pods neu starten (nach erfolgreichem Build)
kubectl rollout restart deployment backend
kubectl rollout status deployment backend
```

### Anwendung skalieren

```bash
kubectl scale deployment backend --replicas=3
kubectl scale deployment frontend --replicas=2
```

### Logs aggregieren

```bash
kubectl logs -l app=backend --all-containers=true --tail=100
```

## Aufräumen

```bash
# Kubernetes-Ressourcen löschen
kubectl delete -f kubernetes/

# EKS-Cluster löschen
eksctl delete cluster --name todo-app-cluster --region eu-north-1

# RDS löschen
aws rds delete-db-instance \
  --db-instance-identifier todo-app-db \
  --skip-final-snapshot \
  --region eu-north-1

# ECR Repositories löschen
aws ecr delete-repository --repository-name todo-backend --force --region eu-north-1
aws ecr delete-repository --repository-name todo-frontend --force --region eu-north-1
```

## Kosten-Optimierung

- Verwende `t3.small` oder `t3.micro` Nodes
- Aktiviere Cluster Autoscaler
- Nutze Spot-Instances für Non-Production
- Lösche ungenutzte EBS Volumes
- Aktiviere RDS Backup-Retention nur wenn nötig

## Sicherheit

- ✅ RDS nicht öffentlich zugänglich machen (nur für Test)
- ✅ Security Groups nach Least-Privilege-Prinzip konfigurieren
- ✅ Secrets in AWS Secrets Manager oder Kubernetes Secrets
- ✅ IAM Roles für Service Accounts (IRSA) verwenden
- ✅ Network Policies in Kubernetes aktivieren
- ✅ Pod Security Standards enforc en

## Weitere Ressourcen

- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Spring Boot on Kubernetes](https://spring.io/guides/gs/spring-boot-kubernetes/)
