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

    #
    # Scenarios: small projects, each in its own folder, built from scratch to check one behaviour.
    # They live inside this repository (so GitHub detection sees its Git repo) under a gitignored
    # folder. Each scenario folder is its project's solution folder (the project is built on its
    # own, so SolutionDir falls back to the project's parent folder), so every scenario build is a
    # clean first build with its own .editorconfig, stylecop.json and PackageIcon.png.
    #
    $scenarioRoot = Join-Path $here "Scenarios"
    Remove-Item $scenarioRoot -Force -Recurse -ErrorAction SilentlyContinue

    # A file that follows the endjin house style, ending with a single newline (default.editorconfig
    # sets insert_final_newline = true).
    $houseStyleClass = (@'
// <copyright file="Widget.cs" company="Endjin Limited">
// Copyright (c) Endjin Limited. All rights reserved.
// </copyright>

using System;

namespace Proj;

/// <summary>
/// A widget.
/// </summary>
public class Widget
{
    /// <summary>
    /// Gets the current time.
    /// </summary>
    /// <returns>The current time.</returns>
    public DateTimeOffset GetNow()
    {
        return DateTimeOffset.UtcNow;
    }
}
'@).ReplaceLineEndings("`r`n").TrimEnd() + "`r`n"

    # A console app entry point in the house style.
    $houseStyleProgram = (@'
// <copyright file="Program.cs" company="Endjin Limited">
// Copyright (c) Endjin Limited. All rights reserved.
// </copyright>

namespace Proj;

/// <summary>
/// The program.
/// </summary>
internal static class Program
{
    /// <summary>
    /// The entry point.
    /// </summary>
    private static void Main()
    {
    }
}
'@).ReplaceLineEndings("`r`n").TrimEnd() + "`r`n"

    function New-ProjectXml {
        param (
            [string] $Properties = '',
            [string] $Items = '',
            [string] $Package = 'Endjin.RecommendedPractices.GitHub',
            [string] $PackageReferenceAttributes = 'PrivateAssets="all"',
            [switch] $NoImport,
            [string] $License = '<PackageLicenseExpression>MIT</PackageLicenseExpression>'
        )

        $import = $NoImport ? '' : '<Import Project="$(EndjinProjectPropsPath)" Condition="$(EndjinProjectPropsPath) != ''''" />'
        @'
<Project Sdk="Microsoft.NET.Sdk">
  {IMPORT}
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    {LICENSE}
    {PROPERTIES}
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="{PACKAGE}" Version="0.0.1-local" {ATTRIBUTES} />
    {ITEMS}
  </ItemGroup>
</Project>
'@.Replace('{IMPORT}', $import).Replace('{LICENSE}', $License).Replace('{PROPERTIES}', $Properties).Replace('{PACKAGE}', $Package).Replace('{ATTRIBUTES}', $PackageReferenceAttributes).Replace('{ITEMS}', $Items)
    }

    # Creates a scenario folder with a project at <ProjectPath> (relative to the scenario folder,
    # e.g. 'Proj/Proj.csproj') and any extra files (written exactly as given), and returns the folder.
    function New-Scenario {
        param (
            [Parameter(Mandatory)] [string] $Name,
            [string] $ProjectXml = (New-ProjectXml),
            [string] $ProjectPath = 'Proj/Proj.csproj',
            [hashtable] $Files = @{ 'Proj/Widget.cs' = $houseStyleClass }
        )

        $dir = Join-Path $scenarioRoot $Name
        $allFiles = @{ $ProjectPath = $ProjectXml } + $Files
        foreach ($relativePath in $allFiles.Keys) {
            $path = Join-Path $dir $relativePath
            New-Item -ItemType Directory -Force -Path (Split-Path $path) | Out-Null
            [System.IO.File]::WriteAllText($path, $allFiles[$relativePath])
        }
        $dir
    }

    # Runs 'dotnet <arguments>' in a scenario folder (restoring from the locally built packages) and
    # returns its exit code and output, without failing on a non-zero exit code.
    #
    # Scenarios behave the same locally and on a CI server: the variables the package uses to
    # detect a CI server are cleared, unless the scenario sets them through -Environment.
    #
    # Scenarios build the Release configuration unless -Configuration says otherwise, because
    # that's where the package makes warnings errors (as CI and packaging do).
    function Invoke-Scenario {
        param ([string] $Dir, [string[]] $Arguments, [hashtable] $Environment = @{}, [string] $Configuration = 'Release')

        # The command (e.g. 'build') must stay first. An empty -Configuration passes none, so the
        # project's own setting (or the SDK's Debug default) applies.
        if ($Configuration) {
            $Arguments = @($Arguments[0], "-p:Configuration=$Configuration") + @($Arguments | Select-Object -Skip 1)
        }

        $variables = @{ TF_BUILD = $null; GITHUB_ACTIONS = $null }
        foreach ($name in $Environment.Keys) { $variables[$name] = $Environment[$name] }
        $saved = @{}
        foreach ($name in $variables.Keys) {
            $saved[$name] = [Environment]::GetEnvironmentVariable($name)
            [Environment]::SetEnvironmentVariable($name, $variables[$name])
        }
        Push-Location $Dir
        try {
            $output = & dotnet @Arguments -nologo -tl:off "-p:RestoreConfigFile=$nugetConfig" 2>&1 | Out-String
            [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
        }
        finally {
            Pop-Location
            foreach ($name in $saved.Keys) {
                [Environment]::SetEnvironmentVariable($name, $saved[$name])
            }
        }
    }
}

Describe 'Endjin.RecommendedPractices package' {

    It 'includes the default .editorconfig and the global analyzer config' {
        $names = Get-PackageEntryNames (Join-Path $packageOutputDir "Endjin.RecommendedPractices.0.0.1-local.nupkg")
        $names | Should -Contain 'build/default.editorconfig'
        $names | Should -Contain 'buildMultiTargeting/default.editorconfig'
        $names | Should -Contain 'build/Endjin.CodeAnalysis.globalconfig'
        $names | Should -Contain 'buildMultiTargeting/Endjin.CodeAnalysis.globalconfig'
    }

    It 'has the same C# settings in its global analyzer config and its default .editorconfig' {
        # Endjin.CodeAnalysis.globalconfig repeats the [*.{cs,csx}] section of default.editorconfig
        # (so the settings apply from the first build); the two must not drift apart.
        function Read-Settings([string[]] $lines) {
            $settings = [ordered]@{}
            foreach ($line in $lines) {
                if ($line -match '^\s*([^#;\[\s][^=]*?)\s*=\s*(.*?)\s*$') { $settings[$Matches[1]] = $Matches[2] }
            }
            $settings
        }

        $buildDir = Join-Path $here "../Endjin.RecommendedPractices.NuGet/build"
        $globalConfig = Read-Settings (Get-Content (Join-Path $buildDir "Endjin.CodeAnalysis.globalconfig"))
        $globalConfig.Remove('is_global')
        $globalConfig.Remove('global_level')

        # Only the C# section: from its header to the next section header (or the end of the file).
        $editorConfigLines = Get-Content (Join-Path $buildDir "default.editorconfig")
        $start = [array]::IndexOf($editorConfigLines, '[*.{cs,csx}]')
        $start | Should -BeGreaterThan -1 -Because 'default.editorconfig should have a [*.{cs,csx}] section'
        $csharpSection = $editorConfigLines | Select-Object -Skip ($start + 1) | ForEach-Object -Begin { $inSection = $true } -Process {
            if ($_ -match '^\s*\[') { $inSection = $false }
            if ($inSection) { $_ }
        }
        $editorConfig = Read-Settings $csharpSection

        ($globalConfig.Keys | Sort-Object) | Should -Be ($editorConfig.Keys | Sort-Object)
        foreach ($key in $globalConfig.Keys) {
            $globalConfig[$key] | Should -Be $editorConfig[$key] -Because "'$key' should have the same value in both files"
        }
    }

    It 'depends on the StyleCop, Roslynator and threading analyzers' {
        $nuspec = Get-PackageEntryText (Join-Path $packageOutputDir "Endjin.RecommendedPractices.0.0.1-local.nupkg") "Endjin.RecommendedPractices.nuspec"
        $nuspec | Should -Match 'id="StyleCop\.Analyzers"'
        $nuspec | Should -Match 'id="Roslynator\.Analyzers"'
        $nuspec | Should -Match 'id="Microsoft\.VisualStudio\.Threading\.Analyzers"'
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

Describe 'Package metadata of a consuming project' {

    BeforeAll {
        $singleFrameworkPackage = Join-Path $packageOutputDir "SingleFramework.0.0.1-local.nupkg"
        $nuspec = Get-PackageEntryText $singleFrameworkPackage "SingleFramework.nuspec"
    }

    It 'sets the authors to Endjin Limited' {
        $nuspec | Should -Match '<authors>Endjin Limited</authors>'
    }

    It 'sets a default endjin copyright notice' {
        $nuspec | Should -Match '<copyright>Copyright \(c\) Endjin Limited \d{4}\. All rights reserved\.</copyright>'
    }

    It 'requires license acceptance' {
        $nuspec | Should -Match '<requireLicenseAcceptance>true</requireLicenseAcceptance>'
    }

    It 'uses the solution-level package icon' {
        $nuspec | Should -Match '<icon>PackageIcon\.png</icon>'
        Get-PackageEntryNames $singleFrameworkPackage | Should -Contain 'PackageIcon.png'
    }

    It 'includes the XML documentation file' {
        Get-PackageEntryNames $singleFrameworkPackage | Should -Contain 'lib/net10.0/SingleFramework.xml'
    }

    It 'records the source repository and commit' {
        # The URL comes from the Git remote, so whether it ends in .git depends on how the repository
        # was cloned (actions/checkout's remote doesn't).
        $nuspec | Should -Match '<repository type="git" url="https://github\.com/[^"]+"[^>]* commit="[0-9a-f]{40}"'
    }

    It 'puts Source Link information in the symbols package' {
        # The portable PDB's Source Link JSON maps source files to raw.githubusercontent.com URLs.
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::OpenRead((Join-Path $packageOutputDir "SingleFramework.0.0.1-local.snupkg"))
        try {
            $entry = $zip.Entries | Where-Object { $_.FullName -eq 'lib/net10.0/SingleFramework.pdb' }
            $stream = New-Object System.IO.MemoryStream
            $entryStream = $entry.Open()
            try { $entryStream.CopyTo($stream) } finally { $entryStream.Dispose() }
            $pdbText = [System.Text.Encoding]::UTF8.GetString($stream.ToArray())
        }
        finally {
            $zip.Dispose()
        }

        $pdbText | Should -Match 'https://raw\.githubusercontent\.com/'
    }

    It 'packs every target framework of a multi-targeting project' {
        $names = Get-PackageEntryNames (Join-Path $packageOutputDir "MultiFramework.0.0.1-local.nupkg")
        $names | Should -Contain 'lib/net10.0/MultiFramework.dll'
        $names | Should -Contain 'lib/netstandard2.0/MultiFramework.dll'
    }

    It 'marks the build as a CI build when <_> is true' -ForEach @('TF_BUILD', 'GITHUB_ACTIONS') {
        $dir = New-Scenario -Name "ci-$_"
        (Invoke-Scenario $dir @('restore', 'Proj/Proj.csproj')).ExitCode | Should -Be 0
        $result = Invoke-Scenario $dir @('msbuild', 'Proj/Proj.csproj', '-getProperty:ContinuousIntegrationBuild') -Environment @{ $_ = 'true' }
        $result.ExitCode | Should -Be 0 -Because $result.Output
        $result.Output.Trim() | Should -Be 'true'
    }

    It 'does not mark a local build as a CI build' {
        $dir = New-Scenario -Name 'ci-none'
        (Invoke-Scenario $dir @('restore', 'Proj/Proj.csproj')).ExitCode | Should -Be 0
        $result = Invoke-Scenario $dir @('msbuild', 'Proj/Proj.csproj', '-getProperty:ContinuousIntegrationBuild')
        $result.ExitCode | Should -Be 0 -Because $result.Output
        $result.Output.Trim() | Should -BeNullOrEmpty
    }

    It 'keeps a copyright notice that the project sets' {
        $dir = New-Scenario -Name 'custom-copyright' -ProjectXml (New-ProjectXml -Properties '<Copyright>Copyright (c) Someone Else.</Copyright>')
        $result = Invoke-Scenario $dir @('pack', 'Proj/Proj.csproj', '-o', 'out')
        $result.ExitCode | Should -Be 0 -Because $result.Output
        Get-PackageEntryText (Join-Path $dir "out/Proj.1.0.0.nupkg") "Proj.nuspec" | Should -Match '<copyright>Copyright \(c\) Someone Else\.</copyright>'
    }
}

Describe 'Project conventions' {

    It 'fails the build with instructions when the project does not import Endjin.Project.props' {
        $dir = New-Scenario -Name 'no-props-import' -ProjectXml (New-ProjectXml -NoImport)
        $result = Invoke-Scenario $dir @('build', 'Proj/Proj.csproj')
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match ([regex]::Escape('you must add <Import Project="$(EndjinProjectPropsPath)"'))
    }

    It 'leaves the root namespace empty' {
        $dir = New-Scenario -Name 'root-namespace'
        $build = Invoke-Scenario $dir @('build', 'Proj/Proj.csproj')
        $build.ExitCode | Should -Be 0 -Because $build.Output
        # Asking for two properties makes MSBuild print them as JSON.
        $result = Invoke-Scenario $dir @('msbuild', 'Proj/Proj.csproj', '-getProperty:RootNamespace', '-getProperty:AssemblyName')
        $properties = ($result.Output.Substring($result.Output.IndexOf('{')) | ConvertFrom-Json).Properties
        $properties.AssemblyName | Should -Be 'Proj'
        $properties.RootNamespace | Should -BeNullOrEmpty
    }

    It 'treats compiler warnings as errors' {
        $code = $houseStyleClass.Replace('return DateTimeOffset.UtcNow;', "int unused;`r`n        return DateTimeOffset.UtcNow;")
        $dir = New-Scenario -Name 'warnings-as-errors' -Files @{ 'Proj/Widget.cs' = $code }
        $result = Invoke-Scenario $dir @('build', 'Proj/Proj.csproj')
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'error CS0168'
    }

    It 'does not treat warnings as errors in a Debug build' {
        $code = $houseStyleClass.Replace('return DateTimeOffset.UtcNow;', "int unused;`r`n        return DateTimeOffset.UtcNow;")
        $dir = New-Scenario -Name 'warnings-debug' -Files @{ 'Proj/Widget.cs' = $code }
        $result = Invoke-Scenario $dir @('build', 'Proj/Proj.csproj') -Configuration Debug
        $result.ExitCode | Should -Be 0 -Because $result.Output
        $result.Output | Should -Match 'warning CS0168'
    }

    It 'treats warnings as errors in a Debug build when the project sets TreatWarningsAsErrors' {
        $code = $houseStyleClass.Replace('return DateTimeOffset.UtcNow;', "int unused;`r`n        return DateTimeOffset.UtcNow;")
        $dir = New-Scenario -Name 'warnings-debug-opt-in' -ProjectXml (New-ProjectXml -Properties '<TreatWarningsAsErrors>true</TreatWarningsAsErrors>') -Files @{ 'Proj/Widget.cs' = $code }
        $result = Invoke-Scenario $dir @('build', 'Proj/Proj.csproj') -Configuration Debug
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'error CS0168'
    }

    It 'treats warnings as errors when the project file itself selects the Release configuration' {
        # No configuration is passed in, so the package's .props sees none; its .targets must apply the rule.
        $code = $houseStyleClass.Replace('return DateTimeOffset.UtcNow;', "int unused;`r`n        return DateTimeOffset.UtcNow;")
        $dir = New-Scenario -Name 'warnings-release-in-project' -ProjectXml (New-ProjectXml -Properties '<Configuration>Release</Configuration>') -Files @{ 'Proj/Widget.cs' = $code }
        $result = Invoke-Scenario $dir @('build', 'Proj/Proj.csproj') -Configuration ''
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'error CS0168'
    }

    It 'keeps TreatWarningsAsErrors <Value> from Directory.Build.props in a Release build (<How>)' -ForEach @(
        @{ Value = 'false'; How = 'passed in'; ProjectProperties = ''; Configuration = 'Release' }
        @{ Value = 'False'; How = 'passed in'; ProjectProperties = ''; Configuration = 'Release' }
        @{ Value = 'False'; How = 'chosen in the project file'; ProjectProperties = '<Configuration>Release</Configuration>'; Configuration = '' }
    ) {
        $code = $houseStyleClass.Replace('return DateTimeOffset.UtcNow;', "int unused;`r`n        return DateTimeOffset.UtcNow;")
        $directoryBuildProps = "<Project><PropertyGroup><TreatWarningsAsErrors>$Value</TreatWarningsAsErrors></PropertyGroup></Project>"
        $name = "warnings-dbp-$Value-$($How.Replace(' ', '-'))"
        $dir = New-Scenario -Name $name -ProjectXml (New-ProjectXml -Properties $ProjectProperties) -Files @{ 'Proj/Widget.cs' = $code; 'Directory.Build.props' = $directoryBuildProps }
        $result = Invoke-Scenario $dir @('build', 'Proj/Proj.csproj') -Configuration $Configuration
        $result.ExitCode | Should -Be 0 -Because $result.Output
        $result.Output | Should -Match 'warning CS0168'
    }

    It 'keeps TreatWarningsAsErrors <_> when the project file sets it and selects Release' -ForEach @('false', 'False') {
        $code = $houseStyleClass.Replace('return DateTimeOffset.UtcNow;', "int unused;`r`n        return DateTimeOffset.UtcNow;")
        $properties = "<Configuration>Release</Configuration><TreatWarningsAsErrors>$_</TreatWarningsAsErrors>"
        $dir = New-Scenario -Name "warnings-release-opt-out-$_" -ProjectXml (New-ProjectXml -Properties $properties) -Files @{ 'Proj/Widget.cs' = $code }
        $result = Invoke-Scenario $dir @('build', 'Proj/Proj.csproj') -Configuration ''
        $result.ExitCode | Should -Be 0 -Because $result.Output
        $result.Output | Should -Match 'warning CS0168'
    }

    It 'requires XML documentation on public members of a packable project' {
        $code = $houseStyleClass.Replace("    /// <summary>`r`n    /// Gets the current time.`r`n    /// </summary>`r`n    /// <returns>The current time.</returns>`r`n", '')
        $dir = New-Scenario -Name 'undocumented-packable' -Files @{ 'Proj/Widget.cs' = $code }
        $result = Invoke-Scenario $dir @('build', 'Proj/Proj.csproj')
        $result.ExitCode | Should -Not -Be 0
    }

    It 'does not require XML documentation on public members of a non-packable project' {
        $code = $houseStyleClass.Replace("    /// <summary>`r`n    /// Gets the current time.`r`n    /// </summary>`r`n    /// <returns>The current time.</returns>`r`n", '')
        $dir = New-Scenario -Name 'undocumented-non-packable' -ProjectXml (New-ProjectXml -Properties '<IsPackable>false</IsPackable>') -Files @{ 'Proj/Widget.cs' = $code }
        $result = Invoke-Scenario $dir @('build', 'Proj/Proj.csproj')
        $result.ExitCode | Should -Be 0 -Because $result.Output
    }

    It 'requires XML documentation in a non-packable project that sets EndjinLeaveWarningsEnabledOnNonPackableProject' {
        $code = $houseStyleClass.Replace("    /// <summary>`r`n    /// Gets the current time.`r`n    /// </summary>`r`n    /// <returns>The current time.</returns>`r`n", '')
        $properties = '<IsPackable>false</IsPackable><EndjinLeaveWarningsEnabledOnNonPackableProject>true</EndjinLeaveWarningsEnabledOnNonPackableProject>'
        $dir = New-Scenario -Name 'undocumented-non-packable-opt-in' -ProjectXml (New-ProjectXml -Properties $properties) -Files @{ 'Proj/Widget.cs' = $code }
        $result = Invoke-Scenario $dir @('build', 'Proj/Proj.csproj')
        $result.ExitCode | Should -Not -Be 0
    }

    It 'copies local.settings.json to the output folder' {
        $dir = New-Scenario -Name 'local-settings' -Files @{ 'Proj/Widget.cs' = $houseStyleClass; 'Proj/local.settings.json' = '{ "IsEncrypted": false }' }
        $result = Invoke-Scenario $dir @('build', 'Proj/Proj.csproj', '-c', 'Release')
        $result.ExitCode | Should -Be 0 -Because $result.Output
        Get-ChildItem -Path (Join-Path $dir 'Proj/bin/Release') -Recurse -Filter 'local.settings.json' | Should -Not -BeNullOrEmpty
    }
}

Describe 'Code analysis on the first build of a clean checkout' {

    It 'accepts code that follows the house style' {
        $dir = New-Scenario -Name 'house-style'
        $result = Invoke-Scenario $dir @('build', 'Proj/Proj.csproj')
        $result.ExitCode | Should -Be 0 -Because $result.Output
    }

    It 'fails the build when code breaks a StyleCop rule' {
        $code = $houseStyleClass.Substring($houseStyleClass.IndexOf('using System;'))
        $dir = New-Scenario -Name 'missing-file-header' -Files @{ 'Proj/Widget.cs' = $code }
        $result = Invoke-Scenario $dir @('build', 'Proj/Proj.csproj')
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'error SA1633'
    }

    It 'applies the house rules from the default .editorconfig, such as requiring a final newline' {
        $dir = New-Scenario -Name 'final-newline' -Files @{ 'Proj/Widget.cs' = $houseStyleClass.TrimEnd() }
        $result = Invoke-Scenario $dir @('build', 'Proj/Proj.csproj')
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'error SA1518'
    }

    It 'does not report RCS1089 for an increment written as an assignment' {
        $code = $houseStyleClass.Replace("    public DateTimeOffset GetNow()`r`n    {`r`n        return DateTimeOffset.UtcNow;`r`n    }", "    public int Increment(int count)`r`n    {`r`n        count += 1;`r`n        return count;`r`n    }").Replace('Gets the current time.', 'Increments a count.').Replace('<returns>The current time.</returns>', "<param name=""count"">The count.</param>`r`n    /// <returns>The incremented count.</returns>")
        $dir = New-Scenario -Name 'increment-assignment' -Files @{ 'Proj/Widget.cs' = $code }
        $result = Invoke-Scenario $dir @('build', 'Proj/Proj.csproj')
        $result.ExitCode | Should -Be 0 -Because $result.Output
        $result.Output | Should -Not -Match '(warning|error) RCS1089'
    }

    It 'reports async void methods (VSTHRD100) from the threading analyzers' {
        $code = $houseStyleClass.Replace("    public DateTimeOffset GetNow()`r`n    {`r`n        return DateTimeOffset.UtcNow;`r`n    }", "    public async void Run()`r`n    {`r`n        await Task.Yield();`r`n    }").Replace('using System;', 'using System.Threading.Tasks;').Replace('Gets the current time.', 'Runs.').Replace("    /// <returns>The current time.</returns>`r`n", '')
        $dir = New-Scenario -Name 'async-void' -Files @{ 'Proj/Widget.cs' = $code }
        $result = Invoke-Scenario $dir @('build', 'Proj/Proj.csproj')
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'error VSTHRD100'
    }

    It 'does not run the StyleCop rules, or create stylecop.json, when EndjinDisableCodeAnalysis is true' {
        $code = $houseStyleClass.Substring($houseStyleClass.IndexOf('using System;'))
        $dir = New-Scenario -Name 'code-analysis-disabled' -ProjectXml (New-ProjectXml -Properties '<EndjinDisableCodeAnalysis>true</EndjinDisableCodeAnalysis>') -Files @{ 'Proj/Widget.cs' = $code }
        $result = Invoke-Scenario $dir @('build', 'Proj/Proj.csproj')
        $result.ExitCode | Should -Be 0 -Because $result.Output
        (Join-Path $dir 'stylecop.json') | Should -Not -Exist
    }

    It 'does not create .editorconfig or apply its settings when EndjinDisableCreateEditorConfig is true' {
        # No using directive: without the house settings, StyleCop also wants usings inside the
        # namespace (SA1200), which would make this fail for a different reason.
        $code = $houseStyleClass.Replace("using System;`r`n`r`n", '').Replace('DateTimeOffset', 'System.DateTimeOffset').TrimEnd()
        $dir = New-Scenario -Name 'editorconfig-disabled' -ProjectXml (New-ProjectXml -Properties '<EndjinDisableCreateEditorConfig>true</EndjinDisableCreateEditorConfig>') -Files @{ 'Proj/Widget.cs' = $code }
        $result = Invoke-Scenario $dir @('build', 'Proj/Proj.csproj')
        $result.ExitCode | Should -Be 0 -Because "without the house settings a missing final newline is allowed`n$($result.Output)"
        (Join-Path $dir '.editorconfig') | Should -Not -Exist
    }

    It 'lets the solution''s own .editorconfig override the house settings' {
        $editorConfig = "root = true`r`n`r`n[*.cs]`r`ninsert_final_newline = false`r`n"
        $dir = New-Scenario -Name 'own-editorconfig' -Files @{ 'Proj/Widget.cs' = $houseStyleClass.TrimEnd(); '.editorconfig' = $editorConfig }
        $result = Invoke-Scenario $dir @('build', 'Proj/Proj.csproj')
        $result.ExitCode | Should -Be 0 -Because $result.Output
    }

    It 'applies the house settings without writing any solution-level files when EndjinDisableSolutionLevelFiles is true' {
        $dir = New-Scenario -Name 'no-solution-files' -ProjectXml (New-ProjectXml -Properties '<EndjinDisableSolutionLevelFiles>true</EndjinDisableSolutionLevelFiles>')
        # The house-style file only passes with the package's stylecop.json (company name) and
        # .editorconfig settings (usings outside a file-scoped namespace).
        $result = Invoke-Scenario $dir @('pack', 'Proj/Proj.csproj', '-o', 'out')
        $result.ExitCode | Should -Be 0 -Because $result.Output
        foreach ($file in @('.editorconfig', 'stylecop.json', 'PackageIcon.png')) {
            (Join-Path $dir $file) | Should -Not -Exist
        }
        Get-PackageEntryNames (Join-Path $dir 'out/Proj.1.0.0.nupkg') | Should -Contain 'PackageIcon.png'
    }

    It 'enforces the house settings when EndjinDisableSolutionLevelFiles is true' {
        $dir = New-Scenario -Name 'no-solution-files-final-newline' -ProjectXml (New-ProjectXml -Properties '<EndjinDisableSolutionLevelFiles>true</EndjinDisableSolutionLevelFiles>') -Files @{ 'Proj/Widget.cs' = $houseStyleClass.TrimEnd() }
        $result = Invoke-Scenario $dir @('build', 'Proj/Proj.csproj')
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'error SA1518'
    }

    It 'does not overwrite the solution''s own <_>' -ForEach @('.editorconfig', 'stylecop.json', 'PackageIcon.png') {
        $content = if ($_ -eq 'stylecop.json') { '{ "settings": { "documentationRules": { "companyName": "Endjin Limited" } } }' } elseif ($_ -eq '.editorconfig') { "root = true`r`n" } else { 'not really a PNG' }
        $dir = New-Scenario -Name "own-$($_.TrimStart('.'))" -Files @{ 'Proj/Widget.cs' = $houseStyleClass; $_ = $content }
        Invoke-Scenario $dir @('build', 'Proj/Proj.csproj') | Out-Null
        [System.IO.File]::ReadAllText((Join-Path $dir $_)) | Should -Be $content
    }
}

Describe 'Packing a consuming project' {

    It 'fails the pack when the reference to the package does not set PrivateAssets to all' {
        $dir = New-Scenario -Name 'not-private' -ProjectXml (New-ProjectXml -PackageReferenceAttributes '')
        $build = Invoke-Scenario $dir @('build', 'Proj/Proj.csproj')
        $build.ExitCode | Should -Be 0 -Because "only packing should be blocked`n$($build.Output)"
        $pack = Invoke-Scenario $dir @('pack', 'Proj/Proj.csproj', '-o', 'out')
        $pack.ExitCode | Should -Not -Be 0
        $pack.Output | Should -Match 'must set PrivateAssets to all'
    }

    It 'fails the pack when the project does not specify a license' {
        $dir = New-Scenario -Name 'no-license' -ProjectXml (New-ProjectXml -License '')
        $result = Invoke-Scenario $dir @('pack', 'Proj/Proj.csproj', '-o', 'out')
        $result.ExitCode | Should -Not -Be 0
    }

    It 'includes the package icon for a project that is not directly below its solution folder' {
        $dir = New-Scenario -Name 'nested-project' -ProjectPath 'src/Nested/Nested.csproj' -Files @{ 'src/Nested/Widget.cs' = $houseStyleClass }
        Push-Location $dir
        try {
            dotnet new sln -n Nested --format sln | Out-Null
            dotnet sln Nested.sln add src/Nested/Nested.csproj | Out-Null
        }
        finally {
            Pop-Location
        }
        $build = Invoke-Scenario $dir @('build', 'Nested.sln')
        $build.ExitCode | Should -Be 0 -Because $build.Output
        $pack = Invoke-Scenario $dir @('pack', 'Nested.sln', '-o', 'out')
        $pack.ExitCode | Should -Be 0 -Because $pack.Output
        Get-PackageEntryNames (Join-Path $dir 'out/Nested.1.0.0.nupkg') | Should -Contain 'PackageIcon.png'
    }

    It 'includes the package icon when a clean checkout is packed without building first' {
        # The solution-level PackageIcon.png doesn't exist when the project is loaded; the build
        # inside 'dotnet pack' creates it.
        $dir = New-Scenario -Name 'first-pack-icon'
        $result = Invoke-Scenario $dir @('pack', 'Proj/Proj.csproj', '-o', 'out')
        $result.ExitCode | Should -Be 0 -Because $result.Output
        Get-PackageEntryNames (Join-Path $dir 'out/Proj.1.0.0.nupkg') | Should -Contain 'PackageIcon.png'
        Get-PackageEntryText (Join-Path $dir 'out/Proj.1.0.0.nupkg') 'Proj.nuspec' | Should -Match '<icon>PackageIcon\.png</icon>'
    }

    It 'leaves out the default package icon when EndjinDisableDefaultPackageIconInclusion is true' {
        $dir = New-Scenario -Name 'no-default-icon' -ProjectXml (New-ProjectXml -Properties '<EndjinDisableDefaultPackageIconInclusion>true</EndjinDisableDefaultPackageIconInclusion>')
        $result = Invoke-Scenario $dir @('pack', 'Proj/Proj.csproj', '-o', 'out')
        $result.ExitCode | Should -Be 0 -Because $result.Output
        Get-PackageEntryNames (Join-Path $dir 'out/Proj.1.0.0.nupkg') | Should -Not -Contain 'PackageIcon.png'
        (Join-Path $dir 'PackageIcon.png') | Should -Not -Exist
    }
}

Describe 'packages.lock.json checks' {

    It 'fails the build of an <_> project that does not use a lock file' -ForEach @('Exe', 'WinExe') {
        $dir = New-Scenario -Name "lock-$_" -ProjectXml (New-ProjectXml -Properties "<OutputType>$_</OutputType>") -Files @{ 'Proj/Program.cs' = $houseStyleProgram }
        $result = Invoke-Scenario $dir @('build', 'Proj/Proj.csproj')
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'Properties for package lock file generation are not set correctly'
    }

    It 'builds an Exe project that uses a lock file' {
        $dir = New-Scenario -Name 'lock-exe-enabled' -ProjectXml (New-ProjectXml -Properties '<OutputType>Exe</OutputType><RestorePackagesWithLockFile>true</RestorePackagesWithLockFile>') -Files @{ 'Proj/Program.cs' = $houseStyleProgram }
        $result = Invoke-Scenario $dir @('build', 'Proj/Proj.csproj')
        $result.ExitCode | Should -Be 0 -Because $result.Output
        (Join-Path $dir 'Proj/packages.lock.json') | Should -Exist
    }

    It 'builds an Exe project without a lock file when EndjinDisableAutoPackagesLock is true' {
        $dir = New-Scenario -Name 'lock-exe-disabled' -ProjectXml (New-ProjectXml -Properties '<OutputType>Exe</OutputType><EndjinDisableAutoPackagesLock>true</EndjinDisableAutoPackagesLock>') -Files @{ 'Proj/Program.cs' = $houseStyleProgram }
        $result = Invoke-Scenario $dir @('build', 'Proj/Proj.csproj')
        $result.ExitCode | Should -Be 0 -Because $result.Output
    }

    It 'fails the CI build of an Exe project whose lock file is not used in locked mode' {
        $dir = New-Scenario -Name 'lock-exe-ci-not-locked' -ProjectXml (New-ProjectXml -Properties '<OutputType>Exe</OutputType><RestorePackagesWithLockFile>true</RestorePackagesWithLockFile>') -Files @{ 'Proj/Program.cs' = $houseStyleProgram }
        $result = Invoke-Scenario $dir @('build', 'Proj/Proj.csproj') -Environment @{ GITHUB_ACTIONS = 'true' }
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'Properties for package lock file generation are not set correctly'
    }

    It 'does not require a lock file for a class library' {
        $dir = New-Scenario -Name 'lock-library'
        $result = Invoke-Scenario $dir @('build', 'Proj/Proj.csproj')
        $result.ExitCode | Should -Be 0 -Because $result.Output
    }
}

Describe 'GitHub support' {

    It 'warns, without failing the build, when a GitHub-hosted project references Endjin.RecommendedPractices instead of the GitHub package' {
        $dir = New-Scenario -Name 'github-without-github-package' -ProjectXml (New-ProjectXml -Package 'Endjin.RecommendedPractices')
        $result = Invoke-Scenario $dir @('build', 'Proj/Proj.csproj')
        $result.ExitCode | Should -Be 0 -Because $result.Output
        $result.Output | Should -Match 'warning : This project is in a GitHub repository, but it references Endjin\.RecommendedPractices instead of Endjin\.RecommendedPractices\.GitHub'
    }

    It 'gives Source Link information to a GitHub-hosted project that references Endjin.RecommendedPractices' {
        # Source Link comes from the .NET SDK, so it doesn't depend on the GitHub package.
        $dir = New-Scenario -Name 'github-without-github-package-sourcelink' -ProjectXml (New-ProjectXml -Package 'Endjin.RecommendedPractices' -Properties '<EndjinDisableGitHubSourceLinkWarning>true</EndjinDisableGitHubSourceLinkWarning>')
        $result = Invoke-Scenario $dir @('pack', 'Proj/Proj.csproj', '-o', 'out')
        $result.ExitCode | Should -Be 0 -Because $result.Output
        Get-PackageEntryText (Join-Path $dir 'out/Proj.1.0.0.nupkg') 'Proj.nuspec' | Should -Match '<repository type="git" url="https://github\.com/[^"]+"[^>]* commit="[0-9a-f]{40}"'
    }

    It 'does not warn when EndjinDisableGitHubSourceLinkWarning is true' {
        $dir = New-Scenario -Name 'github-without-github-package-opt-out' -ProjectXml (New-ProjectXml -Package 'Endjin.RecommendedPractices' -Properties '<EndjinDisableGitHubSourceLinkWarning>true</EndjinDisableGitHubSourceLinkWarning>')
        $result = Invoke-Scenario $dir @('build', 'Proj/Proj.csproj')
        $result.ExitCode | Should -Be 0 -Because $result.Output
        $result.Output | Should -Not -Match 'This project is in a GitHub repository'
    }

    It 'keeps repository and project URLs and release notes that the project sets' {
        $properties = '<RepositoryUrl>https://example.com/custom.git</RepositoryUrl><PackageProjectUrl>https://example.com/project</PackageProjectUrl><PackageReleaseNotes>Custom notes</PackageReleaseNotes>'
        $dir = New-Scenario -Name 'github-custom-urls' -ProjectXml (New-ProjectXml -Properties $properties)
        $result = Invoke-Scenario $dir @('pack', 'Proj/Proj.csproj', '-o', 'out')
        $result.ExitCode | Should -Be 0 -Because $result.Output
        $nuspec = Get-PackageEntryText (Join-Path $dir 'out/Proj.1.0.0.nupkg') 'Proj.nuspec'
        $nuspec | Should -Match '<projectUrl>https://example\.com/project</projectUrl>'
        $nuspec | Should -Match '<releaseNotes>Custom notes</releaseNotes>'
        $nuspec | Should -Match 'url="https://example\.com/custom\.git"'
    }

    It 'finds a GitHub repository with an scp-style remote from a project far below the repository root' {
        # Outside this repository: a new Git repository whose origin is git@github.com:acme/widgets.git,
        # with the project eight folders down.
        $repo = Join-Path ([System.IO.Path]::GetTempPath()) "Endjin.RecommendedPractices.Specs.ScpRemote"
        Remove-Item $repo -Force -Recurse -ErrorAction SilentlyContinue
        $projectDir = Join-Path $repo 'a/b/c/d/e/f/g/Proj'
        New-Item -ItemType Directory -Force -Path $projectDir | Out-Null
        try {
            git -C $repo init -q
            git -C $repo remote add origin git@github.com:acme/widgets.git
            [System.IO.File]::WriteAllText((Join-Path $projectDir 'Proj.csproj'), (New-ProjectXml))
            [System.IO.File]::WriteAllText((Join-Path $projectDir 'Widget.cs'), $houseStyleClass)
            git -C $repo add -A
            git -C $repo -c user.name=specs -c user.email=specs@example.com commit -q -m init
            $result = Invoke-Scenario $projectDir @('pack', 'Proj.csproj', '-o', 'out')
            $result.ExitCode | Should -Be 0 -Because $result.Output
            $nuspec = Get-PackageEntryText (Join-Path $projectDir 'out/Proj.1.0.0.nupkg') 'Proj.nuspec'
            $nuspec | Should -Match '<projectUrl>https://github\.com/acme/widgets</projectUrl>'
            $nuspec | Should -Match '<releaseNotes>See https://github\.com/acme/widgets/releases/</releaseNotes>'
        }
        finally {
            Remove-Item $repo -Force -Recurse -ErrorAction SilentlyContinue
        }
    }

    It 'adds documentation templates to the repository root only when EndjinCreateDocumentationTemplates is true, without overwriting existing files' {
        # Outside this repository, so the templates don't land in this repository's own docs folder.
        $repo = Join-Path ([System.IO.Path]::GetTempPath()) "Endjin.RecommendedPractices.Specs.DocTemplates"
        Remove-Item $repo -Force -Recurse -ErrorAction SilentlyContinue
        $projectDir = Join-Path $repo 'Solutions/Proj'
        New-Item -ItemType Directory -Force -Path $projectDir | Out-Null
        try {
            git -C $repo init -q
            [System.IO.File]::WriteAllText((Join-Path $projectDir 'Proj.csproj'), (New-ProjectXml -Package 'Endjin.RecommendedPractices'))
            [System.IO.File]::WriteAllText((Join-Path $projectDir 'Widget.cs'), $houseStyleClass)

            # Off by default.
            $result = Invoke-Scenario $projectDir @('build', 'Proj.csproj')
            $result.ExitCode | Should -Be 0 -Because $result.Output
            (Join-Path $repo 'docs') | Should -Not -Exist

            # Turned on: the templates go in the repository root (not the solution folder), and an
            # existing file is left alone.
            $existingAdrTemplate = Join-Path $repo 'docs/adr/0000-adr-template.md'
            New-Item -ItemType Directory -Force -Path (Split-Path $existingAdrTemplate) | Out-Null
            [System.IO.File]::WriteAllText($existingAdrTemplate, 'our own template')
            $result = Invoke-Scenario $projectDir @('build', 'Proj.csproj', '-p:EndjinCreateDocumentationTemplates=true')
            $result.ExitCode | Should -Be 0 -Because $result.Output
            (Join-Path $repo 'docs/releasing/Releasing.md') | Should -Exist
            [System.IO.File]::ReadAllText($existingAdrTemplate) | Should -Be 'our own template'
            (Join-Path $repo 'Solutions/docs') | Should -Not -Exist
        }
        finally {
            Remove-Item $repo -Force -Recurse -ErrorAction SilentlyContinue
        }
    }

    It 'does not set GitHub URLs for a project that is not in a GitHub repository' {
        # Outside this repository: a temporary folder that isn't in any Git repository.
        $outside = Join-Path ([System.IO.Path]::GetTempPath()) "Endjin.RecommendedPractices.Specs.NotGitHub"
        Remove-Item $outside -Force -Recurse -ErrorAction SilentlyContinue
        $projectDir = Join-Path $outside 'Proj'
        New-Item -ItemType Directory -Force -Path $projectDir | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $projectDir 'Proj.csproj'), (New-ProjectXml))
        [System.IO.File]::WriteAllText((Join-Path $projectDir 'Widget.cs'), $houseStyleClass)
        try {
            $result = Invoke-Scenario $outside @('pack', 'Proj/Proj.csproj', '-o', 'out')
            $result.ExitCode | Should -Be 0 -Because $result.Output
            $nuspec = Get-PackageEntryText (Join-Path $outside 'out/Proj.1.0.0.nupkg') 'Proj.nuspec'
            $nuspec | Should -Not -Match 'github\.com'
        }
        finally {
            Remove-Item $outside -Force -Recurse -ErrorAction SilentlyContinue
        }
    }
}

Describe '.NET SDK version check' {

    # NETCoreSdkVersion is set by the SDK; a global property overrides it, which lets these specs
    # pretend to be a different SDK without installing one.
    It 'fails the build on a .NET SDK older than 10' {
        $dir = New-Scenario -Name 'sdk-9'
        $result = Invoke-Scenario $dir @('build', 'Proj/Proj.csproj', '-p:NETCoreSdkVersion=9.0.300')
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'requires the \.NET SDK 10\.0 or later'
    }

    It 'accepts a preview of a supported .NET SDK' {
        $dir = New-Scenario -Name 'sdk-preview'
        $result = Invoke-Scenario $dir @('build', 'Proj/Proj.csproj', '-p:NETCoreSdkVersion=11.0.100-rc.1.25451.107')
        $result.ExitCode | Should -Be 0 -Because $result.Output
    }
}

Describe 'Code analyzers' {

    It 'passes the StyleCop, Roslynator and threading analyzers to the compiler' {
        $ids = Get-AnalyzerPackageIds
        $ids | Should -Contain 'StyleCop.Analyzers'
        $ids | Should -Contain 'Roslynator.Analyzers'
        $ids | Should -Contain 'Microsoft.VisualStudio.Threading.Analyzers'
    }

    It 'removes the StyleCop, Roslynator and threading analyzers when EndjinDisableCodeAnalysis is true' {
        $ids = Get-AnalyzerPackageIds @('/p:EndjinDisableCodeAnalysis=true')
        $ids | Should -Not -Contain 'StyleCop.Analyzers'
        $ids | Should -Not -Contain 'Roslynator.Analyzers'
        $ids | Should -Not -Contain 'Microsoft.VisualStudio.Threading.Analyzers'
    }
}
