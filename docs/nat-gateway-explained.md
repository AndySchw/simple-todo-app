# NAT Gateway - Warum & Wie?

## Die Frage: Warum wird ein NAT Gateway gebaut?

### Das Problem verstehen

```
┌─────────────────────────────────────────────────┐
│ VPC                                             │
│                                                 │
│  ┌──────────────┐        ┌──────────────┐      │
│  │Public Subnet │        │Private Subnet│      │
│  │              │        │              │      │
│  │ Load Balancer│        │ Backend Pods │      │
│  │ (öffentlich) │        │ (privat)     │      │
│  │              │        │              │      │
│  │ Öffentliche  │        │ Private IPs  │      │
│  │ IP: 3.x.x.x  │        │ 192.168.1.5  │      │
│  └──────────────┘        └──────┬───────┘      │
│         ↑                       │              │
│         │                       │              │
│    [Internet Gateway]           │              │
│         ↑                       │              │
└─────────┼───────────────────────┼──────────────┘
          │                       │
          │                       ↓
       Internet          ❌ Backend braucht Internet!
                            (ECR, Updates, AWS APIs)
                            Aber hat keine öffentliche IP!
```

**Backend Pod braucht Internet für:**
1. **Docker Images pullen** - Von ECR (123456.dkr.ecr...)
2. **AWS API Calls** - RDS verbinden, Secrets holen
3. **Updates/Packages** - apt-get, yum, etc.

**Aber:** Backend sollte NICHT direkt im Internet erreichbar sein! (Sicherheit)

---

## Die Lösung: NAT Gateway

```
┌─────────────────────────────────────────────────────────────┐
│ VPC                                                         │
│                                                             │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐ │
│  │Public Subnet │    │NAT Gateway   │    │Private Subnet│ │
│  │              │    │              │    │              │ │
│  │Load Balancer │    │Übersetzt     │    │Backend Pods  │ │
│  │              │    │Private→Public│←───│              │ │
│  │              │    │              │    │192.168.1.5   │ │
│  │Öffentliche IP│    │Öffentliche IP│    │(privat)      │ │
│  └──────────────┘    └──────┬───────┘    └──────────────┘ │
│         ↑                   │                              │
│         │                   │                              │
│    [Internet Gateway]───────┘                              │
│         ↑                                                  │
└─────────┼──────────────────────────────────────────────────┘
          │
       Internet
```

**So funktioniert's:**
```
1. Backend Pod (192.168.1.5) will ECR erreichen
   → "Ich will 123.dkr.ecr.eu-north-1.amazonaws.com"

2. Route Table schickt Traffic zu NAT Gateway
   → "Okay, ich leite dich zum NAT weiter"

3. NAT Gateway übersetzt:
   → Source IP: 192.168.1.5 (privat) → 3.15.123.45 (öffentlich)
   → Schickt Request über Internet Gateway

4. ECR antwortet an 3.15.123.45

5. NAT Gateway übersetzt zurück:
   → Destination: 3.15.123.45 → 192.168.1.5
   → Backend bekommt Docker Image ✅
```

---

## Wo wird NAT Gateway konfiguriert?

### In eksctl: AUTOMATISCH (Standard)

```yaml
# cluster-config.yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: todo-app-cluster
  region: eu-north-1

# KEIN vpc-Block → eksctl erstellt automatisch:
# - VPC mit Public + Private Subnets
# - Internet Gateway
# - NAT Gateway (1 pro AZ)
# - Route Tables
```

**eksctl Default-Verhalten:**
```
VPC erstellt:
├── 3 Public Subnets (je AZ)
│   └── Internet Gateway Route
├── 3 Private Subnets (je AZ)
│   └── NAT Gateway Route
├── 3 NAT Gateways (je 1 pro AZ)  ← HIER!
└── Route Tables (automatisch)
```

---

## Explizite VPC-Konfiguration (wenn du Kontrolle willst)

### Option 1: NAT Gateway aktiviert (Standard)

```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: todo-app-cluster
  region: eu-north-1

# Explizite VPC Config
vpc:
  cidr: 192.168.0.0/16
  nat:
    gateway: HighlyAvailable  # ← 1 NAT Gateway pro AZ (3x)
    # ODER:
    # gateway: Single         # ← Nur 1 NAT Gateway (günstiger, kein HA)
    # ODER:
    # gateway: Disable        # ← KEIN NAT Gateway (nur für spezielle Fälle)

  subnets:
    public:
      eu-north-1a:
        cidr: 192.168.0.0/19
      eu-north-1b:
        cidr: 192.168.32.0/19
      eu-north-1c:
        cidr: 192.168.64.0/19
    private:
      eu-north-1a:
        cidr: 192.168.96.0/19
      eu-north-1b:
        cidr: 192.168.128.0/19
      eu-north-1c:
        cidr: 192.168.160.0/19
```

### Option 2: Single NAT Gateway (Kosten sparen)

```yaml
vpc:
  nat:
    gateway: Single  # ← Nur 1 NAT Gateway (günstiger)
    # Nachteil: Wenn die AZ ausfällt → Kein Internet für Private Subnets
```

### Option 3: NAT Gateway deaktivieren (nur für spezielle Fälle)

```yaml
vpc:
  nat:
    gateway: Disable  # ← KEIN NAT Gateway

# Nur für:
# - Komplett isolierte Cluster (kein Internet)
# - Eigene NAT-Lösung (z.B. NAT Instances)
# - Testing ohne Internet
```

---

## NAT Gateway Kosten

### Pricing (eu-north-1):

**NAT Gateway:**
- **Pro Stunde:** 0,048€
- **Pro Monat:** ~35€

**Datenübertragung:**
- **Pro GB processed:** 0,048€

**Beispiel-Rechnung:**
```
Szenario: Todo App (Development)

NAT Gateway:
1 Gateway × 0,048€/h × 730h = 35€/Monat

Datenübertragung:
- Docker Images: 5 GB/Tag = 150 GB/Monat
- AWS API Calls: 10 GB/Monat
- Updates: 5 GB/Monat
Total: 165 GB × 0,048€ = 8€/Monat

TOTAL: ~43€/Monat
```

**Bei 3x NAT Gateways (HighlyAvailable):**
```
3 × 35€ = 105€/Monat (nur NAT Gateways!)
+ Daten = ~113€/Monat
```

---

## Alternativen zum NAT Gateway

### Alternative 1: NAT Instance (günstiger, selbst verwaltet)

```yaml
vpc:
  nat:
    gateway: Disable

# Dann manuell:
# - EC2 t3.micro als NAT Instance starten
# - Routing konfigurieren
# - Selbst verwalten & patchen

# Kosten: ~8€/Monat (t3.micro)
# Nachteil: Selbst verwalten, weniger Performance
```

### Alternative 2: Public Nodes (NICHT empfohlen!)

```yaml
nodeGroups:
  - name: workers
    privateNetworking: false  # ← Nodes bekommen öffentliche IPs
    # KEIN NAT Gateway nötig

# ❌ NACHTEIL: Nodes sind direkt aus dem Internet erreichbar!
# ❌ SICHERHEITSRISIKO!
```

### Alternative 3: VPC Endpoints (für AWS Services)

```yaml
# Für spezifische AWS Services OHNE NAT Gateway
vpc:
  cidr: 192.168.0.0/16
  nat:
    gateway: Single  # Weniger NAT Traffic

# Dann VPC Endpoints für:
# - ECR (Docker Images)
# - S3 (Artifacts)
# - CloudWatch (Logs)

# Kosten: ~10€/Monat pro Endpoint
# Vorteil: Kein Internet-Traffic, schneller
```

---

## Wann brauchst du KEIN NAT Gateway?

### Szenario 1: Alle Nodes im Public Subnet

```yaml
nodeGroups:
  - name: workers
    privateNetworking: false  # Öffentliche IPs
    # Nodes können direkt ins Internet
    # KEIN NAT Gateway nötig
    # ❌ Aber: Sicherheitsrisiko!
```

### Szenario 2: Komplett isolierter Cluster

```yaml
# Cluster ohne Internet-Zugriff
# - Alle Images von privatem Registry
# - Kein AWS API Zugriff nötig
# - Keine Updates
vpc:
  nat:
    gateway: Disable
```

### Szenario 3: VPC Endpoints für alles

```yaml
# VPC Endpoints für:
# - ECR (Images)
# - S3 (Artifacts)
# - RDS (Database)
# - CloudWatch (Logs)
# = Kein Internet nötig
```

---

## NAT Gateway in Action sehen

### Nach Cluster-Erstellung:

```bash
# 1. VPC ID holen
export VPC_ID=$(aws eks describe-cluster \
  --name todo-app-cluster \
  --region eu-north-1 \
  --query 'cluster.resourcesVpcConfig.vpcId' \
  --output text)

# 2. NAT Gateways anzeigen
aws ec2 describe-nat-gateways \
  --filter "Name=vpc-id,Values=$VPC_ID" \
  --region eu-north-1 \
  --query 'NatGateways[*].[NatGatewayId,State,SubnetId]' \
  --output table

# Output:
# ------------------------------------------------------------
# |              DescribeNatGateways                        |
# +----------------------+-----------+----------------------+
# |  nat-abc123def456    |  available|  subnet-public-1a   |
# |  nat-ghi789jkl012    |  available|  subnet-public-1b   |
# |  nat-mno345pqr678    |  available|  subnet-public-1c   |
# +----------------------+-----------+----------------------+
```

### Route Tables prüfen:

```bash
# Private Subnet Route Table
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'RouteTables[?Tags[?Key==`aws:cloudformation:logical-id` && contains(Value,`PrivateRouteTable`)]].[RouteTableId,Routes[0].NatGatewayId]' \
  --output table

# Zeigt: Welche Route Table nutzt welches NAT Gateway
```

---

## Empfehlung für Todo App

### Development/Training:

```yaml
# Option A: Single NAT Gateway (günstig)
vpc:
  nat:
    gateway: Single  # ~35€/Monat

# ODER Option B: Default (eksctl entscheidet)
# Kein vpc-Block → eksctl nutzt HighlyAvailable
```

### Production:

```yaml
# HighlyAvailable (3x NAT Gateway)
vpc:
  nat:
    gateway: HighlyAvailable  # ~105€/Monat
    # Aber: High Availability, kein Single Point of Failure
```

---

## Zusammenfassung

**Warum NAT Gateway?**
- Private Pods brauchen Internet (ECR, AWS APIs)
- Aber sollen nicht direkt erreichbar sein
- NAT Gateway = Sicherer Ausgang

**Wo sehe ich die Config?**
- **Implizit:** Kein `vpc`-Block → eksctl macht es automatisch
- **Explizit:** `vpc.nat.gateway` im YAML

**Wann wird es gebaut?**
- Automatisch bei `eksctl create cluster`
- Wenn Private Subnets existieren

**Kosten:**
- Single: ~35€/Monat
- HighlyAvailable (3x): ~105€/Monat

**Alternative für Training:**
```yaml
# Einfach & günstig:
nodeGroups:
  - name: workers
    privateNetworking: false  # Öffentliche IPs
    # Kein NAT Gateway nötig
    # ⚠️ Aber: Weniger sicher!
```

---

**Für dein Training:** Nutze entweder Single NAT Gateway oder public Nodes!
