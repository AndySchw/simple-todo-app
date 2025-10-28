# RDS PostgreSQL Datenbank erstellen

**WICHTIG:** Erstelle ZUERST den EKS Cluster, DANN die RDS in derselben VPC!

```
Richtige Reihenfolge:
1. EKS Cluster erstellen → VPC wird automatisch erstellt
2. VPC ID vom Cluster holen
3. RDS in DIESER VPC erstellen
4. Backend kann RDS erreichen ✅
```

---

## Option 1: AWS Console (Einfach, aber VPC manuell auswählen)

### Voraussetzung: EKS Cluster VPC kennen

```bash
# 1. EKS Cluster muss bereits laufen!
kubectl get nodes  # Sollte 2 Nodes zeigen

# 2. VPC ID holen
aws eks describe-cluster \
  --name todo-app-cluster \
  --region eu-north-1 \
  --query 'cluster.resourcesVpcConfig.vpcId' \
  --output text

# Output: vpc-abc123def456  ← Diese ID brauchst du!
```

### Schritt 1: RDS öffnen
1. AWS Console öffnen
2. Services → RDS
3. "Create database" klicken

### Schritt 2: Engine wählen
- **Engine type:** PostgreSQL
- **Version:** PostgreSQL 15.x (neueste)
- **Templates:** Free tier (für Testing) ODER Dev/Test

### Schritt 3: Settings
```
DB instance identifier: todo-app-db
Master username: postgres
Master password: YourSecurePassword123!  (WICHTIG: Merken!)
```

### Schritt 4: Instance Configuration
**Free Tier:**
- DB instance class: db.t3.micro

**Für Production/Training:**
- DB instance class: db.t3.small

### Schritt 5: Storage
- Storage type: General Purpose (SSD)
- Allocated storage: 20 GB
- Enable storage autoscaling: ✓

### Schritt 6: Connectivity
**WICHTIG für EKS Zugriff:**
- VPC: **WÄHLE DIE EKS VPC!** (vpc-abc123def456)
  - Im Dropdown nach der VPC ID suchen
  - ODER nach "eksctl-todo-app-cluster" suchen
- Public access: **Yes** (für einfachen Zugriff, in Production besser No)
- VPC security group: Create new
  - Name: `todo-app-db-sg`

**Wenn du die falsche VPC wählst → Backend kann RDS nicht erreichen!** ⚠️

### Schritt 7: Database Authentication
- Password authentication

### Schritt 8: Additional Configuration
```
Initial database name: tododb  (WICHTIG!)
Backup retention: 7 days
Monitoring: Disable Enhanced Monitoring (spart Kosten)
```

### Schritt 9: Create Database
- Klick auf "Create database"
- **Dauert ca. 5-10 Minuten** ☕

---

## Option 2: AWS CLI (Empfohlen - automatisch richtige VPC!)

### Schritt 1: VPC ID von EKS Cluster holen


# ################################################################
**Voraussetzung: EKS Cluster muss bereits laufen!**
```bash
# VPC ID des EKS Clusters finden
export CLUSTER_NAME="todo-app-cluster"
export VPC_ID=$(aws eks describe-cluster \
  --name $CLUSTER_NAME \
  --region eu-north-1 \
  --query 'cluster.resourcesVpcConfig.vpcId' \
  --output text)

echo "VPC ID: $VPC_ID"
```

########## VPC ID: vpc-04ac7d12cee96d5d9  ##########

### Schritt 2: Security Group erstellen
```bash
# Security Group für RDS erstellen
export SG_ID=$(aws ec2 create-security-group \
  --group-name todo-app-db-sg \
  --description "Security group for Todo App RDS" \
  --vpc-id $VPC_ID \
  --region eu-north-1 \
  --output text)

echo "Security Group ID: $SG_ID"



# PostgreSQL Port (5432) öffnen für alle IPs in VPC
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 5432 \
  --cidr 172.31.0.0/16 \
  --region eu-north-1
```

############# Security Group ID: sg-0afce072db758f08e ######

### Schritt 3: Subnet Group erstellen
```bash
# Alle Subnets der VPC holen
# Als Array holen
  SUBNET_IDS=($(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --region eu-north-1 \
    --query 'Subnets[*].SubnetId' \
    --output text))

echo "Subnet IDs: $SUBNET_IDS"

# DB Subnet Group erstellen
aws rds create-db-subnet-group \
  --db-subnet-group-name todo-app-subnet-group \
  --db-subnet-group-description "Subnet group for Todo App" \
  --subnet-ids $SUBNET_IDS \
  --region eu-north-1
```

### Schritt 4: RDS Instance erstellen
```bash
# RDS PostgreSQL Instance erstellen
aws rds create-db-instance \
  --db-instance-identifier todo-app-db \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --master-username postgres \
  --master-user-password YourSecurePassword123! \
  --allocated-storage 20 \
  --db-subnet-group-name todo-app-subnet-group \
  --vpc-security-group-ids $SG_ID \
  --db-name tododb \
  --backup-retention-period 7 \
  --no-multi-az \
  --publicly-accessible \
  --region eu-north-1

echo "✅ RDS Instance wird erstellt... (dauert 5-10 Min)"
```

### Schritt 5: Warten bis RDS verfügbar ist
```bash
# Status prüfen
aws rds describe-db-instances \
  --db-instance-identifier todo-app-db \
  --region eu-north-1 \
  --query 'DBInstances[0].DBInstanceStatus' \
  --output text

# Warten bis "available"
aws rds wait db-instance-available \
  --db-instance-identifier todo-app-db \
  --region eu-north-1

echo "✅ RDS Instance ist bereit!"
```

---

## Schritt 3: RDS Endpoint holen

### Via AWS Console:
1. RDS → Databases → `todo-app-db`
2. **Endpoint** kopieren (z.B. `todo-app-db.abc123.eu-north-1.rds.amazonaws.com`)

### Via AWS CLI:
```bash
# Endpoint holen
export RDS_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier todo-app-db \
  --region eu-north-1 \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)

echo "RDS Endpoint: $RDS_ENDPOINT"

# Speichern für später
echo $RDS_ENDPOINT > rds-endpoint.txt
```

---

## Schritt 4: RDS Verbindung testen

### Von lokalem Computer (wenn Public Access aktiviert):
```bash
# PostgreSQL Client installieren (Mac)
brew install postgresql

# Verbindung testen
psql -h $RDS_ENDPOINT \
     -U postgres \
     -d tododb \
     -p 5432

# Passwort eingeben: YourSecurePassword123!

# Im psql:
\dt  # Tabellen anzeigen (noch leer)
\q   # Beenden
```

### Oder via Docker:
```bash
docker run -it --rm postgres:15 psql \
  -h $RDS_ENDPOINT \
  -U postgres \
  -d tododb
```

---

## Schritt 5: Endpoint in Kubernetes Config eintragen

Öffne: `kubernetes/02-backend.yaml`

```yaml
env:
  - name: DB_HOST
    value: "todo-app-db.abc123.eu-north-1.rds.amazonaws.com"  # ← Dein Endpoint
  - name: DB_PORT
    value: "5432"
  - name: DB_NAME
    value: "tododb"
  - name: DB_USER
    value: "postgres"
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: db-secret
        key: password
```

---

## Troubleshooting

### Problem: Backend kann RDS nicht erreichen

**Lösung 1: Security Group prüfen**
```bash
# Security Group Rules anzeigen
aws ec2 describe-security-groups \
  --group-ids $SG_ID \
  --region eu-north-1

# Falls Port 5432 nicht offen: öffnen
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 5432 \
  --cidr 0.0.0.0/0 \
  --region eu-north-1
```

**Lösung 2: VPC prüfen**
- RDS und EKS müssen in DERSELBEN VPC sein!

**Lösung 3: Public Access aktivieren**
```bash
aws rds modify-db-instance \
  --db-instance-identifier todo-app-db \
  --publicly-accessible \
  --apply-immediately \
  --region eu-north-1
```

---

## Kosten

**db.t3.micro (Free Tier - 12 Monate):**
- KOSTENLOS (750 Stunden/Monat)

**db.t3.micro (nach Free Tier):**
- ca. 15€/Monat

**db.t3.small:**
- ca. 30€/Monat

**Storage:**
- 20 GB SSD: ca. 2,50€/Monat

---

## Aufräumen (Wichtig!)

### Via Console:
1. RDS → Databases → `todo-app-db`
2. Actions → Delete
3. ❌ Create final snapshot? → NEIN
4. ✓ I acknowledge...
5. Type "delete me"
6. Delete

### Via CLI:
```bash
# RDS Instance löschen (OHNE Final Snapshot)
aws rds delete-db-instance \
  --db-instance-identifier todo-app-db \
  --skip-final-snapshot \
  --region eu-north-1

# DB Subnet Group löschen (nach ~10 Min wenn RDS gelöscht)
aws rds delete-db-subnet-group \
  --db-subnet-group-name todo-app-subnet-group \
  --region eu-north-1

# Security Group löschen
aws ec2 delete-security-group \
  --group-id $SG_ID \
  --region eu-north-1
```

---

**Weiter mit:** `01-deployment-guide.md`
