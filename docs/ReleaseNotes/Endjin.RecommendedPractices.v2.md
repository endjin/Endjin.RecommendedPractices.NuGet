# Endjin.Recommended Practices release notes

## v2.0

* The GitHub Source Link functionality has been split out, and projects should now reference `Endjin.Recommended.GitHub` if they want this; `Endjin.Recommended` enables use of these practices on non-GitHub-hosted repos
* Code analysis rules are enabled in .NET 6.0 SDK by default, so we no longer use the settings designed for the older mechanisms
* The ruleset file, which was deprecated in Visual Studio 2019 16.5, has been removed, and all the relevant rules have moved into the `.editorconfig` file
* In 'Top of food chain' projects (Function hosts, web apps, test projects) verify that the use of `packages.lock.json` files has been correctly configured