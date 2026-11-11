$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "Here: $here"

$recommendedPracticesDir = Resolve-Path (Join-Path $here "../Endjin.RecommendedPractices.NuGet")
$recommendPracticesNuspec = Resolve-Path (Join-Path $recommendedPracticesDir "Endjin.RecommendedPractices.nuspec")
$recommendedPracticesGitHubDir = Resolve-Path (Join-Path $here "../Endjin.RecommendedPractices.NuGet.GitHub")
$recommendPracticesGitHubNuspec = Resolve-Path (Join-Path $recommendedPracticesGitHubDir "Endjin.RecommendedPractices.GitHub.nuspec")
$specsSlnDir = Resolve-Path (Join-Path $here "Solution")
$specsSln = Resolve-Path (Join-Path $specsSlnDir "Endjin.RecommendedPractices.Nuget.Specs.sln")
$packageOutputDir = (New-Item -ItemType Directory -Force -Path (Join-Path $here "../packages")).FullName

Write-Host "Recommended Practices directory: $recommendedPracticesDir"
Write-Host "Recommended Practices nuspec: $recommendPracticesNuspec"
Write-Host "Recommended Practices GitHub directory: $recommendedPracticesGitHubDir"
Write-Host "Recommended Practices GitHub nuspec: $recommendPracticesGitHubNuspec"
Write-Host "Specs solution directory: $specsSlnDir"
Write-Host "Specs solution: $specsSln"
Write-Host "Package output directory: $packageOutputDir"

# Clear down anything left from previous run
Remove-Item $packageOutputDir -Force -Recurse -ErrorAction SilentlyContinue
@(".editorconfig","PackageIcon.png","stylecop.json") | ForEach-Object { Join-Path $specsSlnDir $_ } | Remove-Item -Force -ErrorAction SilentlyContinue
Remove-Item "$env:userprofile\.nuget\packages\endjin.recommendedpractices\0.0.1-local" -Force -Recurse -ErrorAction SilentlyContinue

$pathToNuGet = Get-Command nuget.exe | Select-Object -ExpandProperty Source
Write-Host "Path to NuGet: $pathToNuGet"

function Invoke-NuGet {
    param (
        $command,
        $subCommand,
        $arguments
    )
    
    Write-Host "`nRunning: nuget $command $subcommand $($arguments -join ' ')`n"

    If ($IsWindows) {
        (&nuget $command $subCommand @arguments) | Write-Host
    }
    Else {
        (&mono $pathToNuGet $command $subCommand @arguments) | Write-Host
    }
}

Describe 'Packaging tests' {

    Invoke-NuGet sources Add @("-Name", 'EndjinRecommendedPracticesLocal', "-Source", $packageOutputDir)
    Invoke-NuGet pack $recommendPracticesNuspec @("-Version", '0.0.1-local', "-OutputDirectory", $packageOutputDir, "-NoDefaultExcludes")
    Invoke-NuGet pack $recommendPracticesGitHubNuspec @("-Version", '0.0.1-local', "-OutputDirectory", $packageOutputDir, "-NoDefaultExcludes")

    (dotnet build $specsSln /p:Configuration=Release) | Write-Host
    (dotnet pack (Join-Path $specsSlnDir "SingleFramework/SingleFramework.csproj") --no-build --output $packageOutputDir /p:Configuration=Release /p:EndjinRepositoryUrl="https://github.com/endjin/Endjin.RecommendedPractices" /p:PackageVersion=0.0.1-local) | Write-Host
    (dotnet pack (Join-Path $specsSlnDir "MultiFramework/MultiFramework.csproj") --no-build --output $packageOutputDir /p:Configuration=Release /p:EndjinRepositoryUrl="https://github.com/endjin/Endjin.RecommendedPractices" /p:PackageVersion=0.0.1-local) | Write-Host

    Invoke-NuGet sources Remove @("-Name", 'EndjinRecommendedPracticesLocal')

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

    It 'should not make the SingleFramework package depend on the development-only packages' {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::OpenRead((Join-Path $packageOutputDir "SingleFramework.0.0.1-local.nupkg"))
        try {
            $entry = $zip.Entries | Where-Object { $_.FullName -eq 'SingleFramework.nuspec' }
            $reader = New-Object System.IO.StreamReader($entry.Open())
            $nuspec = $reader.ReadToEnd()
            $reader.Dispose()
        }
        finally {
            $zip.Dispose()
        }

        $nuspec | Should -Not -Match 'id="Endjin\.RecommendedPractices'
        $nuspec | Should -Not -Match 'id="StyleCop\.Analyzers"'
        $nuspec | Should -Not -Match 'id="Roslynator\.Analyzers"'
    }
}

Describe 'Code analyzer tests' {

    function Get-AnalyzerPackageIds {
        param ([string[]] $extraArguments)

        # ResolveLockFileAnalyzers produces the Analyzer items that are passed to the compiler,
        # after the package's opt-out target (if enabled) has removed any.
        $json = dotnet msbuild (Join-Path $specsSlnDir "SingleFramework/SingleFramework.csproj") -nologo -tl:off -t:ResolveLockFileAnalyzers -getItem:Analyzer /p:Configuration=Release @extraArguments
        $items = ($json | Out-String | ConvertFrom-Json).Items.Analyzer
        @($items | ForEach-Object { $_.NuGetPackageId } | Sort-Object -Unique)
    }

    It 'should pass the StyleCop and Roslynator analyzers to the compiler' {
        $ids = Get-AnalyzerPackageIds @()
        $ids | Should -Contain 'StyleCop.Analyzers'
        $ids | Should -Contain 'Roslynator.Analyzers'
    }

    It 'should remove the StyleCop and Roslynator analyzers when EndjinDisableCodeAnalysis is true' {
        $ids = Get-AnalyzerPackageIds @('/p:EndjinDisableCodeAnalysis=true')
        $ids | Should -Not -Contain 'StyleCop.Analyzers'
        $ids | Should -Not -Contain 'Roslynator.Analyzers'
    }
}