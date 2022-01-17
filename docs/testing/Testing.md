# How to test Endjin.RecommendedPractices

There's no good way to debug MSBuild extensions in a NuGet package. It appears that the only way to get these things to run at all is to add a reference to the package through the normal NuGet mechanisms. If you do this through NuGet.org, this results in a very slow developer experience, and typically a large number of unwanted preview releases up on NuGet.org (which never lets you truly delete anything).

So the only sensible way to develop and test these kinds of NuGet packages is to set up a local NuGet package feed.

First, you'll need to build the `.nupkg` files. You'll want to supply version numbers distinctively different from the current real packages. From the `src` folder you can run something like this:

```
nuget pack .\Endjin.RecommendedPractices.NuGet\Endjin.RecommendedPractices.nuspec -Version 9.9.9
nuget pack .\Endjin.RecommendedPractices.NuGet.GitHub\Endjin.RecommendedPractices.GitHub.nuspec -Version 9.9.9
```

This will build the `nupkg` files directly into your local folder.

Next, decide where you're going to put your local package store. It just needs to be a local folder, and it can go wherever you like. I'm using `C:\dev\NuGetLocal`.

```
nuget add Endjin.RecommendedPractices.9.9.9.nupkg -source C:\dev\NuGetLocal
nuget add Endjin.RecommendedPractices.GitHub.9.9.9.nupkg -source C:\dev\NuGetLocal
```

You can use this by adding a `NuGet.config` file to any .NET solution folder with these contents:

```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <config>
    <add key="globalPackagesFolder" value="C:\dev\NuGetLocal" />
    <add key="repositoryPath" value="C:\dev\NuGetLocal" />
  </config>
  <packageSources>
    <add key="NuGetLocal" value="C:\dev\NuGetLocal" />
  </packageSources>
</configuration>
```

The `<config>` section is necessary for command line usage (e.g. `dotnet add My.csproj package Endjin.RecommendedPractices.GitHub -v 9.9.9`). The `<packageSources>` section is there to keep Visual Studio happy, because it seems not to recognize the other part.

With this in place you can add a reference to the versions of the packages in your local feed.