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
- GitHub Account (für CI/CD)
- Lens (optional aber empfohlen)
```

### Quick Start (5 Schritte)

```bash
# 1. Repository klonen/forken
git clone https://github.com/<USERNAME>/simple-todo-app.git
cd simple-todo-app

# 2. RDS erstellen (siehe docs/deployment-guide-complete.md)
aws rds create-db-instance --db-instance-identifier todo-app-db ...

# 3. EKS Cluster erstellen
eksctl create cluster -f kubernetes/cluster-config.yaml

# 4. RDS Security Group konfigurieren
aws ec2 authorize-security-group-ingress \
  --group-id <RDS-SG> --port 5432 --source-group <EKS-SG>

# 5. Deployen
kubectl apply -f kubernetes/
```

**Vollständige Anleitung:** [📖 Complete Deployment Guide](docs/deployment-guide-complete.md)

### Kritische Setup-Schritte

⚠️ **Wichtig:** Diese Schritte sind entscheidend für ein funktionierendes Deployment!

1. **RDS Security Group** muss Traffic von EKS erlauben
2. **Docker Images** müssen für AMD64 (nicht ARM64) gebaut werden
3. **GitHub Secrets** korrekt konfigurieren für CI/CD
4. **Kubernetes Manifests** anpassen (Image-URLs, RDS-Endpoint)

Siehe: [Complete Deployment Guide](docs/deployment-guide-complete.md) für Details.

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

**Siehe detaillierte Troubleshooting-Guides:**
- 📖 [Complete Deployment Guide](docs/deployment-guide-complete.md) - Vollständige Schritt-für-Schritt Anleitung
- 🔧 [Troubleshooting Guide](docs/TROUBLESHOOTING.md) - Häufige Probleme und Lösungen

### Schnelle Diagnose

```bash
# Pod Status prüfen
kubectl get pods --all-namespaces

# Pod Logs anzeigen
kubectl logs -l app=backend --tail=50

# Service Status
kubectl get services
```

### Häufigste Probleme

#### 1. Backend crasht: "exec format error"
**Ursache:** Image für falsche Architektur gebaut (ARM64 statt AMD64)
**Lösung:** Verwende GitHub Actions für AMD64-Builds (siehe [Deployment Guide](docs/deployment-guide-complete.md#teil-4-docker-images-bauen-und-zu-ecr-pushen))

#### 2. Backend kann RDS nicht erreichen
**Ursache:** RDS Security Group blockiert EKS
**Lösung:**
```bash
aws ec2 authorize-security-group-ingress \
  --group-id <RDS-SG> \
  --protocol tcp \
  --port 5432 \
  --source-group <EKS-SG> \
  --region eu-north-1
```

#### 3. GitHub Actions - 401 Unauthorized
**Ursache:** IAM User fehlen ECR-Permissions
**Lösung:**
```bash
aws iam attach-user-policy \
  --user-name <IAM-USER> \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser
```

**Vollständige Lösungen:** Siehe [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

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
