# Endjin.Recommended Practices release notes

## v3.0

### Breaking changes

* The .NET 10 SDK or later is now required, because .NET 10 is the earliest supported version of .NET. The build fails with an error on older SDKs. You can still target older frameworks, such as `netstandard2.0`, when you build with a supported SDK. If you must build with an older SDK for a short time, set the `EndjinSuppressSdkVersionError` build property to `true`.
* `Endjin.RecommendedPractices.GitHub` no longer depends on the `Microsoft.SourceLink.GitHub` package, and `Endjin.RecommendedPractices` no longer depends on the `Microsoft.Build.Tasks.Git` package. Source Link now comes from the support built into the .NET SDK, so you always get the version that matches your SDK. If you need a specific Source Link version, add your own `PackageReference` to `Microsoft.SourceLink.GitHub`.
* The StyleCop and Roslynator analyzers now run in your projects. Earlier versions declared them in a way that NuGet restore ignored, so they never ran, even though the package said it added them. Because the package turns on `TreatWarningsAsErrors`, you may now get new SA and RCS build errors. To deal with them:
  * fix the code, or change rule severities in your `.editorconfig`; or
  * set the `EndjinDisableCodeAnalysis` build property to `true` to turn both analyzers off.
  * If your project references `StyleCop.Analyzers` or `Roslynator.Analyzers` directly at a lower version than this package (1.3.180 and 5.0.1), remove that reference. The downgrade causes error NU1605. A reference to the same or a higher version is fine.
* Packing a project fails if its reference to `Endjin.RecommendedPractices` or `Endjin.RecommendedPractices.GitHub` does not set `PrivateAssets="all"`. NuGet adds this automatically when you install the package with `dotnet add package` or Visual Studio. Without it, the package your project produces would depend on this package and its analyzers.
* The `packages.lock.json` check now applies to `WinExe` projects (such as WPF and Windows Forms apps) as well as `Exe` projects. Add the lock file settings that the error shows, or set `EndjinDisableAutoPackagesLock` to `true`.
* Builds on GitHub Actions are now CI builds (`ContinuousIntegrationBuild` is `true`), as builds on Azure Pipelines already were. So in GitHub Actions, projects that need lock files must also set `RestoreLockedMode`, as the lock file error shows. A `ContinuousIntegrationBuild` value that your project sets itself is kept.

### Other changes

* A project in a GitHub repository that references `Endjin.RecommendedPractices` instead of `Endjin.RecommendedPractices.GitHub` now gets a warning instead of an error. Source Link works with either package. The GitHub package adds the repository type, project URL and release notes. Set `EndjinDisableGitHubSourceLinkWarning` to `true` to hide the warning.
* `Endjin.RecommendedPractices.GitHub` shows a warning if Source Link is not available, for example when a project sets `SuppressImplicitGitSourceLink` to `true`.
* `Endjin.RecommendedPractices.GitHub` sets `RepositoryUrl`, `PackageProjectUrl` and `PackageReleaseNotes` only when it finds a GitHub repository. Previously, if it could not find one, it set invalid URLs such as `https://github.com//.git`. Values that your project sets are no longer overwritten. They are also now set when you pack with `dotnet pack --no-build`, and for projects that target multiple frameworks.
* The first build of a clean checkout now uses the package's `.editorconfig` C# settings (through a global analyzer config) and `stylecop.json` settings. Previously that build could fail with errors such as SA1200 and SA1636, because the files were copied into the solution folder only during the build.
* Non-packable projects no longer require XML documentation on public members. Previously, the compiler's CS1591 warning still applied to them.
* Packing a project that is not directly below its solution folder no longer fails with error NU5019 (`PackageIcon.png` not found).
* The `StyleCop.Analyzers` reference is updated to 1.3.180 (the first stable 1.3 release), and the `Roslynator.Analyzers` reference to 5.0.1.
