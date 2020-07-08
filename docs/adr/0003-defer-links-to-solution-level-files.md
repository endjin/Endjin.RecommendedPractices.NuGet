# Defer display of links to generated solution-level files in Solution Explorer

## Status

Accepted.

## Context

We optionally generate certain solution-level files (e.g., `PackageIcon.png`, `stylecop.json`) and where appropriate or
necessary, we also arrange for these files to show up in project. (This is necessary for `PackageIcon.png`—the file
needs to be in the project for the corresponding `<PackageIcon>` property to work.) However, this causes problems
when first adding `Endjin.RecommendedPractices` to a project.

The problem is that we don't get the opportunity to generate these files until a build occurs. However, Visual Studio
will attempt to display any files we add to the project immediately after the reference to `Endjin.RecommendedPractices`
has been added, and before any build has occurred. The upshot is that for these kinds of files, Visual Studio shows
them with a big red X, because the physical files they refer to don't exist. Worse, even after the build creates the
files, the crosses remain, because Visual Studio appears not to update such things when the filesystem changes.

The effect of this was that after adding `Endjin.RecommendedPractices` to a project you would need to build, then
unload the solution, and then reload it, before everything looked OK.


## Decision

We now make all additions of files to a project conditional on the file existing. E.g.:

We are going to require all projects to contain this line at the top of the `csproj`:

```xml
<ItemGroup Condition="($(EndjinDisableCodeAnalysis) != 'true') and (Exists('$(SolutionDir)stylecop.json'))">
  <AdditionalFiles Include="$(SolutionDir)stylecop.json" Link="stylecop.json" />
</ItemGroup>  
```

This is how we make a file link to `stylecop.json` appear in a project. It used to be conditional only on the
`EndjinDisableCodeAnalysis` build variable. But now we have an additional `Exists` test.

## Consequences

This fixes the problem in which users see red crosses appearing immediately after adding a reference to
`Endjin.RecommendedPractices`. It also appears to remove the need to reload—although Visual Studio doesn't appear to
realise it can remove the red X when a file appears on disk, it does seem to be smart enough to notice when new
project items come into existence after a build.

So the experience of adding `Endjin.RecommendedPractices` with these changes is that we no longer get file items
with a red X appearing, but as soon as the first build completes (even if it produces errors) the relevant
new items will appear in Solution Explorer.