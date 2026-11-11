# Releasing Endjin.RecommendedPractices

## How a release happens

Releases use endjin's [pr-autoflow](https://github.com/endjin/pr-autoflow) process:

1. A pull request into `main` gets the `pending_release` label when it is opened (by
   [approve_and_label](../../.github/workflows/dependabot_approve_and_label.yml)), unless it has the `no_release`
   label. Dependabot pull requests only get it if they match `AUTO_RELEASE_PACKAGE_WILDCARD_EXPRESSIONS` in
   [pr-autoflow.json](../../.github/config/pr-autoflow.json).
2. When a pull request is merged, [auto_release](../../.github/workflows/auto_release.yml) checks whether any merged
   pull requests still have `pending_release`, and waits for any open Dependabot pull requests that are due to be
   merged automatically. If a release is due, it tags `main` with the version GitVersion calculates (for example
   `3.0.1`) and removes the `pending_release` labels.
3. The tag build ([build.yml](../../.github/workflows/build.yml)) runs `FullBuildAndPublish`. It packs both packages
   with the tag's version, creates a GitHub release with the packages attached, and pushes them to nuget.org.

To stop a merge from releasing, add the `no_release` label to the pull request before merging it.

Versions come from GitVersion ([GitVersion.yml](../../GitVersion.yml)). Each release increments the patch number. To
release a new major or minor version, change `next-version` in `GitVersion.yml` in the pull request that needs it.

Update [CHANGELOG.md](../../CHANGELOG.md) in every pull request that changes the packages' behaviour.

## If the publish fails

The GitHub release is created before the packages are pushed to nuget.org. If the push fails (for example because
of a credentials problem), fix the cause and re-run the tag build: the push uses `--skip-duplicate`, and the GitHub
release step updates the existing release.

## Removing a bad release

nuget.org doesn't let you delete a package version, so a bad release is withdrawn and replaced, not removed.

1. **Release a fix.** Revert or fix the change in a pull request with the `pending_release` label. Merging it
   releases the next patch version, which is what most consumers will pick up (Dependabot and floating versions
   move forward, not back).
2. **Deprecate the bad version on nuget.org.** On the package's **Manage** page, deprecate the version for both
   packages (`Endjin.RecommendedPractices` and `Endjin.RecommendedPractices.GitHub`). Choose the reason (usually
   *Has critical bugs*), select the fixed version as the alternative, and explain the problem in the message.
   NuGet shows the deprecation in Visual Studio, `dotnet list package --deprecated` and on nuget.org.
3. **Unlist it** if nobody should take it any more. Unlisting hides the version from search and from `dotnet add
   package`, but restore still works for projects that already reference it, so builds don't break.
4. **Update the GitHub release.** Edit the release's notes to say that the version is withdrawn and which version
   replaces it. Leave the tag in place: the build that produced the packages depends on it, and GitVersion
   calculates later versions from it. Delete the GitHub release only if its assets are harmful to download.
5. **Record it in the changelog.** Add a note to the bad version's entry in [CHANGELOG.md](../../CHANGELOG.md) saying
   that it was withdrawn and why, and link to the fixed version.
