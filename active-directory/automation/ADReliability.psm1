Set-StrictMode -Version Latest

function Get-ADReplicationHealth {
    [CmdletBinding()]
    param(
        [int]$LookbackHours = 24
    )

    $since = (Get-Date).AddHours(-1 * $LookbackHours)

    $failures = Get-ADReplicationFailure -Scope Forest -ErrorAction SilentlyContinue
    $partners = Get-ADReplicationPartnerMetadata -Target * -Scope Forest -ErrorAction SilentlyContinue

    $failedPartners = @($failures).Count
    $totalPartners = @($partners).Count

    $maxLagMinutes = 0
    if ($partners) {
        $maxLagMinutes = [int](($partners | ForEach-Object {
            if ($_.LastReplicationSuccess) {
                ((Get-Date) - $_.LastReplicationSuccess).TotalMinutes
            }
        } | Measure-Object -Maximum).Maximum)
    }

    [pscustomobject]@{
        Metric                    = 'Replication'
        LookbackHours             = $LookbackHours
        FailedPartners            = $failedPartners
        TotalPartners             = $totalPartners
        MaxReplicationLagMinutes  = $maxLagMinutes
        Healthy                   = ($failedPartners -eq 0)
        CheckedAt                 = Get-Date
    }
}

function Get-ADAuthFailureMetrics {
    [CmdletBinding()]
    param(
        [int]$LookbackHours = 24
    )

    $start = (Get-Date).AddHours(-1 * $LookbackHours)
    $events = Get-WinEvent -FilterHashtable @{ LogName = 'Security'; StartTime = $start; Id = 4625, 4768, 4769, 4771, 4740 } -ErrorAction SilentlyContinue

    $failedLogon = @($events | Where-Object Id -eq 4625).Count
    $preauthFail = @($events | Where-Object Id -eq 4771).Count
    $tgtIssued = @($events | Where-Object Id -eq 4768).Count
    $stIssued = @($events | Where-Object Id -eq 4769).Count
    $lockouts = @($events | Where-Object Id -eq 4740).Count

    [pscustomobject]@{
        Metric                      = 'Authentication'
        LookbackHours               = $LookbackHours
        FailedLogons4625            = $failedLogon
        KerberosPreAuthFailed4771   = $preauthFail
        TGTIssued4768               = $tgtIssued
        ServiceTickets4769          = $stIssued
        AccountLockouts4740         = $lockouts
        Healthy                     = ($preauthFail -lt 100 -and $lockouts -lt 50)
        CheckedAt                   = Get-Date
    }
}

function Get-ADDnsHealth {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DomainFqdn
    )

    $ldapSrv = $null
    $kerbSrv = $null
    try { $ldapSrv = Resolve-DnsName -Type SRV ("_ldap._tcp.dc._msdcs.{0}" -f $DomainFqdn) -ErrorAction Stop } catch {}
    try { $kerbSrv = Resolve-DnsName -Type SRV ("_kerberos._tcp.{0}" -f $DomainFqdn) -ErrorAction Stop } catch {}

    $ldapCount = @($ldapSrv).Count
    $kerbCount = @($kerbSrv).Count

    [pscustomobject]@{
        Metric                = 'DNS'
        DomainFqdn            = $DomainFqdn
        LdapSrvRecords        = $ldapCount
        KerberosSrvRecords    = $kerbCount
        Healthy               = ($ldapCount -gt 0 -and $kerbCount -gt 0)
        CheckedAt             = Get-Date
    }
}

function Get-ADGpoHealth {
    [CmdletBinding()]
    param(
        [int]$LookbackHours = 24
    )

    $start = (Get-Date).AddHours(-1 * $LookbackHours)
    $events = Get-WinEvent -FilterHashtable @{ LogName = 'Microsoft-Windows-GroupPolicy/Operational'; StartTime = $start } -ErrorAction SilentlyContinue

    $success = @($events | Where-Object Id -eq 5016).Count
    $networkFail = @($events | Where-Object Id -eq 1129).Count
    $comErrors = @($events | Where-Object Id -eq 8194).Count

    [pscustomobject]@{
        Metric                 = 'GPO'
        LookbackHours          = $LookbackHours
        Successful5016         = $success
        NetworkFailures1129    = $networkFail
        ComErrors8194          = $comErrors
        Healthy                = ($networkFail -eq 0 -and $comErrors -eq 0)
        CheckedAt              = Get-Date
    }
}

function Get-ADReliabilityScorecard {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DomainFqdn,
        [int]$LookbackHours = 24
    )

    $replication = Get-ADReplicationHealth -LookbackHours $LookbackHours
    $auth = Get-ADAuthFailureMetrics -LookbackHours $LookbackHours
    $dns = Get-ADDnsHealth -DomainFqdn $DomainFqdn
    $gpo = Get-ADGpoHealth -LookbackHours $LookbackHours

    $score = 100
    if (-not $replication.Healthy) { $score -= 30 }
    if (-not $dns.Healthy) { $score -= 30 }
    if (-not $auth.Healthy) { $score -= 25 }
    if (-not $gpo.Healthy) { $score -= 15 }

    if ($score -lt 0) { $score = 0 }

    $status = if ($score -ge 95) { 'Green' } elseif ($score -ge 80) { 'Yellow' } else { 'Red' }

    [pscustomobject]@{
        DomainFqdn       = $DomainFqdn
        LookbackHours    = $LookbackHours
        Score            = $score
        Status           = $status
        Replication      = $replication
        Authentication   = $auth
        DNS              = $dns
        GPO              = $gpo
        GeneratedAt      = Get-Date
    }
}

function Invoke-ADSelfHealing {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$DomainFqdn,

        [switch]$ReregisterDns,
        [switch]$RestartNetlogon,
        [switch]$ForceReplication,
        [switch]$PurgeKerberosTickets
    )

    $actions = @()

    if ($ReregisterDns) {
        if ($PSCmdlet.ShouldProcess('LocalHost', 'Re-register DNS records')) {
            ipconfig /registerdns | Out-Null
            $actions += 'Executed: ipconfig /registerdns'
        }
    }

    if ($RestartNetlogon) {
        if ($PSCmdlet.ShouldProcess('LocalHost', 'Restart Netlogon service')) {
            Restart-Service -Name Netlogon -Force
            $actions += 'Executed: Restart-Service Netlogon'
        }
    }

    if ($ForceReplication) {
        if ($PSCmdlet.ShouldProcess($DomainFqdn, 'Force AD replication syncall')) {
            repadmin /syncall /AdeP | Out-Null
            $actions += 'Executed: repadmin /syncall /AdeP'
        }
    }

    if ($PurgeKerberosTickets) {
        if ($PSCmdlet.ShouldProcess('LocalHost', 'Purge Kerberos ticket cache')) {
            klist purge | Out-Null
            $actions += 'Executed: klist purge'
        }
    }

    if (-not $actions) {
        $actions += 'No actions selected. Use switches to invoke healing actions.'
    }

    [pscustomobject]@{
        DomainFqdn = $DomainFqdn
        Actions    = $actions
        CompletedAt = Get-Date
    }
}

Export-ModuleMember -Function Get-ADReplicationHealth, Get-ADAuthFailureMetrics, Get-ADDnsHealth, Get-ADGpoHealth, Get-ADReliabilityScorecard, Invoke-ADSelfHealing
