# Simple Todo App - Deployment Guide mit Lens

## Überblick: Was wir bauen

```
┌─────────────────────────────────────────────────────────────┐
│                     AWS Cloud                               │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │              EKS Cluster (Kubernetes)                  │ │
│  │                                                        │ │
│  │  ┌──────────┐    ┌──────────┐    ┌──────────┐       │ │
│  │  │ Frontend │───▶│ Backend  │───▶│  Redis   │       │ │
│  │  │  (Nginx) │    │ (Spring) │    │ (Cache)  │       │ │
│  │  │ 2 Replicas    │ 2 Replicas    │ 1 Replica │       │ │
│  │  └──────────┘    └──────────┘    └──────────┘       │ │
│  │       │                │                              │ │
│  │       │                └──────────────┐               │ │
│  │       │                               ▼               │ │
│  └───────┼───────────────────────────────────────────────┘ │
│          │                          ┌──────────┐           │
│          │                          │   RDS    │           │
│          │                          │(Postgres)│           │
│          │                          └──────────┘           │
│          ▼                                                 │
│     [Load Balancer]                                        │
│          ▼                                                 │
└──────────┼─────────────────────────────────────────────────┘
           │
           ▼
       Internet (Du!)
```

---

## Phase 1: Vorbereitung (10 Min)

### Schritt 1: EKS Cluster erstellen

**WICHTIG:** Zuerst den Cluster erstellen, DANN die RDS in derselben VPC!

```bash
cd kubernetes/

# Cluster erstellen (dauert 15-20 Min)
eksctl create cluster -f cluster-config.yaml

# ☕ Kaffee trinken...
```

**Was passiert:**
```
✓ VPC wird erstellt (172.31.0.0/16)
✓ 2x Public Subnets
✓ 2x Private Subnets
✓ Internet Gateway + NAT Gateway
✓ EKS Control Plane
✓ 2x t3.small Worker Nodes
✓ kubectl config wird automatisch aktualisiert
```

### Schritt 2: Cluster prüfen

```bash
# Nodes anzeigen
kubectl get nodes

# Output:
# NAME                                           STATUS   AGE
# ip-192-168-xx-xx.eu-north-1.compute.internal   Ready    2m
# ip-192-168-xx-xx.eu-north-1.compute.internal   Ready    2m

# Labels prüfen
kubectl get nodes --show-labels | grep tier
```

### Schritt 3: RDS Datenbank erstellen

**JETZT die RDS in derselben VPC wie der Cluster!**

Folge: `00-rds-setup.md` → **"Option 2: AWS CLI"** (nutzt VPC vom Cluster!)

**Ergebnis:** Du hast:
- ✅ RDS PostgreSQL Datenbank (in EKS VPC!)
- ✅ RDS Endpoint (z.B. `todo-app-db.abc123.eu-north-1.rds.amazonaws.com`)
- ✅ Passwort (z.B. `YourSecurePassword123!`)

```bash
# VPC ID vom Cluster holen
export VPC_ID=$(aws eks describe-cluster \
  --name todo-app-cluster \
  --region eu-north-1 \
  --query 'cluster.resourcesVpcConfig.vpcId' \
  --output text)

echo "EKS VPC ID: $VPC_ID"

# Jetzt RDS in DIESER VPC erstellen (siehe 00-rds-setup.md)
```

---

## 🎯 LENS CHECKPOINT 1: Cluster in Lens anschauen

### Lens öffnen
```bash
open -a Lens  # oder: open -a OpenLens
```

### In Lens:
1. **Catalog** → **Clusters**
2. Du siehst: `todo-app-cluster (eu-north-1)` ✅
3. **Klick drauf!**

### Was du siehst:
```
Dashboard:
├── Cluster: todo-app-cluster
├── Nodes: 2 (beide Ready)
├── CPU Usage: ~5%
├── Memory: ~400 MB / 4 GB
└── Pods: ~10 (nur System-Pods)
```

### Nodes anschauen:
1. **Sidebar:** `Nodes`
2. **Klick auf einen Node**
3. **Siehst du:**
   - Labels: `tier: application`, `project: todo-app`
   - Capacity: 2 CPU, 2 GB RAM
   - Allocatable: ~1.8 CPU, ~1.5 GB RAM
   - Running Pods: kube-proxy, aws-node, etc.

**✅ Checkpoint erfolgreich:** Du siehst deinen leeren Cluster!

---

## Phase 2: Docker Images bauen (15 Min)

### Schritt 4: Docker Images bauen & zu ECR hochladen

**WICHTIG:** Folge zuerst: `docker-images-ecr.md` für komplette Anleitung!

**Kurzversion:**

```bash
cd ../backend/

# Docker Image bauen
docker build -t todo-backend:v1.0 .

# Das dauert 3-5 Minuten beim ersten Mal (Maven Dependencies)
```

**Was passiert:**
```
1. Maven Download Dependencies
2. Build Spring Boot JAR
3. Create Docker Image mit JRE
4. Final size: ~250 MB
```

### Schritt 5: Frontend Image bauen

```bash
cd ../frontend/

# Docker Image bauen
docker build -t todo-frontend:v1.0 .

# Das dauert nur 10 Sekunden!
```

### Schritt 6: Images nach ECR pushen (optional)

**Ohne ECR (für lokales Testing):** Skip this!

**Mit ECR (für EKS Production):**

```bash
# ECR Repository erstellen
aws ecr create-repository \
  --repository-name todo-backend \
  --region eu-north-1

aws ecr create-repository \
  --repository-name todo-frontend \
  --region eu-north-1

# Login zu ECR
aws ecr get-login-password --region eu-north-1 | \
  docker login --username AWS --password-stdin \
  <ACCOUNT_ID>.dkr.ecr.eu-north-1.amazonaws.com

# Images taggen
docker tag todo-backend:v1.0 \
  <ACCOUNT_ID>.dkr.ecr.eu-north-1.amazonaws.com/todo-backend:v1.0

docker tag todo-frontend:v1.0 \
  <ACCOUNT_ID>.dkr.ecr.eu-north-1.amazonaws.com/todo-frontend:v1.0

# Images pushen
docker push <ACCOUNT_ID>.dkr.ecr.eu-north-1.amazonaws.com/todo-backend:v1.0
docker push <ACCOUNT_ID>.dkr.ecr.eu-north-1.amazonaws.com/todo-frontend:v1.0
```

---

## Phase 3: Redis deployen (5 Min)

### Schritt 7: Redis YAML anpassen (optional)

```bash
cd ../kubernetes/

# Redis YAML anschauen
cat 01-redis.yaml

# Alles gut, nichts zu ändern!
```

### Schritt 8: Redis deployen

```bash
# Redis deployen
kubectl apply -f 01-redis.yaml

# Output:
# deployment.apps/redis created
# service/redis-service created
```

### Schritt 9: Redis Pods prüfen

```bash
# Pods anschauen
kubectl get pods

# Output:
# NAME                     READY   STATUS    RESTARTS   AGE
# redis-xxxxxxxxxx-xxxxx   1/1     Running   0          30s

# Deployment prüfen
kubectl get deployments

# Service prüfen
kubectl get services
```

---

## 🎯 LENS CHECKPOINT 2: Redis in Lens anschauen

### In Lens:
1. **Workloads** → **Deployments**
2. **Siehst du:** `redis` (1/1 Ready) ✅

3. **Klick auf `redis` Deployment**
   - Status: 1/1 Replicas
   - Pods: redis-xxx (Running)
   - Image: redis:7-alpine

4. **Workloads** → **Pods**
5. **Klick auf den Redis Pod**
   - Status: Running
   - Node: ip-192-168-xx-xx
   - Containers: redis (Running)

### Redis Shell öffnen (in Lens!):
1. **Pod anklicken**
2. **[Shell] Button klicken**
3. **Im Terminal:**
   ```bash
   redis-cli

   # Im Redis CLI:
   PING
   # Output: PONG ✅

   SET test "Hello from Lens!"
   GET test
   # Output: "Hello from Lens!"

   exit
   ```

**✅ Checkpoint erfolgreich:** Redis läuft und du kannst reinschauen!

---

## Phase 4: Backend deployen (10 Min)

### Schritt 10: Backend YAML anpassen

```bash
# Öffne: kubernetes/02-backend.yaml

# ÄNDERN:
# 1. Docker Image
image: <YOUR_DOCKER_IMAGE>
# Ersetze mit: todo-backend:v1.0 (lokal)
# Oder: <ACCOUNT_ID>.dkr.ecr.eu-north-1.amazonaws.com/todo-backend:v1.0

# 2. RDS Endpoint
- name: DB_HOST
  value: "<YOUR_RDS_ENDPOINT>"
# Ersetze mit: todo-app-db.abc123.eu-north-1.rds.amazonaws.com

# 3. DB Passwort (im Secret)
stringData:
  password: "YourSecurePassword123!"
# Ersetze mit deinem RDS Passwort
```

### Schritt 11: Backend deployen

```bash
# Backend deployen
kubectl apply -f 02-backend.yaml

# Output:
# deployment.apps/backend created
# service/backend-service created
# secret/db-secret created
```

### Schritt 12: Backend Pods prüfen

```bash
# Pods live beobachten
kubectl get pods -w

# Output:
# NAME                       READY   STATUS    AGE
# redis-xxx                  1/1     Running   5m
# backend-xxxxxxxxxx-xxxxx   0/1     Pending   5s   ← Wird erstellt
# backend-xxxxxxxxxx-yyyyy   0/1     Pending   5s

# Nach 30-60 Sekunden:
# backend-xxx   1/1     Running   1m
# backend-yyy   1/1     Running   1m
```

---

## 🎯 LENS CHECKPOINT 3: Backend in Lens - LIVE beobachten!

### In Lens (während Backend startet):
1. **Workloads** → **Deployments**
2. **Siehst du:** `backend` (0/2 Ready → 1/2 Ready → 2/2 Ready) 🎬

3. **Workloads** → **Pods**
4. **Backend Pods live beobachten:**
   - Status: Pending → ContainerCreating → Running
   - Du siehst wie sie starten! ⏱️

5. **Klick auf einen Backend Pod**
6. **[Logs] Button klicken**

### Backend Logs anschauen:
```
  .   ____          _            __ _ _
 /\\ / ___'_ __ _ _(_)_ __  __ _ \ \ \ \
( ( )\___ | '_ | '_| | '_ \/ _` | \ \ \ \
 \\/  ___)| |_)| | | | | || (_| |  ) ) ) )
  '  |____| .__|_| |_|_| |_\__, | / / / /
 =========|_|==============|___/=/_/_/_/
 :: Spring Boot ::

Started TodoApplication in 12.345 seconds
Tomcat started on port(s): 8080 (http)
Connected to PostgreSQL Database
Connected to Redis Cache
Application is ready!
```

**✅ Checkpoint erfolgreich:** Backend läuft und connected zu RDS + Redis!

### Backend Logs nach Fehler suchen:
1. **In Lens Logs:** `[Search]` Button
2. **Suche nach:** `ERROR`
3. **Sollte leer sein** ✅

### Wenn Fehler:
```bash
# Häufige Fehler:

# 1. "Connection refused" (RDS)
→ RDS Endpoint falsch
→ Security Group nicht offen
→ RDS noch nicht ready

# 2. "Authentication failed" (RDS)
→ Passwort falsch im Secret

# 3. "Unknown host: redis-service"
→ Redis Service nicht deployed
→ kubectl get services prüfen
```

---

## 🎯 LENS CHECKPOINT 4: Redis Cache testen

### Backend erstellt automatisch Stats in Redis!

### In Lens:
1. **Workloads** → **Pods** → **Redis Pod**
2. **[Shell] Button klicken**
3. **Im Terminal:**

```bash
redis-cli

# Alle Keys anzeigen
KEYS *
# Output: (empty list or set) ← Noch keine Daten

# Stats-Key checken
GET todo:stats:todos_created
# Output: (nil) ← Noch keine Todos erstellt

# exit
exit
```

**Merke dir das - wir kommen gleich wieder zurück!**

---

## Phase 5: Frontend deployen (5 Min)

### Schritt 13: Frontend YAML anpassen

```bash
# Öffne: kubernetes/03-frontend.yaml

# ÄNDERN:
# 1. Docker Image
image: <YOUR_DOCKER_IMAGE>
# Ersetze mit: todo-frontend:v1.0 (lokal)
# Oder: <ACCOUNT_ID>.dkr.ecr.eu-north-1.amazonaws.com/todo-frontend:v1.0
```

### Schritt 14: Frontend deployen

```bash
# Frontend deployen
kubectl apply -f 03-frontend.yaml

# Output:
# deployment.apps/frontend created
# service/frontend-service created
```

### Schritt 15: Load Balancer URL holen

```bash
# Services anzeigen
kubectl get services

# Output:
# NAME               TYPE           EXTERNAL-IP      PORT(S)
# frontend-service   LoadBalancer   <pending>        80:30123/TCP
#                                   ↑ Dauert 2-3 Min!

# Warten bis EXTERNAL-IP erscheint (alle 10s prüfen)
kubectl get service frontend-service -w

# Nach 2-3 Min:
# frontend-service   LoadBalancer   abc123.elb.amazonaws.com   80:30123/TCP
#                                   ↑ DIESE URL!
```

---

## 🎯 LENS CHECKPOINT 5: Frontend in Lens und AWS Load Balancer

### In Lens:
1. **Workloads** → **Deployments**
2. **Siehst du:** `frontend`, `backend`, `redis` (alle Ready!) ✅

3. **Network** → **Services**
4. **Klick auf `frontend-service`**

### Service Details:
```
frontend-service (LoadBalancer)
├── Cluster IP: 10.100.50.10
├── External IP: abc123.eu-north-1.elb.amazonaws.com ← AWS Load Balancer!
├── Ports: 80 → 80
└── Endpoints:
    ├── 10.244.1.5:80 (frontend-xxx)
    └── 10.244.2.8:80 (frontend-yyy)
```

### App öffnen (in Lens!):
1. **[Open in Browser] Button** klicken 🔥
2. **Browser öffnet automatisch!**
3. **Du siehst die Todo App!** 🎉

**ODER manuell:**
```bash
# URL holen und öffnen
open http://$(kubectl get service frontend-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
```

---

## Phase 6: Die App nutzen & Redis beobachten! (10 Min)

### Schritt 16: Todos erstellen

**Im Browser:**
1. Todo erstellen: "Kubernetes lernen"
2. Todo erstellen: "Lens beherrschen"
3. Todo erstellen: "EKS Cluster managen"

### Schritt 17: Statistics anschauen

**Im Browser** (in der App):
```
Statistics Box:
├── Created: 3
├── Updated: 0
├── Deleted: 0
└── DB Reads: 1  ← Cache funktioniert!
```

---

## 🎯 LENS CHECKPOINT 6: Redis Cache LIVE sehen!

### In Lens:
1. **Workloads** → **Pods** → **Redis Pod**
2. **[Shell] Button**
3. **Im Terminal:**

```bash
redis-cli

# Alle Keys anzeigen
KEYS *
# Output:
# 1) "todo:stats:todos_created"
# 2) "todo:stats:db_reads"
# 3) "todos::all"  ← Cached Todos!

# Stats anschauen
GET todo:stats:todos_created
# Output: "3"  ✅

GET todo:stats:db_reads
# Output: "1"  ✅ (Nur 1x DB gelesen, danach Cache!)

# Cached Todos anschauen (ist Java Serialized Object)
GET todos::all
# Output: [Binary data...]

# TTL checken (wann läuft Cache ab?)
TTL todos::all
# Output: 287 (Sekunden bis Ablauf)

exit
```

**✅ DAS IST MEGA!** Du siehst LIVE wie Redis den Cache speichert!

---

## 🎯 LENS CHECKPOINT 7: Cache Invalidierung beobachten

### Test: Todo löschen → Cache wird geleert!

**Im Browser:**
1. Lösche ein Todo (🗑️ Button)

**In Lens → Redis Shell:**
```bash
redis-cli

# Cache ist WEG!
GET todos::all
# Output: (nil)  ← Cache wurde invalidiert! ✅

# Stats updated
GET todo:stats:todos_deleted
# Output: "1"  ✅

exit
```

**Im Browser:** Seite neu laden

**In Lens → Backend Logs:**
```bash
# [Logs] Button bei Backend Pod

# Du siehst:
📊 Fetching from DATABASE (not cached)  ← Cache Miss!
✅ Creating new Todo
```

**In Lens → Redis Shell:**
```bash
# Jetzt ist Cache wieder da!
redis-cli
GET todos::all
# Output: [Binary data...]  ← Neu gecached!
```

**✅ PERFEKT!** Du siehst wie Spring Boot Cache funktioniert:
- GET Request → Cache Hit (schnell)
- POST/PUT/DELETE → Cache Clear
- Nächster GET → Cache Miss → DB Read → Cache wieder füllen

---

## 🎯 LENS CHECKPOINT 8: Die komplette Architektur visualisieren

### In Lens Dashboard:
1. **Cluster Overview**

```
todo-app-cluster
├── Nodes: 2
│   ├── ip-192-168-1-100 (CPU: 25%, Memory: 600 MB)
│   └── ip-192-168-2-150 (CPU: 30%, Memory: 700 MB)
├── Deployments: 3
│   ├── frontend (2/2 Ready)
│   ├── backend (2/2 Ready)
│   └── redis (1/1 Ready)
├── Pods: 5 (alle Running)
└── Services: 3
    ├── frontend-service (LoadBalancer)
    ├── backend-service (ClusterIP)
    └── redis-service (ClusterIP)
```

### Pods auf Nodes verteilen sehen:
1. **Nodes** Tab
2. **Klick auf Node 1:**
   - frontend-xxx (Running)
   - backend-xxx (Running)
   - redis-xxx (Running)

3. **Klick auf Node 2:**
   - frontend-yyy (Running)
   - backend-yyy (Running)

**✅ Kubernetes verteilt automatisch die Pods auf beide Nodes!**

---

## Phase 7: Skalierung testen (5 Min)

### Schritt 18: Backend skalieren (in Lens!)

**In Lens:**
1. **Workloads** → **Deployments** → **backend**
2. **[Scale] Button** klicken
3. **Slider von 2 auf 5 ziehen**
4. **[Scale] bestätigen**

**Was du siehst:**
- LIVE neue Pods starten!
- Pending → ContainerCreating → Running
- Nach 30 Sekunden: 5/5 Ready ✅

### Schritt 19: Load testen

**Im Browser:** Mehrmals Todos erstellen/löschen

**In Lens → Backend Pods:**
- Alle 5 Pods teilen sich die Last!
- Logs bei verschiedenen Pods anschauen
- Jeder Pod bearbeitet Requests

### Schritt 20: Zurück skalieren

**In Lens:**
1. **backend** → **[Scale]**
2. **Slider auf 2**
3. **3 Pods werden terminated** (ordentlich, kein Force!)

---

## Phase 8: Monitoring (5 Min)

### Metrics Server installieren (für Live-Grafiken)

```bash
# Metrics Server deployen
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Warten bis ready (30 Sekunden)
kubectl get deployment metrics-server -n kube-system
```

### In Lens mit Metrics:
1. **Cluster Dashboard**
   - Jetzt siehst du **GRAFIKEN!** 📊
   - CPU Usage über Zeit
   - Memory Usage über Zeit

2. **Pods** Tab
   - Jeder Pod zeigt CPU/Memory

3. **Nodes** Tab
   - Node CPU/Memory in Echtzeit

**Jetzt kannst du alles monitoren!**

---

## Zusammenfassung: Was du gebaut hast

```
✅ EKS Cluster (2 Nodes, t3.small)
✅ RDS PostgreSQL Datenbank
✅ Redis Cache (1 Replica)
✅ Backend (Spring Boot, 2 Replicas)
✅ Frontend (Nginx, 2 Replicas)
✅ AWS Load Balancer (öffentlich)
✅ Lens für Visualisierung
✅ Live Logs, Shell-Zugriff
✅ Cache-Monitoring in Redis
✅ Skalierung auf Knopfdruck
```

---

## Aufräumen (WICHTIG für Kosten!)

```bash
# 1. Kubernetes Deployments löschen
kubectl delete -f 01-redis.yaml
kubectl delete -f 02-backend.yaml
kubectl delete -f 03-frontend.yaml

# 2. Cluster löschen (dauert ~10 Min)
eksctl delete cluster -f cluster-config.yaml

# 3. RDS löschen (siehe 00-rds-setup.md)
aws rds delete-db-instance \
  --db-instance-identifier todo-app-db \
  --skip-final-snapshot \
  --region eu-north-1
```

---

## Troubleshooting

### Problem: Pods sind "Pending"
```bash
# Gründe:
kubectl describe pod <pod-name>

# Häufig:
# - Nicht genug CPU/Memory auf Nodes
# - Image Pull Error (ECR Login?)
# - Node Selector passt nicht
```

### Problem: Backend kann RDS nicht erreichen
```bash
# Prüfen:
kubectl logs <backend-pod>

# Häufig:
# - RDS Endpoint falsch
# - Security Group nicht offen
# - Passwort falsch
```

### Problem: Frontend zeigt "Backend OFFLINE"
```bash
# Prüfen:
kubectl get services

# backend-service muss existieren!
# Nginx Proxy muss auf backend-service:8080 zeigen
```

---

**Viel Erfolg! 🚀**
