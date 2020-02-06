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
