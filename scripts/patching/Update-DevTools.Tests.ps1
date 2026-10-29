#Requires -Version 5.1
# Mocked unit tests — no live package-manager calls.
# Requires Pester 5+: Import-Module Pester -MinimumVersion 5.0

BeforeAll {
    $script:PatchingRoot = $PSScriptRoot
    . (Join-Path $script:PatchingRoot 'Patching.Lib.ps1')
}

Describe 'Patching.Lib ownership' {
    It 'skips native self-update when path is under Chocolatey' {
        $r = Resolve-PatchingSelfUpdateAction -CommandPath 'C:\ProgramData\chocolatey\bin\uv.exe'
        $r.Action | Should -Be 'skip'
        $r.Status | Should -Be 'SKIPPED_OWNERSHIP_AMBIGUOUS'
    }

    It 'skips when Chocolatey lists package but PATH is outside manager roots' {
        $r = Resolve-PatchingSelfUpdateAction -CommandPath 'C:\Users\dev\.local\bin\uv.exe' -ListedInChocolatey $true -ChocoPackageId 'uv'
        $r.Action | Should -Be 'skip'
        $r.Status | Should -Be 'SKIPPED_OWNERSHIP_AMBIGUOUS'
    }

    It 'allows native self-update for standalone path not listed in Chocolatey' {
        $r = Resolve-PatchingSelfUpdateAction -CommandPath 'C:\Users\dev\.local\bin\uv.exe' -ListedInChocolatey $false
        $r.Action | Should -Be 'native'
        $r.Status | Should -Be 'OK'
    }

    It 'returns SKIPPED_NOT_INSTALLED for empty path' {
        $r = Resolve-PatchingSelfUpdateAction -CommandPath ''
        $r.Status | Should -Be 'SKIPPED_NOT_INSTALLED'
    }
}

Describe 'Patching.Lib failure classification' {
    It 'detects Chocolatey-style HTTP 504 as transient' {
        $out = "504 (Gateway Timeout)`nNeed to add specific handling for exception type NuGetResolverInputException"
        Test-PatchingTransientFailure -ExitCode 1 -Output $out | Should -Be $true
    }

    It 'does not treat access denied as transient' {
        Test-PatchingTransientFailure -ExitCode 1 -Output 'Access is denied' | Should -Be $false
        Test-PatchingPermanentFailure -Output 'Access is denied' | Should -Be $true
    }

    It 'retries only while attempts remain and failure is transient' {
        Test-PatchingShouldRetry -Attempt 1 -MaxRetries 3 -Transient $true -Permanent $false | Should -Be $true
        Test-PatchingShouldRetry -Attempt 3 -MaxRetries 3 -Transient $true -Permanent $false | Should -Be $false
        Test-PatchingShouldRetry -Attempt 1 -MaxRetries 3 -Transient $true -Permanent $true | Should -Be $false
    }
}

Describe 'Update-DevTools.ps1 safety contracts' {
    BeforeAll {
        $script:Src = Get-Content -LiteralPath (Join-Path $script:PatchingRoot 'Update-DevTools.ps1') -Raw
        $script:Cfg = Get-Content -LiteralPath (Join-Path $script:PatchingRoot 'update-config.json') -Raw | ConvertFrom-Json
    }

    It 'uses choco upgrade all for inventory, not ad-hoc package install recovery' {
        $script:Src | Should -Match "upgrade', 'all'"
        $script:Src | Should -Not -Match 'CrossManagerFallback'
        $script:Src | Should -Match '--local-only'
    }

    It 'records FAILED_SOURCE_UNAVAILABLE for transient source failures' {
        $script:Src | Should -Match 'FAILED_SOURCE_UNAVAILABLE'
        $script:Src | Should -Match 'do not delete \.chocolatey locks'
    }

    It 'does not enable winget --include-unknown by default' {
        $script:Cfg.WingetIncludeUnknown | Should -Be $false
    }
}
