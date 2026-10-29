#Requires -Version 5.1
<#
.SYNOPSIS
  Update-only maintenance for already-installed Windows developer tools.

.DESCRIPTION
  Discovers WinGet, Chocolatey, and Scoop when present. Updates each manager's
  existing inventory only. Never installs missing apps or bootstraps managers.
  Never recovers a failed update by installing through another manager.

.NOTES
  ADR: docs/adr/0002-ADR-workstation-patching-update-only.md
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Audit,
    [switch]$Fast,
    [switch]$NoElevate,
    [switch]$AutoElevate,
    [string[]]$Only = @(),
    [string[]]$Skip = @(),
    [string]$ConfigPath = '',
    [string]$LogDirectory = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

. (Join-Path $PSScriptRoot 'Patching.Lib.ps1')

$script:Results = [System.Collections.Generic.List[object]]::new()
$script:LogFile = $null
$script:Config = $null
$script:StartTime = Get-Date
$script:IsElevated = $false

function Write-PatchLog {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'DEBUG')][string]$Level = 'INFO'
    )
    $line = '{0:u} [{1}] {2}' -f (Get-Date), $Level, $Message
    Write-Host $line
    if ($script:LogFile) {
        Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8
    }
}

function Test-IsAdmin {
    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]$id
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}

function Invoke-SelfElevation {
    if ($NoElevate -or -not $AutoElevate -or $script:IsElevated) {
        return $false
    }
    if (-not ([Environment]::UserInteractive)) {
        Write-PatchLog 'Non-interactive session; skipping AutoElevate. Use a scheduled admin principal or Run as different user.' 'WARN'
        return $false
    }
    Write-PatchLog 'Relaunching elevated (same user UAC). For a different admin account, use OS Run as different user or just update-elevated.' 'INFO'
    $argList = @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-File', $PSCommandPath
    )
    foreach ($key in $PSBoundParameters.Keys) {
        if ($key -eq 'AutoElevate') { continue }
        $val = $PSBoundParameters[$key]
        if ($val -is [switch]) {
            if ($val) { $argList += "-$key" }
        }
        elseif ($val -is [array]) {
            if ($val.Count -gt 0) {
                $argList += "-$key"
                $argList += ($val -join ',')
            }
        }
        elseif ($val) {
            $argList += "-$key"
            $argList += "$val"
        }
    }
    $argList += '-NoElevate'
    try {
        $p = Start-Process -FilePath (Get-Process -Id $PID).Path -Verb RunAs -ArgumentList $argList -Wait -PassThru
        exit $p.ExitCode
    }
    catch {
        Write-PatchLog "Elevation cancelled or failed: $($_.Exception.Message). Continuing unelevated; admin-only managers will skip." 'WARN'
        return $false
    }
}

function Get-PatchingConfig {
    param([string]$Path)
    $defaults = [ordered]@{
        MaxRetries             = 3
        RetryDelaysSec         = @(15, 30, 60)
        RetryJitterSec         = 5
        CommandTimeoutSec      = 600
        BoundedRunTimeoutSec   = 3600
        LogRetentionDays       = 14
        LogDirectory           = ''
        SkipManagers           = @()
        WingetIncludeUnknown   = $false
        WingetSkipPackages     = @()
        ChocolateySkipPackages = @()
        ScoopSkipPackages      = @()
        EnableUvSelfUpdate     = $true
        EnableBunSelfUpdate    = $true
        EnableMiseSelfUpdate   = $true
        FastSkipManagers       = @('chocolatey')
    }
    if (-not $Path) {
        $Path = Join-Path $PSScriptRoot 'update-config.json'
    }
    if (Test-Path -LiteralPath $Path) {
        try {
            $json = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($prop in $json.PSObject.Properties) {
                $defaults[$prop.Name] = $prop.Value
            }
        }
        catch {
            Write-PatchLog "Config parse failed ($Path): $($_.Exception.Message). Using defaults." 'WARN'
        }
    }
    return $defaults
}

function Test-CommandExists {
    param([Parameter(Mandatory)][string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function New-OpResult {
    param(
        [string]$Manager,
        [string]$Operation,
        [string]$PackageId = '',
        [string]$Status,
        [string]$PreviousVersion = '',
        [string]$ResultVersion = '',
        [int]$Attempt = 1,
        [object]$ExitCode = $null,
        [string]$Detail = ''
    )
    $obj = [pscustomobject]@{
        Timestamp       = (Get-Date).ToUniversalTime().ToString('o')
        Manager         = $Manager
        Operation       = $Operation
        PackageId       = $PackageId
        Status          = $Status
        PreviousVersion = $PreviousVersion
        ResultVersion   = $ResultVersion
        Attempt         = $Attempt
        ExitCode        = $ExitCode
        Detail          = $Detail
    }
    $script:Results.Add($obj) | Out-Null
    Write-PatchLog ("{0}/{1} {2} → {3} {4}" -f $Manager, $Operation, $PackageId, $Status, $Detail)
    return $obj
}

function Invoke-External {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string[]]$ArgumentList = @(),
        [int]$TimeoutSec = 600,
        [int[]]$SuccessExitCodes = @(0),
        [switch]$DisableRetry
    )
    $max = if ($DisableRetry) { 1 } else { [int]$script:Config.MaxRetries }
    if ($max -lt 1) { $max = 1 }
    $delays = @($script:Config.RetryDelaysSec)
    $jitterMax = [int]$script:Config.RetryJitterSec
    $attempt = 0
    $last = $null

    while ($attempt -lt $max) {
        $attempt++
        $stdoutFile = [IO.Path]::GetTempFileName()
        $stderrFile = [IO.Path]::GetTempFileName()
        try {
            $p = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList `
                -NoNewWindow -PassThru -Wait `
                -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile
            # Start-Process -Wait does not enforce timeout on older hosts; best-effort check:
            if ($TimeoutSec -gt 0 -and $p.HasExited -eq $false) {
                try { $p.Kill() } catch { }
                $out = (Get-Content $stdoutFile -Raw -ErrorAction SilentlyContinue) + (Get-Content $stderrFile -Raw -ErrorAction SilentlyContinue)
                $last = [pscustomobject]@{ ExitCode = -1; Output = $out; TimedOut = $true; Attempt = $attempt }
                if ($attempt -ge $max) { return $last }
                continue
            }
            $code = $p.ExitCode
            $out = @(
                (Get-Content -LiteralPath $stdoutFile -Raw -ErrorAction SilentlyContinue)
                (Get-Content -LiteralPath $stderrFile -Raw -ErrorAction SilentlyContinue)
            ) -join "`n"
            $last = [pscustomobject]@{ ExitCode = $code; Output = $out; TimedOut = $false; Attempt = $attempt }
            if ($SuccessExitCodes -contains $code) {
                return $last
            }
            if (Test-PatchingPermanentFailure -Output $out) {
                return $last
            }
            if (-not (Test-PatchingTransientFailure -ExitCode $code -Output $out)) {
                return $last
            }
            if ($attempt -ge $max) {
                return $last
            }
            $delayIdx = [Math]::Min($attempt - 1, $delays.Count - 1)
            $delay = [int]$delays[$delayIdx]
            if ($jitterMax -gt 0) { $delay += Get-Random -Minimum 0 -Maximum ($jitterMax + 1) }
            Write-PatchLog "Transient failure (exit $code); retry $attempt/$max after ${delay}s" 'WARN'
            New-OpResult -Manager 'runner' -Operation 'retry' -Status 'RETRYING_TRANSIENT_FAILURE' -Attempt $attempt -ExitCode $code -Detail $FilePath | Out-Null
            Start-Sleep -Seconds $delay
        }
        finally {
            Remove-Item -LiteralPath $stdoutFile, $stderrFile -Force -ErrorAction SilentlyContinue
        }
    }
    return $last
}

function Test-ManagerEnabled {
    param([Parameter(Mandatory)][string]$Name)
    $n = $Name.ToLowerInvariant()
    if ($Only.Count -gt 0) {
        $hit = $false
        foreach ($o in $Only) {
            if ($o.ToLowerInvariant() -eq $n) { $hit = $true; break }
        }
        if (-not $hit) { return $false }
    }
    foreach ($s in $Skip) {
        if ($s.ToLowerInvariant() -eq $n) { return $false }
    }
    foreach ($s in @($script:Config.SkipManagers)) {
        if ("$s".ToLowerInvariant() -eq $n) { return $false }
    }
    if ($Fast) {
        foreach ($s in @($script:Config.FastSkipManagers)) {
            if ("$s".ToLowerInvariant() -eq $n) { return $false }
        }
    }
    return $true
}

function Get-CommandPathSafe {
    param([string]$Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { return $cmd.Source }
    if ($cmd -and $cmd.Path) { return $cmd.Path }
    return $null
}

function Test-ChocoHasPackage {
    param([string]$Id)
    if (-not (Test-CommandExists 'choco')) { return $false }
    $r = Invoke-External -FilePath 'choco' -ArgumentList @('list', '--local-only', '--limit-output', $Id) -DisableRetry -SuccessExitCodes @(0)
    if (-not $r -or $r.ExitCode -ne 0) { return $false }
    foreach ($line in ($r.Output -split "`r?`n")) {
        if ($line -match ('^{0}\|' -f [regex]::Escape($Id))) { return $true }
    }
    return $false
}

function Resolve-SelfUpdateOwner {
    param(
        [Parameter(Mandatory)][string]$CommandName,
        [string]$ChocoPackageId = ''
    )
    $path = Get-CommandPathSafe $CommandName
    if (-not $path) {
        return [pscustomobject]@{ Action = 'skip'; Status = 'SKIPPED_NOT_INSTALLED'; Detail = "$CommandName not on PATH" }
    }
    $chocoId = if ($ChocoPackageId) { $ChocoPackageId } else { $CommandName }
    $inChoco = $false
    if (Test-CommandExists 'choco') {
        $inChoco = Test-ChocoHasPackage -Id $chocoId
    }
    $resolved = Resolve-PatchingSelfUpdateAction -CommandPath $path -ListedInChocolatey:$inChoco -ChocoPackageId $chocoId
    if ($resolved.Detail -and $resolved.Detail -notmatch [regex]::Escape($path)) {
        $resolved.Detail = "$($resolved.Detail). Path=$path"
    }
    return $resolved
}

function Initialize-Logging {
    $root = $LogDirectory
    if (-not $root) { $root = [string]$script:Config.LogDirectory }
    if (-not $root) {
        $root = Join-Path $env:LOCALAPPDATA 'mycmd\patching\logs'
    }
    New-Item -ItemType Directory -Force -Path $root | Out-Null
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $script:LogFile = Join-Path $root "update-devtools-$stamp.log"
    Write-PatchLog "Log: $($script:LogFile)"
    return $root
}

function Save-JsonReport {
    param([string]$LogRoot)
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $path = Join-Path $LogRoot "update-devtools-$stamp.json"
    $failed = @($script:Results | Where-Object { $_.Status -like 'FAILED_*' })
    $payload = [pscustomobject]@{
        StartedUtc   = $script:StartTime.ToUniversalTime().ToString('o')
        FinishedUtc  = (Get-Date).ToUniversalTime().ToString('o')
        DryRun       = [bool]$DryRun
        Audit        = [bool]$Audit
        Elevated     = [bool]$script:IsElevated
        Results      = @($script:Results)
        FailedCount  = $failed.Count
        LogFile      = $script:LogFile
    }
    $payload | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $path -Encoding UTF8
    Write-PatchLog "JSON report: $path"
    return $path
}

function Show-Summary {
    $groups = $script:Results | Group-Object Status | Sort-Object Name
    Write-Host ''
    Write-Host '=== Summary ==='
    foreach ($g in $groups) {
        Write-Host ("  {0,-32} {1}" -f $g.Name, $g.Count)
    }
}

function Invoke-WingetUpdate {
    if (-not (Test-CommandExists 'winget')) {
        New-OpResult -Manager 'winget' -Operation 'discover' -Status 'SKIPPED_NOT_INSTALLED' -Detail 'winget not found' | Out-Null
        return
    }
    if (-not (Test-ManagerEnabled 'winget')) {
        New-OpResult -Manager 'winget' -Operation 'filter' -Status 'SKIPPED_NOT_INSTALLED' -Detail 'filtered by Only/Skip/Fast/config' | Out-Null
        return
    }
    if ($Audit -or $DryRun) {
        $args = @('upgrade', '--source', 'winget', '--disable-interactivity', '--accept-source-agreements')
        if ($script:Config.WingetIncludeUnknown) { $args += '--include-unknown' }
        if ($DryRun) { Write-PatchLog 'DRYRUN winget upgrade --all (inventory probe only)' }
        $probe = Invoke-External -FilePath 'winget' -ArgumentList $args -SuccessExitCodes @(0, -1978335189) -DisableRetry
        New-OpResult -Manager 'winget' -Operation 'audit' -Status 'ALREADY_CURRENT' -ExitCode $probe.ExitCode -Detail 'Listed upgrade candidates (no changes)' | Out-Null
        return
    }
    $upgradeArgs = @(
        'upgrade', '--all', '--source', 'winget',
        '--disable-interactivity', '--accept-package-agreements', '--accept-source-agreements'
    )
    if ($script:Config.WingetIncludeUnknown) { $upgradeArgs += '--include-unknown' }
    $r = Invoke-External -FilePath 'winget' -ArgumentList $upgradeArgs `
        -TimeoutSec ([int]$script:Config.CommandTimeoutSec) `
        -SuccessExitCodes @(0, -1978335189, -1978335212)
    if ($r.ExitCode -in @(0, -1978335189, -1978335212)) {
        $status = if ($r.ExitCode -eq -1978335189) { 'ALREADY_CURRENT' } else { 'UPDATED' }
        New-OpResult -Manager 'winget' -Operation 'upgrade-all' -Status $status -ExitCode $r.ExitCode | Out-Null
    }
    elseif (Test-PatchingTransientFailure -ExitCode $r.ExitCode -Output $r.Output) {
        New-OpResult -Manager 'winget' -Operation 'upgrade-all' -Status 'FAILED_SOURCE_UNAVAILABLE' -ExitCode $r.ExitCode -Attempt $r.Attempt -Detail 'Transient source/network failure' | Out-Null
    }
    elseif ("$($r.Output)" -match 'Access is denied|requires administrator') {
        New-OpResult -Manager 'winget' -Operation 'upgrade-all' -Status 'FAILED_PERMISSION' -ExitCode $r.ExitCode | Out-Null
    }
    else {
        $snip = if ($r.Output) { $r.Output.Substring(0, [Math]::Min(200, $r.Output.Length)) } else { '' }
        New-OpResult -Manager 'winget' -Operation 'upgrade-all' -Status 'FAILED_PACKAGE_OPERATION' -ExitCode $r.ExitCode -Detail $snip | Out-Null
    }
}

function Invoke-ChocolateyUpdate {
    if (-not (Test-CommandExists 'choco')) {
        New-OpResult -Manager 'chocolatey' -Operation 'discover' -Status 'SKIPPED_NOT_INSTALLED' -Detail 'choco not found' | Out-Null
        return
    }
    if (-not (Test-ManagerEnabled 'chocolatey')) {
        New-OpResult -Manager 'chocolatey' -Operation 'filter' -Status 'SKIPPED_NOT_INSTALLED' -Detail 'filtered by Only/Skip/Fast/config' | Out-Null
        return
    }
    if (-not $script:IsElevated) {
        New-OpResult -Manager 'chocolatey' -Operation 'upgrade-all' -Status 'SKIPPED_PERMISSION' -Detail 'Chocolatey typically needs admin; rerun elevated or schedule as admin user' | Out-Null
        return
    }
    # Inventory probe — never call choco upgrade <id> for packages not listed here.
    $list = Invoke-External -FilePath 'choco' -ArgumentList @('list', '--local-only', '--limit-output') -DisableRetry -SuccessExitCodes @(0)
    if (-not $list -or $list.ExitCode -ne 0) {
        $status = if (Test-PatchingTransientFailure -ExitCode $list.ExitCode -Output $list.Output) { 'FAILED_SOURCE_UNAVAILABLE' } else { 'FAILED_PACKAGE_OPERATION' }
        New-OpResult -Manager 'chocolatey' -Operation 'list' -Status $status -ExitCode $list.ExitCode | Out-Null
        return
    }
    $packages = @()
    foreach ($line in ($list.Output -split "`r?`n")) {
        if ($line -match '^([^|]+)\|') {
            $id = $Matches[1].Trim()
            if ($id -and $id -ne 'chocolatey') { $packages += $id }
        }
    }
    Write-PatchLog ("Chocolatey inventory: {0} packages" -f $packages.Count)
    if ($Audit -or $DryRun) {
        New-OpResult -Manager 'chocolatey' -Operation 'audit' -Status 'ALREADY_CURRENT' -Detail ("Would upgrade inventory ({0} pkgs) via choco upgrade all" -f $packages.Count) | Out-Null
        return
    }
    if ($packages.Count -eq 0) {
        New-OpResult -Manager 'chocolatey' -Operation 'upgrade-all' -Status 'ALREADY_CURRENT' -Detail 'Empty inventory' | Out-Null
        return
    }
    # upgrade all = Chocolatey's inventory; do not pass ad-hoc package IDs.
    $r = Invoke-External -FilePath 'choco' -ArgumentList @('upgrade', 'all', '-y', '--no-progress', '--limit-output') `
        -TimeoutSec ([int]$script:Config.CommandTimeoutSec) -SuccessExitCodes @(0, 1)
    if ($r.ExitCode -in @(0, 1)) {
        New-OpResult -Manager 'chocolatey' -Operation 'upgrade-all' -Status 'UPDATED' -ExitCode $r.ExitCode -Detail 'choco upgrade all (installed inventory only)' | Out-Null
    }
    elseif (Test-PatchingTransientFailure -ExitCode $r.ExitCode -Output $r.Output) {
        New-OpResult -Manager 'chocolatey' -Operation 'upgrade-all' -Status 'FAILED_SOURCE_UNAVAILABLE' -ExitCode $r.ExitCode -Attempt $r.Attempt -Detail 'e.g. HTTP 504 / source timeout' | Out-Null
    }
    elseif ("$($r.Output)" -match 'Access is denied|locked|Unable to obtain lock') {
        New-OpResult -Manager 'chocolatey' -Operation 'upgrade-all' -Status 'FAILED_PERMISSION' -ExitCode $r.ExitCode -Detail 'Lock/permission failure — do not delete .chocolatey locks without evidence' | Out-Null
    }
    else {
        New-OpResult -Manager 'chocolatey' -Operation 'upgrade-all' -Status 'FAILED_PACKAGE_OPERATION' -ExitCode $r.ExitCode | Out-Null
    }
}

function Invoke-ScoopUpdate {
    if (-not (Test-CommandExists 'scoop')) {
        New-OpResult -Manager 'scoop' -Operation 'discover' -Status 'SKIPPED_NOT_INSTALLED' -Detail 'scoop not found' | Out-Null
        return
    }
    if (-not (Test-ManagerEnabled 'scoop')) {
        New-OpResult -Manager 'scoop' -Operation 'filter' -Status 'SKIPPED_NOT_INSTALLED' -Detail 'filtered' | Out-Null
        return
    }
    if ($Audit -or $DryRun) {
        New-OpResult -Manager 'scoop' -Operation 'audit' -Status 'ALREADY_CURRENT' -Detail 'Would run: scoop update; scoop update *' | Out-Null
        return
    }
    $u1 = Invoke-External -FilePath 'scoop' -ArgumentList @('update') -TimeoutSec 300 -SuccessExitCodes @(0)
    if ($u1.ExitCode -ne 0) {
        $st = if (Test-PatchingTransientFailure -ExitCode $u1.ExitCode -Output $u1.Output) { 'FAILED_SOURCE_UNAVAILABLE' } else { 'FAILED_PACKAGE_OPERATION' }
        New-OpResult -Manager 'scoop' -Operation 'update-scoop' -Status $st -ExitCode $u1.ExitCode | Out-Null
        return
    }
    $u2 = Invoke-External -FilePath 'scoop' -ArgumentList @('update', '*') -TimeoutSec ([int]$script:Config.CommandTimeoutSec) -SuccessExitCodes @(0)
    if ($u2.ExitCode -eq 0) {
        New-OpResult -Manager 'scoop' -Operation 'update-apps' -Status 'UPDATED' -ExitCode 0 | Out-Null
    }
    elseif (Test-PatchingTransientFailure -ExitCode $u2.ExitCode -Output $u2.Output) {
        New-OpResult -Manager 'scoop' -Operation 'update-apps' -Status 'FAILED_SOURCE_UNAVAILABLE' -ExitCode $u2.ExitCode | Out-Null
    }
    else {
        New-OpResult -Manager 'scoop' -Operation 'update-apps' -Status 'FAILED_PACKAGE_OPERATION' -ExitCode $u2.ExitCode | Out-Null
    }
}

function Invoke-NativeSelfUpdates {
    $targets = @(
        @{ Cmd = 'uv'; Enabled = [bool]$script:Config.EnableUvSelfUpdate; Args = @('self', 'update'); ChocoId = 'uv' },
        @{ Cmd = 'bun'; Enabled = [bool]$script:Config.EnableBunSelfUpdate; Args = @('upgrade'); ChocoId = 'bun' },
        @{ Cmd = 'mise'; Enabled = [bool]$script:Config.EnableMiseSelfUpdate; Args = @('self-update', '--yes'); ChocoId = 'mise' }
    )
    foreach ($t in $targets) {
        $name = $t.Cmd
        if (-not $t.Enabled) { continue }
        if (-not (Test-ManagerEnabled $name)) { continue }
        $owner = Resolve-SelfUpdateOwner -CommandName $name -ChocoPackageId $t.ChocoId
        if ($owner.Action -ne 'native') {
            New-OpResult -Manager $name -Operation 'self-update' -Status $owner.Status -Detail $owner.Detail | Out-Null
            continue
        }
        if ($Audit -or $DryRun) {
            New-OpResult -Manager $name -Operation 'self-update' -Status 'ALREADY_CURRENT' -Detail ("Would run native self-update ($($owner.Detail))") | Out-Null
            continue
        }
        $r = Invoke-External -FilePath $name -ArgumentList $t.Args -TimeoutSec 300 -SuccessExitCodes @(0)
        if ($r.ExitCode -eq 0) {
            New-OpResult -Manager $name -Operation 'self-update' -Status 'UPDATED' -ExitCode 0 -Detail $owner.Detail | Out-Null
        }
        elseif (Test-PatchingTransientFailure -ExitCode $r.ExitCode -Output $r.Output) {
            New-OpResult -Manager $name -Operation 'self-update' -Status 'FAILED_SOURCE_UNAVAILABLE' -ExitCode $r.ExitCode | Out-Null
        }
        else {
            New-OpResult -Manager $name -Operation 'self-update' -Status 'FAILED_PACKAGE_OPERATION' -ExitCode $r.ExitCode | Out-Null
        }
    }
}

# --- main ---
$script:IsElevated = Test-IsAdmin
if (-not $PSBoundParameters.ContainsKey('AutoElevate')) {
    # Hybrid default: try AutoElevate when not elevated and not opted out.
    $AutoElevate = -not $NoElevate
}
$script:Config = Get-PatchingConfig -Path $ConfigPath
if ($Only.Count -eq 1 -and $Only[0] -match ',') { $Only = @($Only[0] -split ',') }
if ($Skip.Count -eq 1 -and $Skip[0] -match ',') { $Skip = @($Skip[0] -split ',') }

if ($AutoElevate -and -not $NoElevate -and -not $script:IsElevated) {
    Invoke-SelfElevation | Out-Null
}

$logRoot = Initialize-Logging
Write-PatchLog ("Mode DryRun={0} Audit={1} Fast={2} Elevated={3}" -f $DryRun, $Audit, $Fast, $script:IsElevated)

$deadline = $script:StartTime.AddSeconds([int]$script:Config.BoundedRunTimeoutSec)

Invoke-WingetUpdate
if ((Get-Date) -gt $deadline) { Write-PatchLog 'Bounded run timeout reached' 'WARN' }
else {
    Invoke-ChocolateyUpdate
    Invoke-ScoopUpdate
    Invoke-NativeSelfUpdates
}

Show-Summary
Save-JsonReport -LogRoot $logRoot | Out-Null

$failCount = @($script:Results | Where-Object { $_.Status -like 'FAILED_*' }).Count
if ($failCount -gt 0) {
    exit 2
}
exit 0
