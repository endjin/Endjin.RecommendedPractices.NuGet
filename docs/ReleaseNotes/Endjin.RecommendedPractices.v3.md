# Endjin.Recommended Practices release notes

## v3.0

### Breaking changes

* The .NET 10 SDK or later is now required, because .NET 10 is the earliest supported version of .NET. The build fails with an error on older SDKs. You can still target older frameworks, such as `netstandard2.0`, when you build with a supported SDK. If you must build with an older SDK for a short time, set the `EndjinSuppressSdkVersionError` build property to `true`.
* `Endjin.RecommendedPractices.GitHub` no longer depends on the `Microsoft.SourceLink.GitHub` package, and `Endjin.RecommendedPractices` no longer depends on the `Microsoft.Build.Tasks.Git` package. Source Link now comes from the support built into the .NET SDK, so you always get the version that matches your SDK. If you need a specific Source Link version, add your own `PackageReference` to `Microsoft.SourceLink.GitHub`.
* The StyleCop and Roslynator analyzers now run in your projects. Earlier versions declared them in a way that NuGet restore ignored, so they never ran, even though the package said it added them. Because the package makes warnings errors in Release builds, you may now get new SA and RCS build errors. To deal with them:
  * fix the code, or change rule severities in your `.editorconfig`; or
  * set the `EndjinDisableCodeAnalysis` build property to `true` to turn both analyzers off.
  * If your project references `StyleCop.Analyzers` or `Roslynator.Analyzers` directly at a lower version than this package (1.3.180 and 5.0.1), remove that reference. The downgrade causes error NU1605. A reference to the same or a higher version is fine.
* Packing a project fails if its reference to `Endjin.RecommendedPractices` or `Endjin.RecommendedPractices.GitHub` does not set `PrivateAssets="all"`. NuGet adds this automatically when you install the package with `dotnet add package` or Visual Studio. Without it, the package your project produces would depend on this package and its analyzers.
* The `packages.lock.json` check now applies to `WinExe` projects (such as WPF and Windows Forms apps) as well as `Exe` projects. Add the lock file settings that the error shows, or set `EndjinDisableAutoPackagesLock` to `true`.
* Builds on GitHub Actions are now CI builds (`ContinuousIntegrationBuild` is `true`), as builds on Azure Pipelines already were. So in GitHub Actions, projects that need lock files must also set `RestoreLockedMode`, as the lock file error shows. A `ContinuousIntegrationBuild` value that your project sets itself is kept.

* The `Microsoft.VisualStudio.Threading.Analyzers` analyzers are added. They report async and threading mistakes, such as `async void` methods (VSTHRD100), as errors in Release builds. Fix them, change severities in your `.editorconfig`, or set `EndjinDisableCodeAnalysis` to `true` (which turns off all three analyzer packages).
* The default `.editorconfig` now requires C# files to end with a newline, so SA1518 reports files without one. Previously it required the opposite. This affects solutions that get the `.editorconfig` from the package (and the first build of a checkout that doesn't commit it). A solution with its own `.editorconfig` keeps its setting. To fix existing files, run `dotnet format`.

### Other changes

* Warnings are errors only in Release builds, so Debug builds no longer fail on warnings while you're experimenting. CI and packaging build Release, so warnings still block merging and shipping. Set `TreatWarningsAsErrors` to `true` in your project (or `Directory.Build.props`) to keep warnings as errors in every configuration.
* Set `EndjinDisableSolutionLevelFiles` to `true` if you don't want the package to write `.editorconfig`, `stylecop.json` and `PackageIcon.png` into your solution folder. The settings and icon still apply from the package's own copies.
* The first pack of a clean checkout now includes the package icon, even if `PackageIcon.png` doesn't exist yet.
* GitHub detection reads the Git configuration directly. It works at any depth below the repository root, in worktrees and submodules, and with `git@github.com:` remotes.
* RCS1089 (use `++` instead of `+= 1`) is explicitly turned off.

* A project in a GitHub repository that references `Endjin.RecommendedPractices` instead of `Endjin.RecommendedPractices.GitHub` now gets a warning instead of an error. Source Link works with either package. The GitHub package adds the repository type, project URL and release notes. Set `EndjinDisableGitHubSourceLinkWarning` to `true` to hide the warning.
* `Endjin.RecommendedPractices.GitHub` shows a warning if Source Link is not available, for example when a project sets `SuppressImplicitGitSourceLink` to `true`.
* `Endjin.RecommendedPractices.GitHub` sets `RepositoryUrl`, `PackageProjectUrl` and `PackageReleaseNotes` only when it finds a GitHub repository. Previously, if it could not find one, it set invalid URLs such as `https://github.com//.git`. Values that your project sets are no longer overwritten. They are also now set when you pack with `dotnet pack --no-build`, and for projects that target multiple frameworks.
* The first build of a clean checkout now uses the package's `.editorconfig` C# settings (through a global analyzer config) and `stylecop.json` settings. Previously that build could fail with errors such as SA1200 and SA1636, because the files were copied into the solution folder only during the build.
* Non-packable projects no longer require XML documentation on public members. Previously, the compiler's CS1591 warning still applied to them.
* Packing a project that is not directly below its solution folder no longer fails with error NU5019 (`PackageIcon.png` not found).
* The `StyleCop.Analyzers` reference is updated to 1.3.180 (the first stable 1.3 release), and the `Roslynator.Analyzers` reference to 5.0.1.
