[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]
    $Version,
    [Parameter()]
    [string]
    $LocalRepository = "C:\dev\NuGetLocal"
)

# Packs both packages with the given version and adds them to a local folder feed.
# Packing a .nuspec directly needs the .NET 10 SDK or later.

$ErrorActionPreference = 'Stop'

$nuspecs = @(
    (Join-Path $PSScriptRoot "Endjin.RecommendedPractices.NuGet/Endjin.RecommendedPractices.nuspec"),
    (Join-Path $PSScriptRoot "Endjin.RecommendedPractices.NuGet.GitHub/Endjin.RecommendedPractices.GitHub.nuspec")
)
$outputDir = Join-Path $PSScriptRoot "packages"

foreach ($nuspec in $nuspecs) {
    dotnet pack $nuspec --version $Version --output $outputDir
    if ($LASTEXITCODE -ne 0) { throw "dotnet pack $nuspec failed with exit code $LASTEXITCODE" }
}

New-Item -ItemType Directory -Force -Path $LocalRepository | Out-Null
foreach ($id in @("Endjin.RecommendedPractices", "Endjin.RecommendedPractices.GitHub")) {
    $package = Join-Path $outputDir "$id.$Version.nupkg"
    dotnet nuget push $package --source $LocalRepository
    if ($LASTEXITCODE -ne 0) { throw "dotnet nuget push $package failed with exit code $LASTEXITCODE" }
}
