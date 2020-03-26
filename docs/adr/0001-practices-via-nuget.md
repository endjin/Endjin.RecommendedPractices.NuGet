# Directory.props integration

## Status

Status quo.

## Context

Our initial way of implementing standard build practices was to copy a bunch of files into place in every project. There were various problems:

- there was no single master location from which to copy the files
- each project tended to make its own tweaks and it was never clear which were project-specific, and which were useful enhancements
- there was no procedure defined for pushing updates to the standards out to all projects
- there was no established mechanism around how to handle .NET Core 3.1 or various .NET Standard versions
- there was an inconsistent mixture of mechanisms—some use of imports, some use of Directory.props

We could have tweaked the existing mechanism. For example we could have defined a repository somewhere whose job was to hold the latest master copies of the files. We could have established conventions that could have clarified which parts of the config were the unaltered standard mechanism, and which parts are project-specific modifications.

However, our `Endjin.RecommendedPractices.AzureDevopsPipelines.GitHub` works a lot more smoothly, partly as a result of not going down this path. Instead, it uses a mechanism designed specifically to support reuse (Azure DevOps pipeline templates), and which ensures there is exactly one master copy that everything shares, which has built-in extensibility points to enable project-specific adjustments.

Because projects don't copy and then modify the relevant files—instead they just refer to them and then plug into the extensibility points supplied—it is absolutely clear when something is a project-specific tweak. And this also provides a straightforward mechanism for updates: when something breaks the build (e.g., as happened when .NET Core SDK 3.1.200 came out) we can push a single update to fix everything.

What if `Endjin.RecommendedPractices` could enjoy all these same benefits as `Endjin.RecommendedPractices.AzureDevopsPipelines.GitHub`? The key characteristics are:

- one definitive copy of the relevant files, distributed through a mechanism designed to enable sharing of such files
- clearly-defined extensibility points to provide individual projects with the flexibility they require, without needing them to have their own copies of everything


## Decision

Move our standard build files into a NuGet package: [Endjin.RecommendedPractices.NuGet](https://www.nuget.org/packages/Endjin.RecommendedPractices.NuGet). Define extensibility mechanisms as required.

## Consequences

This solves the problems above:

- this repo, which builds the package, defines the single source, and our listing on the NuGet store provides the mechanism by which it gets distributed to projects that need it
- by using clearly-defined extensibility points, it becomes clear what's a project-specific feature, and what's not
- NuGet defines a mechanism for pushing out updates
- dependabot provides us with a way to discover that updates are available
- it is entirely possible to build multi-target NuGet packages
- this is an opportunity to rationalise the design

It has some additional benefits:

- the process for adhering to our coding standards becomes simple and clear-cut
- this approach seems to be less confusing for some .NET tooling, because that all understands what a NuGet package is, but can get a bit bamboozled when we use imports


It also has some downsides:

- problems in the build can be harder to diagnose because things are less transparent
- if a project needs an extensibility point that doesn't yet exist, there's greater friction as we need to produce a new version of this NuGet package
- there are some constraints around where exactly a NuGet package can inject itself into the build process (e.g., it appears it can't do anything that runs at the exact same moment that `Directory.props` would have run)