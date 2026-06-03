# 02. Active Directory Architecture

> Forests, domains, trusts, sites, replication, FSMO — the structural blueprint of AD.

---

## Forest, Tree, Domain — The Hierarchy

```mermaid
flowchart TD
    FOREST[Forest: contoso.com\nschema + security boundary]
    
    FOREST --> TREE1[Tree 1: contoso.com]
    FOREST --> TREE2[Tree 2: fabrikam.com]
    
    TREE1 --> D1[Domain: contoso.com]
    TREE1 --> D2[Domain: emea.contoso.com]
    TREE1 --> D3[Domain: apac.contoso.com]
    
    TREE2 --> D4[Domain: fabrikam.com]
    TREE2 --> D5[Domain: eu.fabrikam.com]
```

| Concept | Boundary |
|---|---|
| Forest | Security + schema |
| Tree | DNS namespace |
| Domain | Replication + admin |
| OU | Delegation + GPO |

**Rule**: A forest is the **ultimate security boundary** in AD. Cross-forest = trust required.

---

## Trusts

Trust = an authentication path between domains/forests.

### Trust Types

| Trust | Direction | Transitive | Use Case |
|---|---|---|---|
| **Parent-Child** | Two-way | Yes | Automatic within a tree |
| **Tree-Root** | Two-way | Yes | Between tree roots in a forest |
| **External** | One/Two-way | No | To a domain in another forest (legacy) |
| **Forest** | One/Two-way | Yes | Between two forests |
| **Realm** | One/Two-way | Configurable | To non-Windows Kerberos (MIT/Linux) |
| **Shortcut** | One/Two-way | Yes | Optimize auth path within forest |

### Trust Flow Example
```mermaid
flowchart LR
    USER[User in fabrikam.com] -->|Authenticate to resource in contoso.com| TRUST{Forest trust exists?}
    TRUST -->|Yes| AUTH[Kerberos referral\ncross-realm TGT]
    TRUST -->|No| FAIL[Authentication fails]
    AUTH --> RESOURCE[Access resource]
```

### Trust Security Features
- **SID Filtering** — drops SIDs from other forest (prevents SID injection)
- **Selective Authentication** — only allow specific users from trusted forest
- **Name Suffix Routing** — control which DNS suffixes route over trust

```powershell
# Verify trust
Get-ADTrust -Filter *
nltest /domain_trusts /v

# Test trust password
netdom trust contoso.com /Domain:fabrikam.com /verify
```

---

## Sites and Subnets

A **site** = a collection of well-connected (LAN-speed) subnets.

```mermaid
flowchart TD
    FOREST[Forest]
    FOREST --> SITE1[Site: NYC\n10.1.0.0/16]
    FOREST --> SITE2[Site: London\n10.2.0.0/16]
    FOREST --> SITE3[Site: Singapore\n10.3.0.0/16]
    
    SITE1 --> DC1[DC-NYC-01]
    SITE1 --> DC2[DC-NYC-02]
    SITE2 --> DC3[DC-LON-01]
    SITE3 --> DC4[DC-SIN-01]
    
    SITE1 -.IPSec link.- SITE2
    SITE2 -.IPSec link.- SITE3
```

Why sites matter:
- Clients authenticate to **closest DC** (via DNS SRV records weighted by site)
- Replication is **frequent intra-site** (every 15s default) vs **scheduled inter-site** (default every 180 min, configurable)
- GPO and SYSVOL replication respects site topology

### Define a Site
```powershell
New-ADReplicationSite -Name "NYC"
New-ADReplicationSubnet -Name "10.1.0.0/16" -Site "NYC"
```

---

## Replication

AD uses **multi-master replication** — any DC can accept writes (except RODCs).

### Mechanism
- Built on **USN (Update Sequence Numbers)** — monotonically increasing per object
- Uses **vector clocks** (up-to-dateness vector) to track what each DC has seen
- **KCC (Knowledge Consistency Checker)** auto-generates replication topology
- **ISTG (Inter-Site Topology Generator)** picks bridgehead servers per site

```mermaid
sequenceDiagram
    participant DC1 as DC1 (writes change)
    participant DC2 as DC2 (replication partner)
    
    DC1->>DC1: Local write\nIncrement USN
    DC1->>DC2: Notify (intra-site, 15s)\nor wait schedule (inter-site)
    DC2->>DC1: Request changes since USN X
    DC1->>DC2: Send delta
    DC2->>DC2: Apply changes\nUpdate USN, version
```

### Conflict Resolution
- **Last Writer Wins** by attribute version + timestamp
- For deletions: tombstones replicate for 180 days

### Replication Commands
```powershell
# Show replication status
repadmin /showrepl

# Force replication
repadmin /syncall /AdeP

# Show replication queue
repadmin /queue

# Check replication errors
repadmin /replsummary

# Show outbound replication
repadmin /showconn

# Compare DC contents
repadmin /showobjmeta DC1 "CN=jdoe,OU=Users,DC=corp,DC=com"
```

---

## FSMO Roles (Flexible Single Master Operations)

Despite multi-master, **5 special operations** are single-master. These roles are called **FSMO** (or **Operations Master**).

```mermaid
flowchart TD
    FOREST[Forest-wide FSMO roles]
    FOREST --> SCHEMA[Schema Master\n1 per forest]
    FOREST --> DOMAIN_NAMING[Domain Naming Master\n1 per forest]
    
    DOMAIN[Domain-wide FSMO roles]
    DOMAIN --> PDC[PDC Emulator\n1 per domain]
    DOMAIN --> RID[RID Master\n1 per domain]
    DOMAIN --> INFRA[Infrastructure Master\n1 per domain]
```

| Role | Scope | Purpose |
|---|---|---|
| **Schema Master** | Forest | Updates the AD schema |
| **Domain Naming Master** | Forest | Adds/removes domains in the forest |
| **PDC Emulator** | Domain | Time source, password changes, GPO writes |
| **RID Master** | Domain | Allocates RID pools to DCs for new SIDs |
| **Infrastructure Master** | Domain | Cross-domain object references (skip if all DCs are GC) |

### Critical Role: PDC Emulator
- **Authoritative time source** for the domain (syncs from external NTP)
- Receives **password change notifications** first (so other DCs can verify recent changes)
- **GPO editing** happens against the PDC by default
- Acts as **fallback** for legacy NTLM auth

> If PDC Emulator fails: clocks drift → Kerberos breaks → mass auth outage. **Most important FSMO role to monitor.**

### Find FSMO Holders
```powershell
netdom query fsmo

# Or via PowerShell
Get-ADDomain | Select-Object PDCEmulator, RIDMaster, InfrastructureMaster
Get-ADForest | Select-Object SchemaMaster, DomainNamingMaster
```

### Transfer vs Seize
- **Transfer** = graceful, source DC is alive
- **Seize** = forceful, source DC is dead/unrecoverable
- **NEVER** bring the old holder back online after a seize (will cause corruption)

```powershell
# Transfer (graceful)
Move-ADDirectoryServerOperationMasterRole -Identity "DC02" -OperationMasterRole PDCEmulator

# Seize (force — only when source is dead)
Move-ADDirectoryServerOperationMasterRole -Identity "DC02" -OperationMasterRole PDCEmulator -Force
```

---

## Global Catalog (GC)

A **GC** is a DC that holds a partial replica of **all** domain partitions in the forest.

- Enables **forest-wide LDAP searches** without referrals
- Required for **Universal Group membership** evaluation at login
- Required for **Exchange** address lookups

```powershell
# Promote DC to GC
Set-ADObject -Identity (Get-ADDomainController DC02).NTDSSettingsObjectDN -Replace @{options=1}
```

**Rule**: In multi-domain forests, run GC on most DCs. In single-domain forests, every DC is essentially a GC.

---

## Replication Topology

```mermaid
flowchart TD
    subgraph "Site: NYC"
        DC1_NYC[DC1-NYC] --- DC2_NYC[DC2-NYC]
    end
    subgraph "Site: London"
        DC1_LON[DC1-LON] --- DC2_LON[DC2-LON]
    end
    subgraph "Site: Tokyo"
        DC1_TOK[DC1-TOK]
    end
    
    DC1_NYC ==Bridgehead==> DC1_LON
    DC1_LON ==Bridgehead==> DC1_TOK
    
    NYC_LON[Site Link: NYC-LON\ncost 100, schedule 180min]
    LON_TOK[Site Link: LON-TOK\ncost 200, schedule 240min]
```

- **Intra-site**: full mesh, change notification, no compression (15s)
- **Inter-site**: bridgehead-only, scheduled, compressed
- **Site link cost** influences path selection
- **Site link bridging** allows transitive replication

---

## SYSVOL Replication

SYSVOL = the replicated share holding:
- Group Policy templates
- Logon scripts
- Domain DFS namespaces

Replicated by:
- **DFSR** (Distributed File System Replication) — modern, since 2008
- ~~FRS~~ (File Replication Service) — deprecated, must migrate

### Check Replication Health
```powershell
# DFSR backlog
dfsrdiag Backlog /ReceivingMember:DC02 /SendingMember:DC01 /RGName:"Domain System Volume" /RFName:SYSVOL Share

# DFSR health report
dfsrdiag ReplicationState
```

---

## Architecture Decision Matrix

| Question | Answer |
|---|---|
| Single forest or multiple? | Single, unless you need schema/security isolation |
| Single domain or multiple? | Single, unless replication or political boundaries demand |
| How many DCs per site? | At least 2 for redundancy |
| Where to put PDC Emulator? | Most reliable site, closest to NTP |
| RODC in branch office? | Yes — if you don't trust physical security |
| Site link cost | Lower cost = preferred path |
| GC placement | Every DC, unless infrastructure master conflict |

---

## Validation Commands

```powershell
# Comprehensive health check
dcdiag /v /c /e

# Specific tests
dcdiag /test:Replications
dcdiag /test:Advertising
dcdiag /test:FSMOCheck
dcdiag /test:DNS

# Replication summary
repadmin /replsummary

# Show all DCs in domain
Get-ADDomainController -Filter *

# Show forest mode and DCs
Get-ADForest | fl Name,ForestMode,RootDomain,Domains,SchemaMaster,DomainNamingMaster
```

---

## Architecture Health Runbook (PowerShell + CMD)

```mermaid
flowchart TD
        A[AD outage / slowness] --> B{Replication healthy?}
        B -->|No| C[Check repadmin + site links]
        B -->|Yes| D{FSMO reachable?}
        C --> E[Fix DNS/firewall/topology]
        D -->|No| F[Transfer/Seize role safely]
        D -->|Yes| G{Trust healthy?}
        G -->|No| H[Reset/verify trust]
        G -->|Yes| I[Check GC + SYSVOL]
        E --> J[Re-validate all checks]
        F --> J
        H --> J
        I --> J
```

### Replication Health

**PowerShell**
```powershell
Get-ADReplicationFailure -Scope Forest | Format-Table Server,FirstFailureTime,FailureCount -Auto
Get-ADReplicationPartnerMetadata -Target * -Scope Forest |
    Select-Object Server,Partner,LastReplicationSuccess
```

**CMD**
```cmd
repadmin /replsummary
repadmin /showrepl * /csv
repadmin /queue
```

### FSMO Health

**PowerShell**
```powershell
Get-ADForest | Select-Object SchemaMaster,DomainNamingMaster
Get-ADDomain | Select-Object PDCEmulator,RIDMaster,InfrastructureMaster
```

**CMD**
```cmd
netdom query fsmo
dcdiag /test:FSMOCheck
```

### Trust Health

**PowerShell**
```powershell
Get-ADTrust -Filter * | Select-Object Name,TrustType,TrustDirection,TrustAttributes
```

**CMD**
```cmd
nltest /domain_trusts /v
netdom trust contoso.com /domain:fabrikam.com /verify
```

### Site + GC + SYSVOL Health

**PowerShell**
```powershell
Get-ADDomainController -Filter * | Select-Object HostName,Site,IsGlobalCatalog
Get-Service DFSR
```

**CMD**
```cmd
nltest /dsgetsite
dfsrdiag ReplicationState
dcdiag /test:Advertising /test:DNS
```

---

## Key Takeaways

- **Forest** = security + schema boundary (cross-forest = trust)
- **Domains** = replication + admin units; OUs = delegation + GPO
- **5 FSMO roles** — most critical is PDC Emulator (time, passwords, GPO)
- **Multi-master replication** with USNs + vector clocks
- **Sites** define replication topology and DC discovery
- **Global Catalog** enables forest-wide queries + Universal Group eval
- **SYSVOL** = replicated share (DFSR), not part of AD database
- **Trust types** must be chosen based on direction + transitivity needs

**Next**: Kerberos authentication deep dive → [03-ad-authentication-kerberos.md](03-ad-authentication-kerberos.md)
