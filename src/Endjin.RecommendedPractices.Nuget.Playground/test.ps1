$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

$recommendedPracticesDir = Join-Path $here "../Endjin.RecommendedPractices.Nuget"
$recommendPracticesNuspec = Join-Path $recommendedPracticesDir "Endjin.RecommendedPractices.nuspec"

$playgroundSln = Join-Path $here "Endjin.RecommendedPractices.Nuget.Playground.sln"

$packageOutputDir = Join-Path $here "../packages"

Remove-Item $packageOutputDir -Force -Recurse -ErrorAction SilentlyContinue

nuget pack $recommendPracticesNuspec -Version "0.0.1-local" -OutputDirectory $packageOutputDir -NoDefaultExcludes

nuget sources Add -Name "EndjinRecommendedPracticesLocal" -Source $packageOutputDir

Remove-Item "$env:userprofile\.nuget\packages\endjin.recommendedpractices\0.0.1-local" -Force -Recurse -ErrorAction SilentlyContinue

dotnet build $playgroundSln /p:Configuration=Release

dotnet pack (Join-Path $here "SingleFramework/SingleFramework.csproj") --no-build --output $packageOutputDir /p:Configuration=Release /p:EndjinRepositoryUrl="https://github.com/endjin/Endjin.RecommendedPractices" /p:PackageVersion=0.0.1-local
dotnet pack (Join-Path $here "MultiFramework/MultiFramework.csproj") --no-build --output $packageOutputDir /p:Configuration=Release /p:EndjinRepositoryUrl="https://github.com/endjin/Endjin.RecommendedPractices" /p:PackageVersion=0.0.1-local

nuget sources Remove -Name "EndjinRecommendedPracticesLocal"