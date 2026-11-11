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

### Other changes

* `Endjin.RecommendedPractices.GitHub` shows a warning if Source Link is not available, for example when a project sets `SuppressImplicitGitSourceLink` to `true`.
* `Endjin.RecommendedPractices.GitHub` sets `RepositoryUrl`, `PackageProjectUrl` and `PackageReleaseNotes` only when it finds a GitHub repository. Previously, if it could not find one, it set invalid URLs such as `https://github.com//.git`.
* The `StyleCop.Analyzers` reference is updated to 1.3.180 (the first stable 1.3 release), and the `Roslynator.Analyzers` reference to 5.0.1.
