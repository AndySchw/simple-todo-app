# Troubleshooting Guide - Simple Todo App

## Quick Diagnosis Commands

```bash
# Pod Status prüfen
kubectl get pods --all-namespaces

# Pod Logs anzeigen
kubectl logs <POD-NAME> --tail=100

# Pod Details
kubectl describe pod <POD-NAME>

# Service Status
kubectl get services
kubectl get endpoints

# Node Status
kubectl get nodes
```

## Häufige Probleme und Lösungen

### 1. Backend crasht mit "exec format error"

#### Symptom
```
exec /usr/bin/java: exec format error
```

#### Diagnose
```bash
kubectl logs -l app=backend --tail=10
```

#### Ursache
Docker-Image wurde für falsche CPU-Architektur gebaut:
- **ARM64**: Mac M1/M2/M3 buildet standardmäßig ARM64
- **AMD64/x86_64**: EKS Nodes laufen typischerweise auf AMD64

#### Lösung

**Option 1: GitHub Actions verwenden (Empfohlen)**
```bash
# Credentials setzen
gh secret set AWS_ACCESS_KEY_ID --body "YOUR_KEY"
gh secret set AWS_SECRET_ACCESS_KEY --body "YOUR_SECRET"
gh secret set AWS_SESSION_TOKEN --body "YOUR_TOKEN"  # Falls temporär

# Workflow triggern
gh workflow run build-backend.yml

# Nach erfolgreichem Build
kubectl rollout restart deployment backend
```

**Option 2: Lokaler Multi-Platform Build**
```bash
# QEMU für Cross-Platform builds
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

# Build für AMD64
docker buildx build --platform linux/amd64 \
  -t <ACCOUNT-ID>.dkr.ecr.eu-north-1.amazonaws.com/todo-backend:latest \
  --push \
  ./backend
```

**Option 3: ARM64 Nodes verwenden**
```yaml
# In cluster-config.yaml
nodeGroups:
  - name: app-workers
    instanceType: t4g.small  # Graviton (ARM64)
```

### 2. Backend kann RDS nicht erreichen

#### Symptom
```
org.postgresql.util.PSQLException: The connection attempt failed.
Caused by: java.net.SocketTimeoutException: Connect timed out
```

#### Diagnose
```bash
# Prüfe Backend-Logs
kubectl logs -l app=backend --tail=50

# Prüfe Pod-Networking
kubectl get pod <BACKEND-POD> -o wide

# Teste DNS-Auflösung
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  nslookup todo-app-db.c98ky8au2kit.eu-north-1.rds.amazonaws.com
```

#### Ursache
- RDS Security Group blockiert Traffic von EKS
- Falscher RDS-Endpoint in Config
- RDS in anderem VPC

#### Lösung

**Schritt 1: VPCs verifizieren**
```bash
# EKS VPC
aws eks describe-cluster --name todo-app-cluster --region eu-north-1 \
  --query 'cluster.resourcesVpcConfig.vpcId'

# RDS VPC
aws rds describe-db-instances --db-instance-identifier todo-app-db \
  --region eu-north-1 \
  --query 'DBInstances[0].DBSubnetGroup.VpcId'
```

**Schritt 2: Security Groups prüfen**
```bash
# EKS Security Group
aws eks describe-cluster --name todo-app-cluster --region eu-north-1 \
  --query 'cluster.resourcesVpcConfig.securityGroupIds[0]' \
  --output text

# RDS Security Group
aws rds describe-db-instances --db-instance-identifier todo-app-db \
  --region eu-north-1 \
  --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' \
  --output text

# RDS Inbound Rules
aws ec2 describe-security-groups \
  --group-ids <RDS-SG-ID> \
  --query 'SecurityGroups[0].IpPermissions'
```

**Schritt 3: Security Group Rule hinzufügen**
```bash
aws ec2 authorize-security-group-ingress \
  --group-id <RDS-SECURITY-GROUP-ID> \
  --protocol tcp \
  --port 5432 \
  --source-group <EKS-SECURITY-GROUP-ID> \
  --region eu-north-1
```

**Schritt 4: Pods neu starten**
```bash
kubectl delete pods -l app=backend
kubectl get pods -l app=backend -w
```

### 3. GitHub Actions - 401 Unauthorized bei ECR Push

#### Symptom
```
ERROR: failed to push: 401 Unauthorized
```

#### Ursache
- IAM User hat keine ECR-Permissions
- AWS Credentials sind abgelaufen
- Falsche Credentials in GitHub Secrets

#### Lösung

**Schritt 1: IAM Permissions prüfen**
```bash
aws iam list-attached-user-policies --user-name <IAM-USER>
```

**Schritt 2: ECR-Policy hinzufügen**
```bash
aws iam attach-user-policy \
  --user-name <IAM-USER> \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser
```

**Schritt 3: GitHub Secrets aktualisieren**
```bash
# Hole neue Credentials (falls temporär)
# Dann:
gh secret set AWS_ACCESS_KEY_ID --body "NEW_KEY"
gh secret set AWS_SECRET_ACCESS_KEY --body "NEW_SECRET"
gh secret set AWS_SESSION_TOKEN --body "NEW_TOKEN"
```

**Schritt 4: Workflow erneut triggern**
```bash
gh workflow run build-backend.yml
```

### 4. GitHub Actions - Security Token Expired

#### Symptom
```
The security token included in the request is expired
```

#### Ursache
Temporäre AWS Credentials (AWS Academy, SSO) sind abgelaufen

#### Lösung

**Für AWS Academy:**
1. Gehe zu AWS Academy Lab
2. Klicke "AWS Details"
3. Kopiere neue Credentials
4. Update GitHub Secrets:
```bash
gh secret set AWS_ACCESS_KEY_ID --body "ASIAX..."
gh secret set AWS_SECRET_ACCESS_KEY --body "..."
gh secret set AWS_SESSION_TOKEN --body "IQoJ..."
```

**Für permanenten Zugriff:**
Erstelle IAM User mit permanenten Credentials (siehe `docs/github-actions-aws-setup.md`)

### 5. kubectl kann nicht verbinden

#### Symptom
```
Unable to connect to the server: dial tcp: i/o timeout
error: You must be logged in to the server
```

#### Lösung

**Schritt 1: kubeconfig aktualisieren**
```bash
aws eks update-kubeconfig --region eu-north-1 --name todo-app-cluster
```

**Schritt 2: Context prüfen und setzen**
```bash
kubectl config get-contexts
kubectl config use-context arn:aws:eks:eu-north-1:<ACCOUNT-ID>:cluster/todo-app-cluster
```

**Schritt 3: AWS Credentials prüfen**
```bash
aws sts get-caller-identity
```

Falls expired:
```bash
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."
```

**Schritt 4: Mit Credentials kubectl aufrufen**
```bash
AWS_ACCESS_KEY_ID="..." \
AWS_SECRET_ACCESS_KEY="..." \
AWS_SESSION_TOKEN="..." \
kubectl get pods
```

### 6. Pod bleibt in "ImagePullBackOff"

#### Symptom
```bash
$ kubectl get pods
NAME                      READY   STATUS             RESTARTS   AGE
backend-xxx-yyy           0/1     ImagePullBackOff   0          2m
```

#### Diagnose
```bash
kubectl describe pod <POD-NAME>
```

#### Ursache
- Image existiert nicht in ECR
- Falsche Image-URL
- Keine Berechtigung zum Pullen

#### Lösung

**Prüfe ob Image in ECR existiert:**
```bash
aws ecr describe-images \
  --repository-name todo-backend \
  --region eu-north-1
```

**Falls nicht vorhanden, build und push:**
```bash
gh workflow run build-backend.yml
```

### 7. Redis Connection Failed

#### Symptom
```
Redis connection failed
```

#### Diagnose
```bash
kubectl get pods -l app=redis
kubectl logs -l app=redis
kubectl get service redis-service
```

#### Lösung
```bash
# Redis neu deployen
kubectl delete -f kubernetes/01-redis.yaml
kubectl apply -f kubernetes/01-redis.yaml

# Service prüfen
kubectl get endpoints redis-service
```

### 8. LoadBalancer bleibt in "Pending"

#### Symptom
```bash
$ kubectl get service frontend-service
NAME               TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
frontend-service   LoadBalancer   10.100.xx.xx    <pending>     80:xxxxx/TCP   5m
```

#### Ursache
- AWS LoadBalancer Controller nicht installiert
- Keine freien Elastic IPs
- Subnet hat kein IGW

#### Lösung

**Warte 2-3 Minuten** - LoadBalancer-Provisionierung dauert.

Falls nach 5 Minuten noch pending:
```bash
kubectl describe service frontend-service
kubectl get events --sort-by='.lastTimestamp'
```

## Debugging-Tools

### In Pod einloggen
```bash
kubectl exec -it <POD-NAME> -- /bin/sh
```

### Temporärer Debug-Pod
```bash
kubectl run -it --rm debug --image=busybox --restart=Never -- sh
```

### Port-Forwarding für lokalen Zugriff
```bash
kubectl port-forward service/backend-service 8080:8080
```

### Netzwerk-Tests
```bash
# DNS-Test
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  nslookup backend-service

# Connectivity-Test
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- \
  curl http://backend-service:8080/api/todos/health
```

## Logs sammeln

```bash
# Alle Backend-Logs
kubectl logs -l app=backend --all-containers=true --tail=100 > backend-logs.txt

# Events
kubectl get events --sort-by='.lastTimestamp' > events.txt

# Pod-Details
kubectl describe pod <POD-NAME> > pod-details.txt
```

## Performance-Debugging

### Pod-Ressourcen prüfen
```bash
kubectl top pods
kubectl top nodes
```

### Ressourcen-Limits erhöhen
```yaml
# In deployment yaml
resources:
  requests:
    memory: "1Gi"
    cpu: "500m"
  limits:
    memory: "2Gi"
    cpu: "1000m"
```

## Support

Bei weiteren Problemen:
1. Logs sammeln (siehe oben)
2. GitHub Issue erstellen: https://github.com/<USERNAME>/simple-todo-app/issues
3. Relevante Logs und Konfigurationen anhängen
