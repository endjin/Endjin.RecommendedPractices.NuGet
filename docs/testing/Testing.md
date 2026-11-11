# How to test Endjin.RecommendedPractices

There's no good way to debug MSBuild extensions in a NuGet package. It appears that the only way to get these things to run at all is to add a reference to the package through the normal NuGet mechanisms. If you do this through NuGet.org, this results in a very slow developer experience, and typically a large number of unwanted preview releases up on NuGet.org (which never lets you truly delete anything).

So the only sensible way to develop and test these kinds of NuGet packages is to set up a local NuGet package feed.

You need the .NET 10 SDK or later. You don't need `nuget.exe`.

First, you'll need to build the `.nupkg` files. You'll want to supply version numbers distinctively different from the current real packages. From the `src` folder you can run something like this:

```
dotnet pack ./Endjin.RecommendedPractices.NuGet/Endjin.RecommendedPractices.nuspec --version 9.9.9 --output packages
dotnet pack ./Endjin.RecommendedPractices.NuGet.GitHub/Endjin.RecommendedPractices.GitHub.nuspec --version 9.9.9 --output packages
```

This will build the `nupkg` files into the `packages` folder.

`dotnet pack` always leaves out files whose names start with a dot. That's why the package's default `.editorconfig` is stored as `build/default.editorconfig`. The build targets copy it to the solution folder as `.editorconfig`.

Next, decide where you're going to put your local package store. It just needs to be a local folder, and it can go wherever you like. The following examples use `C:\dev\NuGetLocal`. These commands will create the folder if it doesn't already exist.

```
dotnet nuget push packages/Endjin.RecommendedPractices.9.9.9.nupkg --source C:\dev\NuGetLocal
dotnet nuget push packages/Endjin.RecommendedPractices.GitHub.9.9.9.nupkg --source C:\dev\NuGetLocal
```

The [PackAndReleaseForTest.ps1](../../src/PackAndReleaseForTest.ps1) file performs both `pack` and both `push` operations in a single step, enabling you to run just this command:

```
./PackAndReleaseForTest.ps1 9.9.9
```

You can optionally specify the local repository path as the second argument. (It defaults to `C:\dev\NuGetLocal`).


You can use the local package feed by adding a `NuGet.config` file to any .NET solution folder with these contents:

```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <add key="NuGetLocal" value="C:\dev\NuGetLocal" />
  </packageSources>
</configuration>```
```

This works for Visual Studio. It's not clear if it will work for command line development—various Stack Overflow posts suggest you need a `<config>` section that adds the local path value under two different keys: `repositoryPath` and `globalPackagesFolder`. But in my experience, this goes on to break in quite hard to diagnose ways, so I wouldn't recommend it. The alternative is to add this feed to your global feed configuration using either `dotnet nuget add source` or the Visual Studio feed settings page.

To run the automated tests, run `./build.ps1 -Tasks Test` from the repository root, or run `run-tests.ps1` directly. The automated tests ([Endjin.RecommendedPractices.Nuget.Tests.ps1](../../src/Endjin.RecommendedPractices.Nuget.Specs/Endjin.RecommendedPractices.Nuget.Tests.ps1), run by `run-tests.ps1`) don't change your NuGet configuration. They pack both packages, then restore the specs solution with a temporary config file passed to `dotnet restore --configfile`.

However you choose to do it, once the local feed is available, you can add a reference to the versions of the packages in your local feed.

Any time you want to try a change, you need to bump the version number so the tooling knows something is different.