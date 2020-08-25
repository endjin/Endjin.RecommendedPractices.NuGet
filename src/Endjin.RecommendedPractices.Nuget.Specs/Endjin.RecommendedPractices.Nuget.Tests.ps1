$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "Here: $here"

$recommendedPracticesDir = Resolve-Path (Join-Path $here "../Endjin.RecommendedPractices.Nuget")
$recommendPracticesNuspec = Resolve-Path (Join-Path $recommendedPracticesDir "Endjin.RecommendedPractices.nuspec")
$specsSlnDir = Resolve-Path (Join-Path $here "Solution")
$specsSln = Resolve-Path (Join-Path $specsSlnDir "Endjin.RecommendedPractices.Nuget.Specs.sln")
$packageOutputDir = Resolve-Path (Join-Path $here "../packages")

Write-Host "Recommended Practices directory: $recommendedPracticesDir"
Write-Host "Recommended Practices nuspec: $recommendPracticesNuspec"
Write-Host "Specs solution directory: $specsSlnDir"
Write-Host "Specs solution: $specsSln"
Write-Host "Package output directory: $packageOutputDir"

# Clear down anything left from previous run
Remove-Item $packageOutputDir -Force -Recurse -ErrorAction SilentlyContinue
@(".editorconfig","PackageIcon.png","stylecop.json","StyleCop.ruleset") | ForEach-Object { Join-Path $specsSlnDir $_ } | Remove-Item -Force -ErrorAction SilentlyContinue
Remove-Item "$env:userprofile\.nuget\packages\endjin.recommendedpractices\0.0.1-local" -Force -Recurse -ErrorAction SilentlyContinue

Describe 'Packaging tests' {

    nuget sources Add -Name "EndjinRecommendedPracticesLocal" -Source $packageOutputDir

    nuget pack $recommendPracticesNuspec -Version "0.0.1-local" -OutputDirectory $packageOutputDir -NoDefaultExcludes

    dotnet build $specsSln /p:Configuration=Release
    dotnet pack (Join-Path $specsSlnDir "SingleFramework/SingleFramework.csproj") --no-build --output $packageOutputDir /p:Configuration=Release /p:EndjinRepositoryUrl="https://github.com/endjin/Endjin.RecommendedPractices" /p:PackageVersion=0.0.1-local
    dotnet pack (Join-Path $specsSlnDir "MultiFramework/MultiFramework.csproj") --no-build --output $packageOutputDir /p:Configuration=Release /p:EndjinRepositoryUrl="https://github.com/endjin/Endjin.RecommendedPractices" /p:PackageVersion=0.0.1-local

    nuget sources Remove -Name "EndjinRecommendedPracticesLocal"

    It 'should create a nupkg file for the SingleFramework project' {
        (Join-Path $packageOutputDir "SingleFramework.0.0.1-local.nupkg") | Should -Exist
    }

    It 'should create a snupkg file for the SingleFramework project' {
        (Join-Path $packageOutputDir "SingleFramework.0.0.1-local.snupkg") | Should -Exist
    }

    It 'should create a nupkg file for the MultiFramework project' {
        (Join-Path $packageOutputDir "MultiFramework.0.0.1-local.nupkg") | Should -Exist
    }

    It 'should create a snupkg file for the MultiFramework project' {
        (Join-Path $packageOutputDir "MultiFramework.0.0.1-local.snupkg") | Should -Exist
    }
}