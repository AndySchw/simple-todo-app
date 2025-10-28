# Simple Todo App - Kubernetes Full Stack

Eine vollständige Full-Stack Anwendung auf AWS EKS mit Lens-Visualisierung.

## Was ist das?

Eine **einfache aber vollständige** Todo-Anwendung, die alle wichtigen Kubernetes- und Cloud-Konzepte zeigt:

```
Frontend (HTML/CSS/JS) → Backend (Spring Boot) → Cache (Redis) → Database (RDS PostgreSQL)
        ↓                        ↓                    ↓                  ↓
     Nginx                    Java 17            In-Memory          AWS RDS
  LoadBalancer              REST API            Key-Value         Managed DB
   2 Replicas              2 Replicas           1 Replica        Free Tier
```

## Technologie-Stack

### Frontend
- **HTML/CSS/JavaScript** (Vanilla, kein Framework)
- **Nginx** als Webserver
- Bootstrap-ähnliches Design
- Live Statistics Dashboard

### Backend
- **Java 17** mit **Spring Boot 3.2**
- **Spring Data JPA** für Datenbank
- **Spring Data Redis** für Cache
- REST API mit CORS-Support
- Automatische Cache-Invalidierung

### Infrastructure
- **EKS (Elastic Kubernetes Service)** - Managed Kubernetes
- **RDS PostgreSQL** - Managed Database
- **Redis** - In-Memory Cache
- **AWS Load Balancer** - Traffic Distribution
- **Lens** - Kubernetes IDE für Visualisierung

## Features

### Funktional
- ✅ Todos erstellen, bearbeiten, löschen
- ✅ Todos als erledigt markieren
- ✅ Live-Statistiken (Created, Updated, Deleted, DB Reads)
- ✅ Cache-Monitoring in Echtzeit

### Technisch
- ✅ **Redis Caching** mit automatischer Invalidierung
- ✅ **Health Checks** für alle Services
- ✅ **Resource Limits** (CPU/Memory)
- ✅ **Horizontal Scaling** (einfach skalierbar)
- ✅ **Service Discovery** (Kubernetes DNS)
- ✅ **Load Balancing** (AWS ELB)
- ✅ **Secrets Management** (Kubernetes Secrets)

## Projektstruktur

```
simple-todo-app/
├── backend/                      # Spring Boot Backend
│   ├── src/main/java/com/cloudhelden/todo/
│   │   ├── TodoApplication.java         # Main Application
│   │   ├── model/Todo.java              # Entity
│   │   ├── repository/TodoRepository.java
│   │   ├── service/TodoService.java     # Business Logic + Cache
│   │   └── controller/TodoController.java # REST API
│   ├── src/main/resources/
│   │   └── application.properties        # Configuration
│   ├── pom.xml                           # Maven Dependencies
│   └── Dockerfile                        # Multi-Stage Build
│
├── frontend/                     # HTML/CSS/JS Frontend
│   ├── index.html                        # Main Page
│   ├── styles.css                        # CSS Styling
│   ├── app.js                            # JavaScript Logic
│   ├── nginx.conf                        # Nginx Configuration
│   └── Dockerfile                        # Nginx Alpine
│
├── kubernetes/                   # Kubernetes Manifests
│   ├── cluster-config.yaml               # EKS Cluster (eksctl)
│   ├── 01-redis.yaml                     # Redis Deployment + Service
│   ├── 02-backend.yaml                   # Backend Deployment + Service + Secret
│   └── 03-frontend.yaml                  # Frontend Deployment + LoadBalancer
│
└── docs/                         # Anleitungen
    ├── 00-rds-setup.md                   # RDS Datenbank erstellen
    └── 01-deployment-guide.md            # Komplette Deployment-Anleitung
```

## Schnellstart

### Voraussetzungen
```bash
# Installiert haben:
- Docker
- kubectl
- eksctl
- AWS CLI (konfiguriert)
- Lens (optional aber empfohlen)
```

### 1. RDS Datenbank erstellen
```bash
# Siehe: docs/00-rds-setup.md
aws rds create-db-instance ...
```

### 2. EKS Cluster erstellen
```bash
cd kubernetes/
eksctl create cluster -f cluster-config.yaml
# Dauert 15-20 Minuten
```

### 3. Docker Images bauen
```bash
cd backend/
docker build -t todo-backend:v1.0 .

cd ../frontend/
docker build -t todo-frontend:v1.0 .
```

### 4. Deployments anwenden
```bash
cd ../kubernetes/

# Redis
kubectl apply -f 01-redis.yaml

# Backend (YAML vorher anpassen!)
kubectl apply -f 02-backend.yaml

# Frontend (YAML vorher anpassen!)
kubectl apply -f 03-frontend.yaml
```

### 5. App öffnen
```bash
# Load Balancer URL holen
kubectl get service frontend-service

# Browser öffnen
open http://<LOAD_BALANCER_URL>
```

## Lens Integration

### Lens öffnen
```bash
open -a Lens
```

### Was du in Lens siehst:
- 📊 **Dashboard** - Cluster Overview, Metrics
- 🖥️ **Nodes** - Worker Nodes mit Labels
- 📦 **Pods** - Alle Pods mit Status
- 🚀 **Deployments** - Scale, Restart, Edit
- 🌐 **Services** - Load Balancer URLs
- 📋 **Logs** - Live Logs mit Search
- 💻 **Shell** - Terminal in Pods

### Redis Cache live beobachten:
1. Lens → Pods → Redis Pod
2. [Shell] Button
3. `redis-cli`
4. `KEYS *` → Siehst du Cache-Keys!
5. `GET todo:stats:todos_created` → Statistiken!

## Architektur-Highlights

### 1. Spring Boot Caching
```java
@Cacheable(value = "todos", key = "'all'")
public List<Todo> getAllTodos() {
    // Wird nur bei Cache-Miss aufgerufen!
}

@CacheEvict(value = "todos", allEntries = true)
public Todo createTodo(Todo todo) {
    // Leert Cache automatisch!
}
```

### 2. Redis Statistics
```java
private void incrementStat(String statName) {
    redisTemplate.opsForValue().increment("todo:stats:" + statName);
}
```

### 3. Kubernetes Service Discovery
```yaml
# Backend findet Redis automatisch via DNS:
spring.data.redis.host=redis-service  # ← Kubernetes DNS!
```

### 4. Nginx Reverse Proxy
```nginx
location /api/ {
    proxy_pass http://backend-service:8080;  # ← Kubernetes Service!
}
```

## Monitoring

### Mit kubectl:
```bash
# Pods
kubectl get pods -o wide

# Logs
kubectl logs -f <pod-name>

# Resource Usage
kubectl top pods
kubectl top nodes
```

### Mit Lens:
- Live Logs mit Search
- Shell-Zugriff auf Pods
- Resource-Grafiken (CPU/Memory)
- Scale per Slider
- Deployment Rollout History

## Skalierung

### Horizontal (mehr Pods):
```bash
# Via kubectl
kubectl scale deployment backend --replicas=5

# Via Lens
Deployments → backend → [Scale] → Slider auf 5
```

### Vertikal (größere Nodes):
```yaml
# cluster-config.yaml ändern
instanceType: t3.medium  # statt t3.small
desiredCapacity: 3       # statt 2

# Cluster updaten
eksctl scale nodegroup --cluster todo-app-cluster \
  --name app-workers --nodes 3
```

## Kosten (EU-North-1)

**Entwicklung (minimal):**
- EKS Control Plane: 73€/Monat
- 2x t3.small Nodes: 30€/Monat
- RDS db.t3.micro: 15€/Monat
- Storage (30 GB): 3€/Monat
- **Total: ~121€/Monat**

**Free Tier (erste 12 Monate):**
- RDS db.t3.micro: KOSTENLOS
- 750h EC2 (teilweise)
- **Total: ~100€/Monat**

**Aufräumen nach Testing:**
- Alles löschen → 0€!

## Aufräumen

```bash
# 1. Deployments löschen
kubectl delete -f 01-redis.yaml
kubectl delete -f 02-backend.yaml
kubectl delete -f 03-frontend.yaml

# 2. Cluster löschen
eksctl delete cluster -f cluster-config.yaml

# 3. RDS löschen
aws rds delete-db-instance \
  --db-instance-identifier todo-app-db \
  --skip-final-snapshot
```

## Troubleshooting

### Backend startet nicht
```bash
# Logs prüfen
kubectl logs <backend-pod>

# Häufige Fehler:
# - RDS Connection refused → Security Group öffnen
# - Authentication failed → Passwort im Secret prüfen
# - Redis not found → redis-service deployed?
```

### Frontend zeigt "Backend OFFLINE"
```bash
# Backend Service prüfen
kubectl get service backend-service

# Backend Pods prüfen
kubectl get pods -l app=backend
```

### Pods bleiben "Pending"
```bash
# Events anschauen
kubectl describe pod <pod-name>

# Häufig:
# - Nicht genug Ressourcen auf Nodes
# - Image Pull Error
```

## Weiterführende Links

- [eksctl Documentation](https://eksctl.io/)
- [Spring Boot Documentation](https://spring.io/projects/spring-boot)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Lens Documentation](https://docs.k8slens.dev/)
- [Redis Commands](https://redis.io/commands/)

## Lizenz

MIT License - Frei verwendbar für Training und Education.

---

**Viel Erfolg beim Lernen! 🚀**
