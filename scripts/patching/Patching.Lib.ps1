# Shared helpers for Update-DevTools.ps1 (dot-sourced). Safe to load in Pester.
Set-StrictMode -Version Latest

function Test-PatchingTransientFailure {
    param(
        [AllowNull()][object]$ExitCode,
        [string]$Output
    )
    $text = "$Output"
    if ($text -match '504|Gateway Timeout|timed out|timeout|Unable to connect|connection.*(reset|refused)|temporar|TRY AGAIN|NuGetResolverInputException') {
        return $true
    }
    return $false
}

function Test-PatchingPermanentFailure {
    param([string]$Output)
    $text = "$Output"
    return [bool]($text -match 'Access is denied|AccessDenied|not recognized as|Invalid|pinned|No applicable update|package is pinned')
}

function Get-PatchingPathManagerHints {
    param([string]$Path)
    $hints = [System.Collections.Generic.List[string]]::new()
    if (-not $Path) { return @() }
    $p = $Path.ToLowerInvariant()
    if ($p -match '\\chocolatey\\') { $hints.Add('chocolatey') }
    if ($p -match '\\scoop\\') { $hints.Add('scoop') }
    if ($p -match '\\winget\\packages\\' -or $p -match '\\microsoft\\winget\\') { $hints.Add('winget') }
    if ($p -match '\\mise\\' -or $p -match '\\.local\\share\\mise\\') { $hints.Add('mise') }
    return @($hints | Select-Object -Unique)
}

function Resolve-PatchingSelfUpdateAction {
    param(
        [AllowEmptyString()][string]$CommandPath,
        [string[]]$PathHints = @(),
        [bool]$ListedInChocolatey = $false,
        [string]$ChocoPackageId = ''
    )
    if (-not $CommandPath) {
        return [pscustomobject]@{ Action = 'skip'; Status = 'SKIPPED_NOT_INSTALLED'; Detail = 'not on PATH' }
    }
    if (-not $PathHints -or $PathHints.Count -eq 0) {
        $PathHints = @(Get-PatchingPathManagerHints $CommandPath)
    }
    if ($PathHints -contains 'chocolatey' -or $PathHints -contains 'scoop' -or $PathHints -contains 'winget') {
        return [pscustomobject]@{
            Action = 'skip'
            Status = 'SKIPPED_OWNERSHIP_AMBIGUOUS'
            Detail = "Path under manager root ($($PathHints -join ','))"
        }
    }
    if ($ListedInChocolatey -and $PathHints.Count -eq 0) {
        return [pscustomobject]@{
            Action = 'skip'
            Status = 'SKIPPED_OWNERSHIP_AMBIGUOUS'
            Detail = "Chocolatey lists '$ChocoPackageId' but PATH is outside Chocolatey"
        }
    }
    if ($PathHints.Count -gt 1) {
        return [pscustomobject]@{
            Action = 'skip'
            Status = 'SKIPPED_OWNERSHIP_AMBIGUOUS'
            Detail = "Multiple path hints: $($PathHints -join ',')"
        }
    }
    return [pscustomobject]@{ Action = 'native'; Status = 'OK'; Detail = $CommandPath }
}

function Test-PatchingShouldRetry {
    param(
        [int]$Attempt,
        [int]$MaxRetries,
        [bool]$Transient,
        [bool]$Permanent
    )
    if ($Permanent) { return $false }
    if (-not $Transient) { return $false }
    return ($Attempt -lt $MaxRetries)
}
