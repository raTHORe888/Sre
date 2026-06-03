# 09. AD Interview Scenarios (Senior/Staff SRE)

## 1) Why does AD break when DNS is misconfigured?

Because AD service discovery is DNS-driven via SRV records. If clients point to non-AD DNS, they cannot locate DC/KDC/GC.

**Checks**

PowerShell:
```powershell
Resolve-DnsName -Type SRV _ldap._tcp.dc._msdcs.corp.com
```

CMD:
```cmd
nslookup -type=SRV _ldap._tcp.dc._msdcs.corp.com
```

---

## 2) How do you triage a widespread Kerberos outage in 10 minutes?

1. Time sync (`w32tm`)
2. DC discovery (`nltest`)
3. Ticket cache (`klist`)
4. SPN duplicates (`setspn -X`)
5. Security event IDs 4768/4769/4771

```mermaid
flowchart LR
    T[Time] --> D[DC discovery] --> K[Ticket check] --> S[SPN check] --> E[Events]
```

---

## 3) Transfer vs seize FSMO — when and why?

- Transfer: when current role holder is alive.
- Seize: only when holder is unrecoverable.
- Never bring seized former holder back online without metadata cleanup.

PowerShell:
```powershell
Move-ADDirectoryServerOperationMasterRole -Identity "DC02" -OperationMasterRole PDCEmulator -Force
```

CMD:
```cmd
netdom query fsmo
```

---

## 4) Why would GPO apply to one machine but not another in same OU?

- Security filtering
- WMI filter mismatch
- Replication delay
- Loopback mode
- Slow-link behavior

PowerShell:
```powershell
Get-GPInheritance -Target "OU=Workstations,DC=corp,DC=com"
```

CMD:
```cmd
gpresult /h C:\gp.html
```

---

## 5) Explain Golden Ticket in one minute and how you recover.

Golden Ticket = forged TGT signed with stolen KRBTGT hash.
Recovery:
1. Isolate threat
2. Rotate KRBTGT twice
3. Reset privileged/service credentials
4. Validate persistence removed

---

## 6) What AD metrics should SRE monitor?

- Replication failures/latency
- LDAP bind failure rate
- Kerberos failures by code
- DFSR backlog (SYSVOL)
- DNS SRV query failures
- DC CPU/memory and LSASS health

---

## 7) How do you prove trust health across forests?

PowerShell:
```powershell
Get-ADTrust -Filter *
```

CMD:
```cmd
nltest /domain_trusts /v
netdom trust contoso.com /domain:fabrikam.com /verify
```

---

## 8) Why is PDC Emulator operationally critical?

It anchors time sync, receives urgent password updates, and is default for GPO edits. If unstable, authentication reliability drops quickly.

---

## 9) What is your AD DR strategy?

- System State backups for DCs
- Tested authoritative/non-authoritative restore
- Multi-site DCs + DNS redundancy
- Runbook for FSMO seizure and metadata cleanup

---

## 10) Whiteboard this outage: "Users in APAC can log in only after 3 attempts"

Likely causes:
- APAC clients hitting remote DC due to bad subnet mapping
- Inter-site replication lag
- Time drift at APAC DC
- DNS stale SRV records

Use parallel checks with PowerShell + CMD and close with replication + DNS fix.

---

## More Kerberos-Focused Q&A

For a dedicated Kerberos-only interview bank, see [10-kerberos-interview-qa.md](10-kerberos-interview-qa.md).
