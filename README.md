# Endjin.RecommendedPractices.NuGet

A NuGet package that configures .NET projects for endjin's recommended engineering practices

When you add a reference to this package via NuGet, it does the following:

* sets a default (c) string (note: if you're not endjin, you will probably want to change this)
* configures XML doc output
* provides default settings for NuGet package metadata
* enables sourcelink on projects that are building NuGet packages
* makes warnings errors
* disables the more vexing Roslynator and Stylecop warnings
* provides default stylecop.json, StyleCop.ruleset, and .editorconfig files at the solution level if you don't yet have theses
* detects whether you're building for a NuGet package or a non-packaged target, and adjusts the warning set slightly accordingly (unless you ask it not to)
* ensures that if you have a local.setting.json it's configured to be copied to the output folder if it changes
* adds a reference to StyleCop.Analyzers

## CI / CD

The project is [hosted on Azure DevOps](https://dev.azure.com/endjin-labs/Endjin.RecommendedPractices.NuGet) under the `endjin-labs` org.

## Packages

The NuGet packages for the project, hosted on NuGet.org are:

- [Endjin.RecommendedPractices.NuGet](https://www.nuget.org/packages/Endjin.RecommendedPractices.NuGet)

## Licenses

[![GitHub license](https://img.shields.io/badge/License-Apache%202-blue.svg)](https://raw.githubusercontent.com/endjin/Endjin.RecommendedPractices.NuGet/master/LICENSE)

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
