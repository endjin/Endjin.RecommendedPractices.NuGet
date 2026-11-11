# Changelog

All notable changes to the `Endjin.RecommendedPractices` and `Endjin.RecommendedPractices.GitHub` NuGet packages are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

These changes will be released as version 3.0.0. See also the [v3 release notes](docs/ReleaseNotes/Endjin.RecommendedPractices.v3.md).

### Added

- A build error when the .NET SDK is older than 10.0. Set the `EndjinSuppressSdkVersionError` build property to `true` to turn it off.
- A build warning from `Endjin.RecommendedPractices.GitHub` when Source Link is not available, for example when a project sets `SuppressImplicitGitSourceLink` to `true`.
- A pack error when the reference to `Endjin.RecommendedPractices` or `Endjin.RecommendedPractices.GitHub` does not set `PrivateAssets` to `all`. Without it, the package the project produces would depend on this package.

### Changed

- **Breaking:** the .NET 10 SDK or later is now required, because .NET 10 is the earliest supported version of .NET. You can still target older frameworks, such as `netstandard2.0`.
- **Breaking:** the StyleCop and Roslynator analyzers now run in consuming projects (see Fixed). Because the package turns on `TreatWarningsAsErrors`, their warnings become build errors. Fix them, change rule severities in `.editorconfig`, or set `EndjinDisableCodeAnalysis` to `true`. If your project references `StyleCop.Analyzers` or `Roslynator.Analyzers` directly at a lower version than this package, remove that reference: the downgrade causes error NU1605.
- `StyleCop.Analyzers` and `Roslynator.Analyzers` are now dependencies of the `Endjin.RecommendedPractices` package. `EndjinDisableCodeAnalysis` now removes their analyzers from compilation, instead of leaving out the package references.
- **Breaking:** Source Link now comes from the support built into the .NET SDK, so you always get the version that matches your SDK. If you need a specific version, add your own `PackageReference` to `Microsoft.SourceLink.GitHub`.
- Updated the `StyleCop.Analyzers` reference from 1.2.0-beta.556 to 1.3.180.
- Updated the `Roslynator.Analyzers` reference from 4.13.1 to 5.0.1.
- Updated the default `Copyright` year to 2026.
- **Breaking:** the `packages.lock.json` check now applies to `WinExe` projects (such as WPF and Windows Forms apps) as well as `Exe` projects. A `WinExe` project without lock file settings now fails with the same error. Add the settings the error shows, or set `EndjinDisableAutoPackagesLock` to `true`.

### Removed

- **Breaking:** the `Microsoft.SourceLink.GitHub` 1.1.1 dependency from `Endjin.RecommendedPractices.GitHub`.
- **Breaking:** the `Microsoft.Build.Tasks.Git` 1.1.1 dependency from `Endjin.RecommendedPractices`.

### Fixed

- The StyleCop and Roslynator analyzers never reached consuming projects. They were declared as `PackageReference` items in the package's build targets, which NuGet restore doesn't read, so they were never restored or run. This was true from the first release, so none of the analyzer references listed in earlier versions of this changelog had any effect.
- StyleCop now uses the package's `stylecop.json` settings on the first build of a clean checkout, before the package has copied `stylecop.json` into the solution folder. Previously StyleCop used its defaults for that build, so rules such as SA1636 (file header copyright text) failed.
- `Endjin.RecommendedPractices.GitHub` no longer sets invalid `RepositoryUrl`, `PackageProjectUrl` and `PackageReleaseNotes` values (such as `https://github.com//.git`) when it cannot find a GitHub repository.
- Packing a project that is not directly below its solution folder no longer fails with error NU5019 (`PackageIcon.png` not found). The package icon is now always included from the solution folder, where the package puts it.
- `EndjinProjectIsInGitHubRepo` is now `false` for projects that are not in a GitHub repository. Previously it was left empty.
- `EndjinGitHubOrg` is now set for `ssh://` remotes whose user is not `git`.
- Removed stray characters (`']`) from the end of the error shown when a project does not import `Endjin.Project.props`.

## [2.1.18] - 2025-03-13

Version 2.1.17 was tagged from the same commit but was not published.

### Changed

- Updated the `Roslynator.Analyzers` reference from 4.12.11 to 4.13.1.

## [2.1.16] - 2025-02-08

### Changed

- Updated the `Roslynator.Analyzers` reference from 4.12.10 to 4.12.11.

## [2.1.15] - 2025-01-13

### Changed

- Updated the `Roslynator.Analyzers` reference from 4.12.9 to 4.12.10.

## [2.1.14] - 2024-11-24

### Changed

- Updated the `Roslynator.Analyzers` reference from 4.12.4 to 4.12.9.

## [2.1.13] - 2024-08-08

### Changed

- Updated the `Roslynator.Analyzers` reference from 4.12.3 to 4.12.4.

## [2.1.12] - 2024-05-23

### Changed

- Updated the `Roslynator.Analyzers` reference from 4.12.1 to 4.12.3.

### Fixed

- Dependabot updates no longer fail on projects that use this package. The check for the `Endjin.Project.props` import now skips the temporary `Project.csproj` that Dependabot builds.

## [2.1.11] - 2024-04-16

### Changed

- Updated the `Roslynator.Analyzers` reference from 4.12.0 to 4.12.1.

## [2.1.10] - 2024-04-15

### Changed

- Updated the `Roslynator.Analyzers` reference from 4.9.0 to 4.12.0.

## [2.1.9] - 2024-01-18

### Changed

- Updated the `Roslynator.Analyzers` reference from 4.7.0 to 4.9.0.

## [2.1.8] - 2024-01-01

### Changed

- Updated the `Roslynator.Analyzers` reference from 4.6.1 to 4.7.0.
- Updated the `StyleCop.Analyzers` reference from 1.2.0-beta.507 to 1.2.0-beta.556.

## [2.1.7] - 2023-11-01

### Changed

- Updated the `Roslynator.Analyzers` reference from 4.5.0 to 4.6.1.

## [2.1.6] - 2023-09-25

### Changed

- Updated the `Roslynator.Analyzers` reference from 4.3.0 to 4.5.0.
- Updated the `StyleCop.Analyzers` reference from 1.2.0-beta.435 to 1.2.0-beta.507.

## [2.1.5] - 2023-05-02

### Changed

- Updated the `Roslynator.Analyzers` reference from 4.2.0 to 4.3.0.
- Updated the default `Copyright` year to 2023.

## [2.1.4] - 2022-11-28

### Changed

- Updated the `Roslynator.Analyzers` reference from 4.1.2 to 4.2.0.

## [2.1.3] - 2022-11-25

### Changed

- Updated the `Roslynator.Analyzers` reference from 4.1.1 to 4.1.2.

## [2.1.2] - 2022-08-19

### Added

- A package icon for both NuGet packages.

### Changed

- Updated the `Roslynator.Analyzers` reference from 4.1.0 to 4.1.1.
- Updated the `StyleCop.Analyzers` reference from 1.2.0-beta.406 to 1.2.0-beta.435.

## [2.1.1] - 2022-04-27

### Changed

- Updated the `Roslynator.Analyzers` reference from 4.0.2 to 4.1.0.

## [2.1.0] - 2022-01-31

### Changed

- Updated the `Roslynator.Analyzers` reference from 3.3.0 to 4.0.2.
- Updated the `StyleCop.Analyzers` reference from 1.2.0-beta.376 to 1.2.0-beta.406.

## [2.0.1] - 2022-01-27

No functional changes. A comment in the default `.editorconfig` was reworded. Version 2.0.0 is unlisted on NuGet, so use this version instead.

## [2.0.0] - 2022-01-27

See also the [v2 release notes](docs/ReleaseNotes/Endjin.RecommendedPractices.v2.md).

### Added

- The `Endjin.RecommendedPractices.GitHub` package, which adds GitHub Source Link and sets the GitHub repository properties for NuGet packages.
- A build error when a project is hosted on GitHub but references `Endjin.RecommendedPractices` instead of `Endjin.RecommendedPractices.GitHub`. Set the `EndjinDisableGitHubSourceLinkWarning` build property to `true` to turn it off.
- Checks that `packages.lock.json` files are configured in projects that produce runnable artifacts, such as executables and Azure Functions hosts. Use the `EndjinAutoPackagesLock` and `EndjinDisableAutoPackagesLock` build properties to control the checks.
- A reference to `Roslynator.Analyzers` 3.3.0.
- `.editorconfig` rules that require file-scoped namespaces and `using` directives outside the namespace.

### Changed

- **Breaking:** GitHub Source Link moved to the new `Endjin.RecommendedPractices.GitHub` package. `Endjin.RecommendedPractices` can now be used in repositories that are not hosted on GitHub.
- The package uses the code analysis that is enabled by default in the .NET 6 SDK, instead of the settings designed for older mechanisms.
- Updated the `StyleCop.Analyzers` reference from 1.1.118 to 1.2.0-beta.376.

### Removed

- **Breaking:** the `StyleCop.ruleset` file, which was deprecated in Visual Studio 2019 16.5. The relevant rules moved into the `.editorconfig` file.

## [1.2.0] - 2020-08-26

### Added

- Support for projects that target multiple frameworks.

## [1.1.0] - 2020-08-12

### Changed

- XML documentation is now enabled with the `GenerateDocumentationFile` property instead of `DocumentationFile`.

## [1.0.0] - 2020-07-13

No changes. This is the first stable release, with the same contents as 0.6.0.

## [0.6.0] - 2020-07-09

### Added

- Deterministic build settings for builds that run in Azure DevOps.

### Fixed

- Source code links: the repository name is now parsed correctly, and `RepositoryUrl` ends with `.git`.

## [0.5.0] - 2020-07-08

### Added

- A default `PackageIcon.png`, copied to the solution folder if it does not exist.

### Fixed

- Links to `PackageIcon.png` and `stylecop.json` are added only when the files exist, so Solution Explorer no longer shows them with a red X before the first build.

## [0.4.0] - 2020-06-26

### Fixed

- Builds that do not set `$(SolutionDir)`, such as `dotnet build` on a single project, now find the solution-level files.

## [0.3.0] - 2020-04-15

### Changed

- The recommended `Import` of `Endjin.Project.props` now has a `Condition`, so projects still load before the package is restored.

## [0.2.1] - 2020-03-26

No changes to the package. A typo in the README was fixed.

## [0.2.0] - 2020-03-26

Also published as 0.1.1.

### Added

- `Endjin.Project.props`, which projects import at the top of the project file. It sets an empty `RootNamespace`.
- A build error when a project does not import `Endjin.Project.props`.

## [0.1.0] - 2020-02-10

### Added

- First release. The package sets a default copyright, enables XML documentation, sets default NuGet package metadata, enables GitHub Source Link, treats warnings as errors, adds `StyleCop.Analyzers`, and provides default `stylecop.json` and `.editorconfig` files at the solution level.

[Unreleased]: https://github.com/endjin/Endjin.RecommendedPractices.NuGet/compare/2.1.18...HEAD
[2.1.18]: https://github.com/endjin/Endjin.RecommendedPractices.NuGet/compare/2.1.16...2.1.18
[2.1.16]: https://github.com/endjin/Endjin.RecommendedPractices.NuGet/compare/2.1.15...2.1.16
[2.1.15]: https://github.com/endjin/Endjin.RecommendedPractices.NuGet/compare/2.1.14...2.1.15
[2.1.14]: https://github.com/endjin/Endjin.RecommendedPractices.NuGet/compare/2.1.13...2.1.14
[2.1.13]: https://github.com/endjin/Endjin.RecommendedPractices.NuGet/compare/2.1.12...2.1.13
[2.1.12]: https://github.com/endjin/Endjin.RecommendedPractices.NuGet/compare/2.1.11...2.1.12
[2.1.11]: https://github.com/endjin/Endjin.RecommendedPractices.NuGet/compare/2.1.10...2.1.11
[2.1.10]: https://github.com/endjin/Endjin.RecommendedPractices.NuGet/compare/2.1.9...2.1.10
[2.1.9]: https://github.com/endjin/Endjin.RecommendedPractices.NuGet/compare/2.1.8...2.1.9
[2.1.8]: https://github.com/endjin/Endjin.RecommendedPractices.NuGet/compare/2.1.7...2.1.8
[2.1.7]: https://github.com/endjin/Endjin.RecommendedPractices.NuGet/compare/2.1.6...2.1.7
[2.1.6]: https://github.com/endjin/Endjin.RecommendedPractices.NuGet/compare/2.1.5...2.1.6
[2.1.5]: https://github.com/endjin/Endjin.RecommendedPractices.NuGet/compare/2.1.4...2.1.5
[2.1.4]: https://github.com/endjin/Endjin.RecommendedPractices.NuGet/compare/2.1.3...2.1.4
[2.1.3]: https://github.com/endjin/Endjin.RecommendedPractices.NuGet/compare/2.1.2...2.1.3
[2.1.2]: https://github.com/endjin/Endjin.RecommendedPractices.NuGet/compare/2.1.1...2.1.2
[2.1.1]: https://github.com/endjin/Endjin.RecommendedPractices.NuGet/compare/2.1.0...2.1.1
[2.1.0]: https://github.com/endjin/Endjin.RecommendedPractices.NuGet/compare/2.0.1...2.1.0
[2.0.1]: https://github.com/endjin/Endjin.RecommendedPractices.NuGet/compare/2.0...2.0.1
[2.0.0]: https://github.com/endjin/Endjin.RecommendedPractices.NuGet/compare/1.2.0...2.0
[1.2.0]: https://github.com/endjin/Endjin.RecommendedPractices.NuGet/compare/1.1.0...1.2.0
[1.1.0]: https://github.com/endjin/Endjin.RecommendedPractices.NuGet/compare/1.0.0...1.1.0
[1.0.0]: https://github.com/endjin/Endjin.RecommendedPractices.NuGet/compare/0.6.0...1.0.0
[0.6.0]: https://github.com/endjin/Endjin.RecommendedPractices.NuGet/compare/0.5.0...0.6.0
[0.5.0]: https://github.com/endjin/Endjin.RecommendedPractices.NuGet/compare/0.4.0...0.5.0
[0.4.0]: https://github.com/endjin/Endjin.RecommendedPractices.NuGet/compare/0.3.0...0.4.0
[0.3.0]: https://github.com/endjin/Endjin.RecommendedPractices.NuGet/compare/0.2.1...0.3.0
[0.2.1]: https://github.com/endjin/Endjin.RecommendedPractices.NuGet/compare/0.2.0...0.2.1
[0.2.0]: https://github.com/endjin/Endjin.RecommendedPractices.NuGet/compare/0.1.0...0.2.0
[0.1.0]: https://github.com/endjin/Endjin.RecommendedPractices.NuGet/releases/tag/0.1.0
