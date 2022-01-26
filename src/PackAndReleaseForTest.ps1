[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $Version,
    [Parameter()]
    [string]
    $LocalRepository = "C:\dev\NuGetLocal"
)

nuget pack .\Endjin.RecommendedPractices.NuGet\Endjin.RecommendedPractices.nuspec -NoDefaultExcludes -Version $Version
nuget pack .\Endjin.RecommendedPractices.NuGet.GitHub\Endjin.RecommendedPractices.GitHub.nuspec -Version $Version
nuget add Endjin.RecommendedPractices.$Version.nupkg -source $LocalRepository
nuget add Endjin.RecommendedPractices.GitHub.$Version.nupkg -source $LocalRepository
