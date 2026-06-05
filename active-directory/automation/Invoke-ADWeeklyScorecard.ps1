[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$DomainFqdn,

    [int]$LookbackHours = 168,

    [string]$OutputDirectory = ".\reports"
)

Set-StrictMode -Version Latest

$modulePath = Join-Path $PSScriptRoot 'ADReliability.psm1'
Import-Module $modulePath -Force

if (-not (Test-Path $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}

$stamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$baseName = "ad-scorecard-$stamp"

$scorecard = Get-ADReliabilityScorecard -DomainFqdn $DomainFqdn -LookbackHours $LookbackHours

$jsonPath = Join-Path $OutputDirectory "$baseName.json"
$csvPath  = Join-Path $OutputDirectory "$baseName.csv"
$mdPath   = Join-Path $OutputDirectory "$baseName.md"

$scorecard | ConvertTo-Json -Depth 6 | Out-File -FilePath $jsonPath -Encoding utf8

$rows = @(
    [pscustomobject]@{ Metric='Replication'; Healthy=$scorecard.Replication.Healthy; FailedPartners=$scorecard.Replication.FailedPartners; MaxLagMinutes=$scorecard.Replication.MaxReplicationLagMinutes },
    [pscustomobject]@{ Metric='Authentication'; Healthy=$scorecard.Authentication.Healthy; FailedLogons4625=$scorecard.Authentication.FailedLogons4625; KerberosPreAuthFailed4771=$scorecard.Authentication.KerberosPreAuthFailed4771 },
    [pscustomobject]@{ Metric='DNS'; Healthy=$scorecard.DNS.Healthy; LdapSrvRecords=$scorecard.DNS.LdapSrvRecords; KerberosSrvRecords=$scorecard.DNS.KerberosSrvRecords },
    [pscustomobject]@{ Metric='GPO'; Healthy=$scorecard.GPO.Healthy; Successful5016=$scorecard.GPO.Successful5016; NetworkFailures1129=$scorecard.GPO.NetworkFailures1129 }
)
$rows | Export-Csv -Path $csvPath -NoTypeInformation -Encoding utf8

$md = @"
# Active Directory Weekly Reliability Scorecard

- Domain: $($scorecard.DomainFqdn)
- Lookback: $($scorecard.LookbackHours) hours
- Score: **$($scorecard.Score)/100**
- Status: **$($scorecard.Status)**
- GeneratedAt: $($scorecard.GeneratedAt)

## SLI Snapshot

| Metric | Healthy | Key Values |
|---|---|---|
| Replication | $($scorecard.Replication.Healthy) | FailedPartners=$($scorecard.Replication.FailedPartners), MaxLagMinutes=$($scorecard.Replication.MaxReplicationLagMinutes) |
| Authentication | $($scorecard.Authentication.Healthy) | 4625=$($scorecard.Authentication.FailedLogons4625), 4771=$($scorecard.Authentication.KerberosPreAuthFailed4771), Lockouts=$($scorecard.Authentication.AccountLockouts4740) |
| DNS | $($scorecard.DNS.Healthy) | LDAP_SRV=$($scorecard.DNS.LdapSrvRecords), KERB_SRV=$($scorecard.DNS.KerberosSrvRecords) |
| GPO | $($scorecard.GPO.Healthy) | Success5016=$($scorecard.GPO.Successful5016), NetFail1129=$($scorecard.GPO.NetworkFailures1129), COM8194=$($scorecard.GPO.ComErrors8194) |

## Recommended Actions

$(if ($scorecard.Status -eq 'Green') { '- Continue baseline monitoring.' } elseif ($scorecard.Status -eq 'Yellow') { '- Open reliability review item for weak metrics this week.' } else { '- Trigger identity incident runbook immediately and assign incident commander.' })
"@

$md | Out-File -FilePath $mdPath -Encoding utf8

[pscustomobject]@{
    JsonReport = $jsonPath
    CsvReport  = $csvPath
    MdReport   = $mdPath
    Score      = $scorecard.Score
    Status     = $scorecard.Status
}
