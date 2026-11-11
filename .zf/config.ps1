<#
Endjin.RecommendedPractices build process.

This repository has no .NET solution to compile: it ships two NuGet packages made from .nuspec
files and MSBuild .props/.targets. So the build uses only parts of 'ZeroFailed.Build.DotNet':
- Test:    runs the Pester specs (src/Endjin.RecommendedPractices.Nuget.Specs), which pack the
           packages locally and build a sample solution against them.
- Package: packs both .nuspec files, versioned by GitVersion, into $PackagesDir.
- Publish: pushes the packages to $NugetPublishSource and creates a GitHub release with the
           packages attached ('ZeroFailed.Build.GitHub').
#>

$zerofailedExtensions = @(
    @{
        # References the extension from its GitHub repository. If not already installed, use latest version from 'main' will be downloaded.
        Name = "ZeroFailed.Build.DotNet"
        GitRepository = "https://github.com/zerofailed/ZeroFailed.Build.DotNet"
        GitRef = "main"
    }
    @{
        # Creates the GitHub release and attaches the NuGet packages to it (the Publish stage).
        Name = "ZeroFailed.Build.GitHub"
        GitRepository = "https://github.com/zerofailed/ZeroFailed.Build.GitHub"
        GitRef = "main"
    }
)

# Load the tasks and process
. ZeroFailed.tasks -ZfPath $here/.zf

#
# Build process control options
#
$SkipInit = $false
$SkipVersion = $false
$SkipBuild = $false
$CleanBuild = $Clean
$SkipTest = $false
$SkipTestReport = $false
$SkipAnalysis = $false
$SkipPackage = $false
# The Publish stage runs only when the entry task is FullBuildAndPublish, which CI uses for tag
# builds (and for a manual run with forcePublish).
$SkipPublish = $false

#
# Build process configuration
#

# No solution: $SolutionToBuild stays unset, which turns off the .NET extension's compile, test,
# Covenant SBOM, project packaging and NuGet publishing tasks.
$NuSpecFilesToPackage = @(
    "$here/src/Endjin.RecommendedPractices.NuGet/Endjin.RecommendedPractices.nuspec"
    "$here/src/Endjin.RecommendedPractices.NuGet.GitHub/Endjin.RecommendedPractices.GitHub.nuspec"
)

# Publishing. CI sets ZF_NUGET_PUBLISH_SOURCE to nuget.org and NUGET_API_KEY from a secret; a local
# 'FullBuildAndPublish' pushes to a folder feed instead. (This environment variable is defined by
# this file, not by ZeroFailed.)
$NugetPublishSource = property ZF_NUGET_PUBLISH_SOURCE "$here/_local-nuget-feed"

# The GitHub release gets the packages matching $NugetPackageNamesToPublishGlob
# ('*.<SemVer>.nupkg' in $PackagesDir by default). Only a GitHub Actions run creates a release, so
# a local 'FullBuildAndPublish' cannot. Dry-run mode (ZF_GITHUB_RELEASE_DRY_RUN_MODE=true) runs the
# task anywhere without creating or uploading anything.
$PublishNuGetPackagesAsGitHubReleaseArtefacts = $true
$CreateGitHubRelease = ($env:GITHUB_ACTIONS -eq 'true') -or $GitHubReleaseDryRunMode

# Synopsis: Test and Package
task . FullBuild

#
# Build Process Extensibility Points - uncomment and implement as required
#

# task RunFirst {}
# task PreInit {}
# task PostInit {}
# task PreVersion {}
# task PostVersion {}
# task PreBuild {}
# task PostBuild {}
# task PreTest {}
# task PostTest {}
# task PreTestReport {}
# task PostTestReport {}
# task PreAnalysis {}
# task PostAnalysis {}
# task PrePackage {}
# task PostPackage {}
# task PrePublish {}
# task PostPublish {}
# task RunLast {}

# Synopsis: Runs the Pester specs. They pack both packages (as version 0.0.1-local), then build
# and pack a sample solution that references them. run-tests.ps1 exits non-zero if any spec fails.
task RunPesterSpecs -After TestCore -If { !$SkipTest } {
    exec {
        & pwsh -NoProfile -File (Join-Path $here "src/Endjin.RecommendedPractices.Nuget.Specs/run-tests.ps1")
    }
}

# Synopsis: Pushes the packages built from the .nuspec files to $NugetPublishSource.
# ZeroFailed.Build.DotNet's own PublishNuGetPackages task only runs when $SolutionToBuild is set,
# and this repository has no solution, so this task does the equivalent push.
task PublishNuSpecPackages -After PublishCore -If { !$SkipPublish } Version,EnsurePackagesDir,{
    $glob = Resolve-Value $NugetPackageNamesToPublishGlob
    $packages = @(Get-ChildItem -Path $PackagesDir -Filter $glob)
    if (!$packages) {
        throw "No packages matching '$glob' were found in '$PackagesDir' to publish."
    }

    $apiKey = $env:NUGET_API_KEY ? $env:NUGET_API_KEY : "no-key"
    if (([uri]$NugetPublishSource).Scheme -ne 'file' -and $apiKey -eq "no-key") {
        Write-Warning "No value was found in the 'NUGET_API_KEY' environment variable, publishing may fail."
    }
    if ((Test-Path $NugetPublishSource -IsValid) -and !(Test-Path $NugetPublishSource)) {
        New-Item -ItemType Directory $NugetPublishSource | Out-Null
    }

    foreach ($package in $packages) {
        Write-Build Green "Publishing $($package.Name) to $NugetPublishSource"
        exec {
            & dotnet nuget push $package.FullName --source $NugetPublishSource --api-key $apiKey --skip-duplicate
        }
    }
}
