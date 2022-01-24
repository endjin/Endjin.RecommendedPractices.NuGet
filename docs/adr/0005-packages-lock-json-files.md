# Use of packages.lock.json files in top-level projects

We want to minimize the amount of effort required to stay up to date with Microsoft .NET NuGet package updates. We do this by using floating version numbers in leaf IP packages, and using `package.lock.json` files in 'top of the food chain' projects (e.g. Azure Function hosts, Web Apps, Console Apps, Test Projects) to ensure repeatable builds. We would like the `Endjin.RecommendedPractices` NuGet package should make this happen by default as much as possible, but unfortunately, NuGet packages don't get to extend the relevant part of the build process, so the best we can do is to check that the right properties have been set, and generate advisory diagnostics when they haven't.

## Status

Accepted.

## Context

Endjin uses GitHub's [Dependabot](https://docs.github.com/en/rest/reference/dependabot) to help keep package references up to date, but this caused a problem in our 'leaf' projects. In [`Corvus`](https://github.com/corvus-dotnet/), we don't use a monorepo—we have separate repositories for each distinct area of functionality. Initially after we enabled Dependabot, each time Microsoft published a new patch release for .NET we would be buried in a vast number of Dependabot notifications. Dependabot's lack of support for aggregating multiple changes into a single PR made matters worse, with the effect that with each such .NET release, we would need to do manual updates to every project across our IP estate.

In most cases this was meaningless busy work, because of Microsoft's policy of giving the majority of their `System.*` and `Microsoft.Extensions.*` NuGet packages the same version number. E.g., when .NET 6.0.1 ships, Microsoft releases a 6.0.1 version of `Microsoft.Extensions.DependencyInjection.Abstractions` even if absolutely no code in that package has changed.

Patch releases for these particular components generally have extremely high levels of compatibility. Very often, the only thing to change between patch releases is the version number (thanks to the policy of releasing new versions of all these components every time .NET is updated). But even when there are genuine changes, Microsoft has very high standards for compatibility with these changes.

The upshot is that for the Microsoft-authored components that are on this versioning regime, there is rarely any reason not to use the latest patch version.

We wanted to avoid having to update 20+ of our packages every few weeks just to bump the version numbers for all the references to these kinds of packages. So we moved over to using floating version numbers. A `<PackageReference>` element in a `.csproj` file can have a `Version` string of the form `"[6.0.*,)"`.

If you're not familiar with NuGet package strings, this can look a little odd. It combines two syntaxes. The first is the range syntax. `"[6.0.0,7.0.0]"` means "any version from 6.0.0 to 7.0.0 inclusive", so this demands at least version 6.0.0, but would also be happy with 6.0.4, 6.3.4, or 7.0.0, but would not accept 7.0.1. You can make the upper bound exclusive by using a `)`, so `"[6.0.0,7.0.0)"` would accept any 6.x.x version, but would reject 7.0.0 or anything higher. If you omit the higher value, then that means you're prepared to work with any higher version number. E.g. `"[6.0.4,)"` requires at least version 6.0.4, but is prepared to work with literally any version number higher than that (e.g. version 132.97.12 would be fine). So that's version ranges. And then the `*` denotes a floating version number. E.g. `6.0.*` indicates that any version starting with `6.0` is acceptable, but, *if* no other packages involved have any more specific requirements, that the highest available patch should be used. So if the highest version starting `6.0` is `6.0.4`, this will use that, unless some other component involved in the application is demanding a lower version. And then in combination, a version string `"[6.0.*,)"` means "I'll work with any version of this package starting from 6.0.0, but if nothing else in the project expresses a preference, I'll select the highest available patch version for 6.0."

The effect of this is that when an application consumes our Corvus packages, it will pick up transitive references to all required `Microsoft.Extensions.*` and `System.*` packages that the referenced Corvus packages need, and those transitive references will automatically pick up the latest available patch.

The upshot of this is that we don't need to update Corvus packages each time a new .NET version ships. Those floating version numbers mean that any application using Corvus is automatically going to acquire the latest .NET packages unless it deliberately selects older versions.

This removes the problem of having to get on the version update treadmill for tens of projects several times a month, but it introduces a new problem: applications consuming our packages now get different transitive dependencies over time. If you build an application when the latest version of .NET is 6.0.1, you'll get all 6.0.1 references, but if you build the exact same version again several months later when .NET has moved onto 6.0.4, you'll now be building against 6.0.4. This is bad because it means the exact same commit in a repo will build different results over time.

Fortunately there's a mechanism to deal with this. If you set the `<RestorePackagesWithLockFile>` build property to `true`, the build tools will automatically emit a `packages.lock.json` file describing all the versions of all dependencies that were determined at a particular moment in time. We check these into source control. And then, to ensure repeatable builds, we need to take an additional step:

When building on the build server, we set the `RestoreLockedMode` build property to `true`, which ensures that when the "restore" step executes, NuGet does not look for new versions of anything, and instead just restores whatever the `packages.lock.json` file says.

We do this only when running CI builds, by making the property conditional—we only set `RestorePackagesWithLockFile` if `ContinuousIntegrationBuild` is true. That way, when a developer opens a solution in Visual Studio, NuGet will automatically scan for new patch releases for any components referenced through floating versions, and will update the `packages.lock.json` file if it finds any. The upshot is that opening up a project to work on it automatically updates all your floating references, but automated builds build whatever was current at the point in time when you committed the code.

The only projects that should be using `packages.lock.json` files are what you might call "top of food chain" projects—essentially anything that gets run directly. For example, an Azure Functions host project needs to do this. So do test projects, and projects that build command line tools. But if an application builds its own library component, that should not have a `packages.lock.json` file. It should allow floating version references to flow through transitively, and if it defines its own references to Microsoft components on the lock-step-with-.NET versioning regime, they should also be floating references. It is always ultimately a running application (or test project) that determines exactly how all NuGet packages are resolved, so these are the only places where we want these lock files.

We had hoped with v2 of the `Endjin.RecommendedPractices` NuGet package to automate the settings required to generate `packages.lock.json` when needed. Unfortunately, there's a problem.

When running a NuGet package restore, the .NET SDK excludes MSBuild `.props` and `.targets` files contributed by NuGet packages. There's a very good reason for this: the result of this step should be stable, and if NuGet packages were able to influence the NuGet package restore process, it might not be. Given an initial condition of "Repo just checked out, build never run" it's entirely possible that none of the NuGet packages being used by the project will have been downloaded onto the machine yet. (They might be in the package cache, but they might not be.) So at that stage they can't have any effect on the restore process because they're not present yet, and the build system needs to run the package restore process to fetch them. But once they have been downloaded, if they were allowed to have an impact on the restore process, that might mean that restoring your packages a second time might produce different results from restoring them the first time.

To avoid this, the .NET SDK sets the `ExcludeRestorePackageImports` build variable to `true` when running package restores, which prevents the normal import of `props` and `targets` files from NuGet packages.

Unfortunately, the generation of the `packages.lock.json` file takes place as part of this phase in which package imports are excluded. This is a reasonable design decision, but it does mean it's impossible for us to fully automate the setting of these properties through extensions to the build system supplied by NuGet packages. The only way we could do it would be to have `Endjin.RecommendedPractices` add another file into the main source tree (much as we do with `.editorconfig` today) and to tell people to `<Import>` that instead of the current import via the `EndjinProjectPropsPath` build variable (which doesn't work during the NuGet restore phase because `EndjinProjectPropsPath` doesn't get set in that phase thanks to `ExcludeRestorePackageImports`). However, these emitted files are a problem: they are part of the consuming project's source tree, we can't stop people editing them, and there isn't a good way to modify them if later versions of `Endjin.RecommendedPractices` needs to make changes for any reason.

## Decision

Starting with v2 of `Endjin.RecommendedPractices`, "top of food chain" projects will detect whether the `RestorePackagesWithLockFile` build variable has been set to `true`, and will issue an advisory diagnostic instructing developers to add a suitable `<PropertyGroup>`. When these projects are running a CI build (`ContinuousIntegrationBuild` is `true`) we perform a similar check that the set `RestoreLockedMode` is also set to true.

We identify a project as being "top of food chain" when either of the following conditions are met:

* `OutputType` build variable is `Exe` or `WinExe`
* `OutputType` build variable is `Library` and `AzureFunctionsVersion` has a non-empty value

If a project that is at the top of the food chain is built in a way that is not picked up by this automatic detection, it can set the `EndjinAutoPackagesLock` property to true to declare that it's that sort of project (although all this does is enable the checks—the project will still need to add the necessary settings to enable lock file handling). Conversely, if a project using `Endjin.RecommendedPractices` matches the criteria above but does not want a packages lock file for some reason, the feature can be disabled by setting the `EndjinDisableAutoPackagesLock` build property to `true`.

## Consequences

`Endjin.RecommendedPractices` will verify that applications consuming components using floating version references (such as Corvus) have suitable settings in their `.csproj`. When they don't the build diagnostic explains exactly how to modify the project file.

Developers will still have to make manual edits to their `.csproj` to comply, but this is unavoidable because of the way the .NET SDK excludes contributions to the build process from NuGet packages during the package restore phase. (Even the workaround in which we emit a file into the repo would still require the user to make an edit to their `.csproj`, and it has problems of its own.)
