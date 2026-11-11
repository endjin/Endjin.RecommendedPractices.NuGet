# Endjin.RecommendedPractices.NuGet

A NuGet package that configures .NET projects for endjin's recommended engineering practices

**Requirements:** the .NET 10 SDK or later. .NET 10 is the earliest supported version of .NET, and the package stops the build with an error on older SDKs. (You can still target older frameworks, such as `netstandard2.0`, from a supported SDK.)

## Packages

- [Endjin.RecommendedPractices](https://www.nuget.org/packages/Endjin.RecommendedPractices): for any .NET project.
- [Endjin.RecommendedPractices.GitHub](https://www.nuget.org/packages/Endjin.RecommendedPractices.GitHub): for projects in a GitHub repository. It includes `Endjin.RecommendedPractices`, and also sets the package's repository type, project URL and release notes from the GitHub repository. If a project in a GitHub repository references `Endjin.RecommendedPractices` instead, the build shows a warning.

## Using the package

Add a reference with `PrivateAssets="all"`. `dotnet add package` and Visual Studio do this for you, because it is a development dependency:

```xml
<PackageReference Include="Endjin.RecommendedPractices.GitHub" Version="3.0.0" PrivateAssets="all" />
```

You must also import `Endjin.Project.props` at the top of the project file, before any other content. Some properties, such as `RootNamespace`, can only be set correctly from there. If the import is missing, the build fails with an error that tells you what to add:

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <Import Project="$(EndjinProjectPropsPath)" Condition="$(EndjinProjectPropsPath) != ''" />

  ...
</Project>
```

When you add a reference to this package via NuGet, it does the following:

* sets a default copyright notice (if you're not endjin, set the `Copyright` property in your project)
* configures XML documentation output
* provides default settings for NuGet package metadata, such as the authors, the package icon, license acceptance and symbol packages
* makes compiler warnings errors
* adds the StyleCop.Analyzers and Roslynator.Analyzers code analyzers (set `EndjinDisableCodeAnalysis` to `true` to turn them off)
* turns off the more vexing Roslynator and StyleCop rules
* provides default `stylecop.json` and `.editorconfig` files at the solution level if you don't yet have these
* detects whether you're building a NuGet package or a non-packaged target, and doesn't require XML documentation in non-packaged targets (unless you ask it to)
* ensures that if you have a `local.settings.json` file, it is copied to the output folder when it changes
* checks that projects producing runnable artifacts (such as console apps, test projects and Azure Functions) use `packages.lock.json` files
* marks builds on Azure Pipelines and GitHub Actions as CI builds (`ContinuousIntegrationBuild`)

Source Link comes from the .NET SDK, which enables it for projects in GitHub, Azure Repos, GitLab and Bitbucket repositories.

The set of code analysis rules will gradually change because the .NET SDK incorporates new ones over time. If you want to pin to a particular era of rules, you can set the `EnableNETAnalyzers` build property to false, and then add a reference to the [`Microsoft.CodeAnalysis.NetAnalyzers` NuGet package](https://www.nuget.org/packages/Microsoft.CodeAnalysis.NetAnalyzers) instead.

## CI / CD

The build uses [ZeroFailed](https://github.com/zerofailed/ZeroFailed) and runs in [GitHub Actions](.github/workflows/build.yml). To run it locally (PowerShell 7 and the .NET 10 SDK required):

```
./build.ps1
```

This runs the Pester specs and packs both packages into `_packages`. The build is configured in [.zf/config.ps1](.zf/config.ps1).

Releases use endjin's [pr-autoflow](https://github.com/endjin/pr-autoflow) process. When a pull request labelled `pending_release` is merged into `main`, [auto_release](.github/workflows/auto_release.yml) tags `main` with the next version. The tag build pushes the packages to nuget.org and creates a GitHub release with the packages attached.

See the [changelog](CHANGELOG.md) for what changed in each version.

## Licenses

[![GitHub license](https://img.shields.io/badge/License-Apache%202-blue.svg)](https://raw.githubusercontent.com/endjin/Endjin.RecommendedPractices.NuGet/main/LICENSE)

This project is available under the Apache 2.0 open source license.

For any licensing questions, please email [&#108;&#105;&#99;&#101;&#110;&#115;&#105;&#110;&#103;&#64;&#101;&#110;&#100;&#106;&#105;&#110;&#46;&#99;&#111;&#109;](&#109;&#97;&#105;&#108;&#116;&#111;&#58;&#108;&#105;&#99;&#101;&#110;&#115;&#105;&#110;&#103;&#64;&#101;&#110;&#100;&#106;&#105;&#110;&#46;&#99;&#111;&#109;)

## Project Sponsor

This project is sponsored by [endjin](https://endjin.com), a UK based Microsoft Gold Partner for Cloud Platform, Data Platform, Data Analytics, DevOps, a Power BI Partner, and .NET Foundation Corporate Sponsor.

We help small teams achieve big things.

For more information about our products and services, or for commercial support of this project, please [contact us](https://endjin.com/contact-us). 

We produce two free weekly newsletters; [Azure Weekly](https://azureweekly.info) for all things about the Microsoft Azure Platform, and [Power BI Weekly](https://powerbiweekly.info).

Keep up with everything that's going on at endjin via our [blog](https://blogs.endjin.com/), follow us on [Twitter](https://twitter.com/endjin), or [LinkedIn](https://www.linkedin.com/company/1671851/).

Our other Open Source projects can be found on [our website](https://endjin.com/open-source)

## Code of conduct

This project has adopted a code of conduct adapted from the [Contributor Covenant](http://contributor-covenant.org/) to clarify expected behavior in our community. This code of conduct has been [adopted by many other projects](http://contributor-covenant.org/adopters/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [&#104;&#101;&#108;&#108;&#111;&#064;&#101;&#110;&#100;&#106;&#105;&#110;&#046;&#099;&#111;&#109;](&#109;&#097;&#105;&#108;&#116;&#111;:&#104;&#101;&#108;&#108;&#111;&#064;&#101;&#110;&#100;&#106;&#105;&#110;&#046;&#099;&#111;&#109;) with any additional questions or comments.
