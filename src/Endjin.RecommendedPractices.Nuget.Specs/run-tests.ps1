$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $PSCommandPath
$pesterVer = '6.2.0'

try {
    [array]$existingModule = Get-Module -ListAvailable Pester
    if (!$existingModule -or ($existingModule.Version -notcontains $pesterVer)) {
        # Pester 5 and later are signed by a different publisher than the Pester 3.4 that ships
        # with Windows, so -SkipPublisherCheck is required to avoid the
        # "not matching with the authenticode issuer" error.
        # REF: https://github.com/pester/Pester/issues/2438
        Install-Module Pester -RequiredVersion $pesterVer -Force -Scope CurrentUser -SkipPublisherCheck
    }
    Import-Module Pester -RequiredVersion $pesterVer

    $config = New-PesterConfiguration
    $config.Run.Path = $here
    $config.Run.PassThru = $true
    $config.Output.Verbosity = 'Detailed'
    $results = Invoke-Pester -Configuration $config

    if ($results.FailedCount -gt 0) {
        Write-Host ("{0} out of {1} tests failed - check previous logging for more details" -f $results.FailedCount, $results.TotalCount)
        exit 1
    }

    $results
}
catch {
    Write-Output ("::error file={0},line={1},col={2}::{3}" -f `
                        $_.InvocationInfo.ScriptName,
                        $_.InvocationInfo.ScriptLineNumber,
                        $_.InvocationInfo.OffsetInLine,
                        $_.Exception.Message)

    exit 1
}
