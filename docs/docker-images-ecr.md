# Docker Images zu AWS ECR hochladen

## Das Problem verstehen

```
┌─────────────────────────────────────────────────────────────┐
│ Dein Computer (lokal)                                       │
│                                                             │
│  docker build -t todo-backend:v1.0 .                       │
│  → Image ist NUR lokal gespeichert                         │
│                                                             │
│  kubectl apply -f backend.yaml                             │
│  → Sagt EKS: "Starte Image: todo-backend:v1.0"            │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│ EKS Cluster (AWS Cloud)                                     │
│                                                             │
│  Node 1 (EC2):                                              │
│  → docker pull todo-backend:v1.0                           │
│  → ❌ ERROR: Image not found!                              │
│                                                             │
│  Warum? Das Image ist nur auf deinem Computer!             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Die Nodes brauchen eine Registry (Bildarchiv im Internet):**

```
Dein Computer → [ECR (AWS)] ← EKS Nodes
    Upload          Image        Download
                   Registry
```

---

## Option 1: AWS ECR (Empfohlen für EKS)

### Schritt 1: ECR Repositories erstellen

```bash
# Repository für Backend erstellen
aws ecr create-repository \
  --repository-name todo-backend \
  --region eu-north-1

# Output:
# {
#   "repository": {
#     "repositoryUri": "123456789.dkr.ecr.eu-north-1.amazonaws.com/todo-backend"
#   }
# }

# Repository für Frontend erstellen
aws ecr create-repository \
  --repository-name todo-frontend \
  --region eu-north-1
```

**Speichere die URIs:**
```bash
export BACKEND_REPO="123456789.dkr.ecr.eu-north-1.amazonaws.com/todo-backend"
export FRONTEND_REPO="123456789.dkr.ecr.eu-north-1.amazonaws.com/todo-frontend"

echo $BACKEND_REPO
echo $FRONTEND_REPO
```

### Schritt 2: Docker Login zu ECR

```bash
# Login zu ECR
aws ecr get-login-password --region eu-north-1 | \
  docker login --username AWS --password-stdin \
  DEINE_ACCOUNTID.dkr.ecr.eu-north-1.amazonaws.com

# Output:
# Login Succeeded ✅
```

**Was passiert?**
- AWS CLI holt temporäres Passwort
- Docker logged sich in ECR ein
- Token ist 12 Stunden gültig

### Schritt 3: Images bauen (falls noch nicht geschehen)

```bash
# Backend bauen
cd backend/
docker build -t todo-backend:v1.0 .

# Frontend bauen
cd ../frontend/
docker build -t todo-frontend:v1.0 .
```

### Schritt 4: Images taggen für ECR

```bash
# Backend taggen
docker tag todo-backend:v1.0 \
  $BACKEND_REPO:v1.0

# Frontend taggen
docker tag todo-frontend:v1.0 \
  $FRONTEND_REPO:v1.0

# Prüfen
docker images | grep todo
```

**Was passiert?**
```
Vorher:
todo-backend:v1.0  (nur lokal, kein Registry-Name)

Nachher:
todo-backend:v1.0  (lokal, ursprünglicher Name)
123456789.dkr.ecr.eu-north-1.amazonaws.com/todo-backend:v1.0  (tagged für ECR)
                    ↑ Registry URL
```

### Schritt 5: Images zu ECR pushen

```bash
# Backend pushen
docker push $BACKEND_REPO:v1.0

# Output:
# The push refers to repository [123456789.dkr.ecr.eu-north-1.amazonaws.com/todo-backend]
# v1.0: digest: sha256:abc123... size: 1234
# ✅

# Frontend pushen
docker push $FRONTEND_REPO:v1.0

# Dauert je nach Internet 2-5 Minuten
```

**Was passiert?**
```
Dein Computer → ECR (AWS Cloud)

Layer 1: Uploading [==============>] 50 MB
Layer 2: Uploading [=========>     ] 30 MB
...
✅ Pushed!
```

### Schritt 6: Images in ECR prüfen

```bash
# Backend Images auflisten
aws ecr describe-images \
  --repository-name todo-backend \
  --region eu-north-1

# Frontend Images auflisten
aws ecr describe-images \
  --repository-name todo-frontend \
  --region eu-north-1
```

**Oder in AWS Console:**
1. ECR → Repositories
2. `todo-backend` → Du siehst: `v1.0` ✅
3. `todo-frontend` → Du siehst: `v1.0` ✅

### Schritt 7: Kubernetes YAMLs anpassen

**Öffne: `kubernetes/02-backend.yaml`**

```yaml
# VORHER (funktioniert NICHT auf EKS):
spec:
  containers:
    - name: backend
      image: todo-backend:v1.0  # ❌ Nur lokal!

# NACHHER (funktioniert auf EKS):
spec:
  containers:
    - name: backend
      image: 123456789.dkr.ecr.eu-north-1.amazonaws.com/todo-backend:v1.0  # ✅ ECR!
```

**Öffne: `kubernetes/03-frontend.yaml`**

```yaml
# NACHHER:
spec:
  containers:
    - name: frontend
      image: 123456789.dkr.ecr.eu-north-1.amazonaws.com/todo-frontend:v1.0
```

### Schritt 8: Deployen!

```bash
cd ../kubernetes/

# Jetzt funktioniert es!
kubectl apply -f 02-backend.yaml
kubectl apply -f 03-frontend.yaml

# Pods prüfen
kubectl get pods

# Output:
# NAME                        READY   STATUS    RESTARTS   AGE
# backend-xxx                 1/1     Running   0          30s  ✅
# frontend-yyy                1/1     Running   0          20s  ✅
```

---

## Option 2: Docker Hub (Alternative)

### Vorteil:
- Öffentlich kostenlos
- Keine AWS Account nötig
- Einfacher für Testing

### Nachteil:
- Images sind öffentlich (außer du zahlst)
- Langsamer als ECR (andere Region)

### Setup:

```bash
# 1. Docker Hub Account erstellen auf hub.docker.com

# 2. Docker Login
docker login
# Username: deinusername
# Password: ****

# 3. Images taggen
docker tag todo-backend:v1.0 deinusername/todo-backend:v1.0
docker tag todo-frontend:v1.0 deinusername/todo-frontend:v1.0

# 4. Pushen
docker push deinusername/todo-backend:v1.0
docker push deinusername/todo-frontend:v1.0

# 5. In YAML verwenden
image: deinusername/todo-backend:v1.0
```

---

## Workflow verstehen

### Kompletter Development-Zyklus:

```bash
# 1. Code ändern
vim backend/src/main/java/...

# 2. Lokales Image neu bauen
docker build -t todo-backend:v1.1 backend/

# 3. Image taggen für ECR
docker tag todo-backend:v1.1 $BACKEND_REPO:v1.1

# 4. Zu ECR pushen
docker push $BACKEND_REPO:v1.1

# 5. Kubernetes YAML updaten
# kubernetes/02-backend.yaml:
# image: 123456789...todo-backend:v1.1  ← Neue Version!

# 6. Deployment updaten
kubectl apply -f kubernetes/02-backend.yaml

# 7. Rollout beobachten
kubectl rollout status deployment/backend

# 8. In Lens anschauen
# → Pods → Neue Pods mit v1.1 starten!
```

---

## kubectl apply: Was passiert genau?

```bash
kubectl apply -f 02-backend.yaml
```

**Schritt-für-Schritt:**

```
1. kubectl liest YAML-Datei auf deinem Computer
   ↓
2. kubectl schickt YAML an EKS API Server (in AWS Cloud)
   ↓
3. EKS Kubernetes Scheduler analysiert:
   - "2 Replicas gewünscht"
   - "Image: 123...todo-backend:v1.0"
   - "Resources: 512Mi RAM, 250m CPU"
   ↓
4. Scheduler wählt Nodes aus:
   - Node 1: Genug Platz? Ja → 1 Pod
   - Node 2: Genug Platz? Ja → 1 Pod
   ↓
5. Kubelet auf Node 1:
   - "Ich soll todo-backend:v1.0 starten"
   - "Wo ist das Image?"
   - "Steht ECR URL → Pull von ECR!"
   - docker pull 123...todo-backend:v1.0
   ↓
6. Docker auf Node 1:
   - Connected zu ECR
   - Downloaded Image
   - Container gestartet ✅
```

**Das Image selbst wird NICHT von deinem Computer hochgeladen!**
- kubectl schickt nur die YAML-Beschreibung
- Die Nodes pullen das Image selbst von ECR

---

## ImagePullPolicy verstehen

```yaml
containers:
  - name: backend
    image: todo-backend:v1.0
    imagePullPolicy: Always  # ← Wichtig!
```

**Optionen:**

1. **Always** (Default bei latest-Tag):
   - Pod startet → Pull Image von Registry
   - Immer aktuellste Version
   - Langsamer (Network)

2. **IfNotPresent**:
   - Pod startet → Check: Image lokal da?
   - Ja → Nutze lokales Image
   - Nein → Pull von Registry
   - Schneller bei Restarts

3. **Never**:
   - Nutze NUR lokales Image
   - Wenn nicht da → ERROR
   - Nur für lokales Testing!

**Empfehlung:**
```yaml
image: 123...todo-backend:v1.0  # Mit Version-Tag
imagePullPolicy: IfNotPresent    # Schneller
```

---

## Häufige Fehler & Lösungen

### Fehler 1: ImagePullBackOff

```bash
kubectl get pods

# Output:
# NAME          READY   STATUS             RESTARTS   AGE
# backend-xxx   0/1     ImagePullBackOff   0          2m
```

**Grund:** Image nicht in Registry gefunden

**Lösung:**
```bash
# Image in ECR prüfen
aws ecr describe-images --repository-name todo-backend

# Falls nicht da: Pushen!
docker push $BACKEND_REPO:v1.0

# Pod neu starten
kubectl delete pod backend-xxx
# Neuer Pod wird automatisch erstellt
```

### Fehler 2: ErrImagePull

```bash
kubectl describe pod backend-xxx

# Events:
# Failed to pull image: unauthorized: authentication required
```

**Grund:** EKS kann nicht auf ECR zugreifen

**Lösung:**
```bash
# IAM Role für EKS Nodes prüfen
# Muss AmazonEC2ContainerRegistryReadOnly Policy haben

# eksctl macht das automatisch!
# Falls nicht: IAM Role manuell hinzufügen
```

### Fehler 3: "Image not found"

```bash
# Pod Events:
# Failed to pull image "todo-backend:v1.0": not found
```

**Grund:** YAML zeigt auf lokalen Namen statt ECR

**Lösung:**
```yaml
# Falsch:
image: todo-backend:v1.0

# Richtig:
image: 123456789.dkr.ecr.eu-north-1.amazonaws.com/todo-backend:v1.0
```

---

## Best Practices

### 1. Versions-Tags nutzen
```bash
# ❌ Schlecht (nicht nachvollziehbar)
docker build -t todo-backend:latest .

# ✅ Gut (nachvollziehbar)
docker build -t todo-backend:v1.0 .
docker build -t todo-backend:v1.1 .
docker build -t todo-backend:v2.0 .
```

### 2. Git Commit als Tag
```bash
# Aktueller Git Commit Hash
GIT_COMMIT=$(git rev-parse --short HEAD)

# Image mit Commit-Hash taggen
docker build -t todo-backend:${GIT_COMMIT} .
docker tag todo-backend:${GIT_COMMIT} $BACKEND_REPO:${GIT_COMMIT}
docker push $BACKEND_REPO:${GIT_COMMIT}

# In YAML:
image: 123...todo-backend:a3b4c5d  ← Git Commit
```

### 3. Multi-Tag Strategy
```bash
# Image mehrfach taggen
docker tag todo-backend:v1.0 $BACKEND_REPO:v1.0
docker tag todo-backend:v1.0 $BACKEND_REPO:latest

# Beide pushen
docker push $BACKEND_REPO:v1.0
docker push $BACKEND_REPO:latest

# Production: Nutze v1.0 (stabil)
# Development: Nutze latest (aktuell)
```

---

## Zusammenfassung

### Für EKS (Cloud):

```bash
# 1. Images lokal bauen
docker build -t todo-backend:v1.0 backend/

# 2. ECR Repository erstellen
aws ecr create-repository --repository-name todo-backend

# 3. ECR Login
aws ecr get-login-password | docker login ...

# 4. Image taggen für ECR
docker tag todo-backend:v1.0 123...ecr...todo-backend:v1.0

# 5. Zu ECR pushen
docker push 123...ecr...todo-backend:v1.0

# 6. YAML mit ECR URI
image: 123...ecr...todo-backend:v1.0

# 7. Deployen
kubectl apply -f backend.yaml
```

### Für lokales Testing (minikube):

```bash
# 1. Images lokal bauen
docker build -t todo-backend:v1.0 backend/

# 2. minikube Image laden
minikube image load todo-backend:v1.0

# 3. YAML mit lokalem Namen
image: todo-backend:v1.0
imagePullPolicy: Never  # ← Wichtig!

# 4. Deployen
kubectl apply -f backend.yaml
```

---

**Jetzt verstehst du, warum ECR nötig ist!** 🚀
