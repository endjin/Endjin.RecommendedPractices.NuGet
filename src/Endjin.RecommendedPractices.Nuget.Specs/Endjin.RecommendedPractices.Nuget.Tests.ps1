# Pester 6 tests (run by run-tests.ps1). Pester 5 and later separate discovery from execution,
# so all setup lives in BeforeAll: code placed directly in a Describe block would run during
# discovery, before (and separately from) the tests.

BeforeAll {
    $ErrorActionPreference = 'Stop'

    $here = $PSScriptRoot
    $recommendedPracticesNuspec = Resolve-Path (Join-Path $here "../Endjin.RecommendedPractices.NuGet/Endjin.RecommendedPractices.nuspec")
    $recommendedPracticesGitHubNuspec = Resolve-Path (Join-Path $here "../Endjin.RecommendedPractices.NuGet.GitHub/Endjin.RecommendedPractices.GitHub.nuspec")
    $specsSlnDir = Resolve-Path (Join-Path $here "Solution")
    $specsSln = Resolve-Path (Join-Path $specsSlnDir "Endjin.RecommendedPractices.Nuget.Specs.sln")
    $singleFrameworkProject = Join-Path $specsSlnDir "SingleFramework/SingleFramework.csproj"
    $multiFrameworkProject = Join-Path $specsSlnDir "MultiFramework/MultiFramework.csproj"
    $packageOutputDir = Join-Path $here "../packages"

    Write-Host "Recommended Practices nuspec: $recommendedPracticesNuspec"
    Write-Host "Recommended Practices GitHub nuspec: $recommendedPracticesGitHubNuspec"
    Write-Host "Specs solution: $specsSln"
    Write-Host "Package output directory: $packageOutputDir"

    function Invoke-DotNet {
        Write-Host "`nRunning: dotnet $($args -join ' ')`n"
        & dotnet @args | Write-Host
        if ($LASTEXITCODE -ne 0) {
            throw "dotnet $($args -join ' ') failed with exit code $LASTEXITCODE"
        }
    }

    function Get-PackageEntryNames {
        param ([string] $packagePath)

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::OpenRead($packagePath)
        try {
            $zip.Entries | ForEach-Object { $_.FullName }
        }
        finally {
            $zip.Dispose()
        }
    }

    function Get-PackageEntryText {
        param ([string] $packagePath, [string] $entryName)

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::OpenRead($packagePath)
        try {
            $entry = $zip.Entries | Where-Object { $_.FullName -eq $entryName }
            $reader = New-Object System.IO.StreamReader($entry.Open())
            try {
                $reader.ReadToEnd()
            }
            finally {
                $reader.Dispose()
            }
        }
        finally {
            $zip.Dispose()
        }
    }

    function Get-AnalyzerPackageIds {
        param ([string[]] $extraArguments = @())

        # ResolveLockFileAnalyzers produces the Analyzer items that are passed to the compiler,
        # after the package's opt-out target (if enabled) has removed any.
        $json = dotnet msbuild $singleFrameworkProject -nologo -tl:off -t:ResolveLockFileAnalyzers -getItem:Analyzer /p:Configuration=Release @extraArguments
        if ($LASTEXITCODE -ne 0) {
            throw "dotnet msbuild -getItem:Analyzer failed with exit code $LASTEXITCODE"
        }
        $items = ($json | Out-String | ConvertFrom-Json).Items.Analyzer
        @($items | ForEach-Object { $_.NuGetPackageId } | Sort-Object -Unique)
    }

    # Clear down anything left from previous run, including both locally built packages in the
    # global packages folder (otherwise restore keeps using the copies from an earlier run), and
    # the solution-level files the package creates, so we test a clean first build.
    Remove-Item $packageOutputDir -Force -Recurse -ErrorAction SilentlyContinue
    $packageOutputDir = (New-Item -ItemType Directory -Force -Path $packageOutputDir).FullName
    @(".editorconfig", "PackageIcon.png", "stylecop.json") |
        ForEach-Object { Join-Path $specsSlnDir $_ } |
        Remove-Item -Force -ErrorAction SilentlyContinue
    $globalPackagesDir = if ($env:NUGET_PACKAGES) { $env:NUGET_PACKAGES } else { Join-Path $HOME ".nuget/packages" }
    @("endjin.recommendedpractices", "endjin.recommendedpractices.github") |
        ForEach-Object { Join-Path $globalPackagesDir "$_/0.0.1-local" } |
        Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

    # MSBuild's reusable worker processes cache the .props/.targets files they import, and treat
    # files in the NuGet packages folder as unchanging. Because every run repacks the packages as
    # 0.0.1-local, a worker left over from an earlier build can apply the previous run's files. So
    # stop any running build servers, and don't leave new ones behind.
    Invoke-DotNet build-server shutdown
    $env:MSBUILDDISABLENODEREUSE = '1'

    # Restore the specs solution from the locally built packages (and nuget.org, for their
    # dependencies) using a config file passed on the command line, so we don't change the
    # user's or build agent's NuGet configuration.
    $nugetConfig = Join-Path ([System.IO.Path]::GetTempPath()) "Endjin.RecommendedPractices.Specs.nuget.config"
    @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="EndjinRecommendedPracticesLocal" value="$packageOutputDir" />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
  </packageSources>
</configuration>
"@ | Set-Content -Path $nugetConfig -Encoding utf8
    Write-Host "NuGet config: $nugetConfig"

    # Packing a .nuspec directly needs the .NET 10 SDK or later.
    Invoke-DotNet pack $recommendedPracticesNuspec --version 0.0.1-local --output $packageOutputDir
    Invoke-DotNet pack $recommendedPracticesGitHubNuspec --version 0.0.1-local --output $packageOutputDir

    Invoke-DotNet restore $specsSln --configfile $nugetConfig
    Invoke-DotNet build $specsSln --no-restore /p:Configuration=Release
    Invoke-DotNet pack $singleFrameworkProject --no-build --output $packageOutputDir /p:Configuration=Release /p:PackageVersion=0.0.1-local
    Invoke-DotNet pack $multiFrameworkProject --no-build --output $packageOutputDir /p:Configuration=Release /p:PackageVersion=0.0.1-local
}

Describe 'Endjin.RecommendedPractices package' {

    It 'includes the default .editorconfig' {
        $names = Get-PackageEntryNames (Join-Path $packageOutputDir "Endjin.RecommendedPractices.0.0.1-local.nupkg")
        $names | Should -Contain 'build/default.editorconfig'
        $names | Should -Contain 'buildMultiTargeting/default.editorconfig'
    }

    It 'depends on the StyleCop and Roslynator analyzers' {
        $nuspec = Get-PackageEntryText (Join-Path $packageOutputDir "Endjin.RecommendedPractices.0.0.1-local.nupkg") "Endjin.RecommendedPractices.nuspec"
        $nuspec | Should -Match 'id="StyleCop\.Analyzers"'
        $nuspec | Should -Match 'id="Roslynator\.Analyzers"'
    }
}

Describe 'Building the specs solution' {

    It 'copies the default <_> to the solution folder' -ForEach @('.editorconfig', 'stylecop.json', 'PackageIcon.png') {
        (Join-Path $specsSlnDir $_) | Should -Exist
    }

    It 'creates a <_> file for the SingleFramework project' -ForEach @('nupkg', 'snupkg') {
        (Join-Path $packageOutputDir "SingleFramework.0.0.1-local.$_") | Should -Exist
    }

    It 'creates a <_> file for the MultiFramework project' -ForEach @('nupkg', 'snupkg') {
        (Join-Path $packageOutputDir "MultiFramework.0.0.1-local.$_") | Should -Exist
    }

    # The specs projects reference Endjin.RecommendedPractices.GitHub, and this repository is on
    # GitHub. Both are packed with --no-build, which skips Compile; MultiFramework's package is also
    # created in the outer (multi-targeting) build, where Compile never runs.
    It 'sets the GitHub project URL and release notes in the <_> package' -ForEach @('SingleFramework', 'MultiFramework') {
        $nuspec = Get-PackageEntryText (Join-Path $packageOutputDir "$_.0.0.1-local.nupkg") "$_.nuspec"
        $nuspec | Should -Match '<projectUrl>https://github\.com/[^/<]+/[^/<]+</projectUrl>'
        $nuspec | Should -Match '<releaseNotes>See https://github\.com/[^/<]+/[^/<]+/releases/</releaseNotes>'
    }

    It 'does not make the SingleFramework package depend on the development-only packages' {
        $nuspec = Get-PackageEntryText (Join-Path $packageOutputDir "SingleFramework.0.0.1-local.nupkg") "SingleFramework.nuspec"
        $nuspec | Should -Not -Match 'id="Endjin\.RecommendedPractices'
        $nuspec | Should -Not -Match 'id="StyleCop\.Analyzers"'
        $nuspec | Should -Not -Match 'id="Roslynator\.Analyzers"'
    }
}

Describe 'Code analyzers' {

    It 'passes the StyleCop and Roslynator analyzers to the compiler' {
        $ids = Get-AnalyzerPackageIds
        $ids | Should -Contain 'StyleCop.Analyzers'
        $ids | Should -Contain 'Roslynator.Analyzers'
    }

    It 'removes the StyleCop and Roslynator analyzers when EndjinDisableCodeAnalysis is true' {
        $ids = Get-AnalyzerPackageIds @('/p:EndjinDisableCodeAnalysis=true')
        $ids | Should -Not -Contain 'StyleCop.Analyzers'
        $ids | Should -Not -Contain 'Roslynator.Analyzers'
    }
}
