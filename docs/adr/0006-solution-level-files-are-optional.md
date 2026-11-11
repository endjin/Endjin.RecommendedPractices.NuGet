# Solution-level files are a convenience, not a requirement

## Status

Accepted.

## Context

`Endjin.RecommendedPractices` is referenced by projects, but some of what it sets up belongs to the whole
solution: the `.editorconfig` that holds the code style and analyzer settings, the `stylecop.json` that configures
StyleCop, and the `PackageIcon.png` used by every package the solution produces. NuGet has no way for a package to
supply solution-level content, so the package copies these files into the solution folder during a build if they
don't exist yet. Issue #23 pointed out that this is a project-level mechanism applied to a solution-level concern.

Until version 3, the build depended on the copies. Because the files are only copied during a build, and the .NET
SDK decides which `.editorconfig` and `stylecop.json` apply when the project is loaded, the first build of a clean
checkout that didn't commit them ran the analyzers without the endjin settings, and failed. The package icon had the
same problem: the first pack of such a checkout produced a package with no icon.

## Decision

The package supplies everything the build needs itself, so the solution-level files are never required:

* the C# settings from the default `.editorconfig` are also applied as a global analyzer config
  (`Endjin.CodeAnalysis.globalconfig`), which applies to every file in the compilation;
* until the solution has its own `stylecop.json`, StyleCop gets the package's copy as an additional file;
* when packing, if no package icon has been set, the solution's `PackageIcon.png` is used if it exists, and
  otherwise the package's default icon.

The package still copies the files into the solution folder by default, because they make the settings visible
and easy to change, and most solutions commit them. A solution's own copies always take precedence over the
package's settings. A solution that doesn't want a NuGet package writing files into its solution folder can set
`EndjinDisableSolutionLevelFiles` to `true`, and gets the same settings without the files.

We considered other ways to deliver solution-level files, such as a `dotnet new` template or a separate tool.
These would only run when someone remembers to run them, and couldn't keep a project consistent the way a
package reference does, so we didn't adopt them.

## Consequences

* The first build of a clean checkout behaves the same as every later build.
* Solutions can choose between editable copies of the settings (the default) and no solution-level files at all.
* The C# settings exist in two files in this repository, `default.editorconfig` and
  `Endjin.CodeAnalysis.globalconfig`. A spec checks that they stay the same.

## Documentation templates

Issue #24 asked for a way to set up documentation in each repository, such as a procedure for withdrawing a bad
release. This uses the same copy-if-missing approach, but documentation belongs to the whole repository, not to the
solution, and not every repository wants it. So setting `EndjinCreateDocumentationTemplates` to `true` copies the
package's documentation templates into the root of the Git repository (or the solution folder, outside a Git
repository), and the package never overwrites them. It is off by default.
