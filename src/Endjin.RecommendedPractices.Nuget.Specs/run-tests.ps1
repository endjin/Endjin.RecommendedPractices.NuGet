$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $PSCommandPath
$pesterVer = '4.10.1'

try {
    [array]$existingModule = Get-Module -ListAvailable Pester
    if (!$existingModule -or ($existingModule.Version -notcontains $pesterVer)) {
        # Build agents now have v5.6.1 of Pester installed, which has a different publisher
        # than earlier versions. This means that the -SkipPublisherCheck flag is required to
        # avoid the error "not matching with the authenticode issuer" error.
        # REF: https://github.com/pester/Pester/issues/2438
        Install-Module Pester -RequiredVersion $pesterVer -Force -Scope CurrentUser -SkipPublisherCheck
    }
    Import-Module Pester
    $results = Invoke-Pester $here -PassThru

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