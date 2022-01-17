# How to test Endjin.RecommendedPractices

There's no good way to debug MSBuild extensions in a NuGet package. It appears that the only way to get these things to run at all is to add a reference to the package through the normal NuGet mechanisms. If you do this through NuGet.org, this results in a very slow developer experience, and typically a large number of unwanted preview releases up on NuGet.org (which never lets you truly delete anything).

So the only sensible way to develop and test these kinds of NuGet packages is to set up a local NuGet package feed.

First, you'll need to build the `.nupkg` files. You'll want to supply version numbers distinctively different from the current real packages. From the `src` folder you can run something like this:

```
nuget pack .\Endjin.RecommendedPractices.NuGet\Endjin.RecommendedPractices.nuspec -NoDefaultExcludes -Version 9.9.9
nuget pack .\Endjin.RecommendedPractices.NuGet.GitHub\Endjin.RecommendedPractices.GitHub.nuspec -Version 9.9.9
```

This will build the `nupkg` files directly into your local folder.

Next, decide where you're going to put your local package store. It just needs to be a local folder, and it can go wherever you like. I'm using `C:\dev\NuGetLocal`.

```
nuget add Endjin.RecommendedPractices.9.9.9.nupkg -source C:\dev\NuGetLocal
nuget add Endjin.RecommendedPractices.GitHub.9.9.9.nupkg -source C:\dev\NuGetLocal
```

The [PackAndReleaseForTest.ps1](../../src/PackAndReleaseForTest.ps1) file performs both `pack` and both `add` operations in a single step, enabling you to run just this command:

```
./PackAndReleaseForTest.ps1 9.9.9
```

You can optionally specify the local repository path as the second argument. (It defaults to `C:\dev\NuGetLocal`).


You can use this by adding a `NuGet.config` file to any .NET solution folder with these contents:

```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <add key="NuGetLocal" value="C:\dev\NuGetLocal" />
  </packageSources>
</configuration>```

This works for Visual Studio. It's not clear if it will work for command line development—various Stack Overflow posts suggest you need a `<config>` section setting either `repositoryPath` or `globalPackagesFolder` or both, but in my experience, this goes on to break in quite hard to diagnose ways, so I wouldn't recommend it. The alternative is to add this feed to your global feed configuration using either the `nuget` tool or the Visual Studio feed settings page.

With this in place you can add a reference to the versions of the packages in your local feed.

Any time you want to try a change, you need to bump the version number so the tooling knows something is different.