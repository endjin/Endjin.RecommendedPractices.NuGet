# Releasing

<!--
  This file was added to your repository by the Endjin.RecommendedPractices NuGet package, because a project sets
  EndjinCreateDocumentationTemplates to true. The package never overwrites it, so edit it to describe how this
  repository releases. Delete any parts that don't apply.
-->

## How a release happens

Describe how a release is triggered and what it publishes. For repositories that use endjin's
[pr-autoflow](https://github.com/endjin/pr-autoflow) process:

1. A pull request into the default branch gets the `pending_release` label when it is opened, unless it has the
   `no_release` label.
2. When a pull request is merged, the `auto_release` workflow tags the default branch with the next version
   (calculated by GitVersion) if any merged pull requests still have `pending_release`, and removes those labels.
3. The tag build publishes the release: packages to their feed, and a GitHub release with the packages attached.

To stop a merge from releasing, add the `no_release` label to the pull request before merging it.

## If publishing fails

Describe how to recover, for example: fix the cause (such as an expired credential), then re-run the tag build.
Publishing steps should skip packages that were already pushed.

## Removing a bad release

Package feeds such as nuget.org don't let you delete a version, so a bad release is withdrawn and replaced, not
removed.

1. **Release a fix.** Revert or fix the change in a pull request that will release (with the `pending_release`
   label). Consumers move forward to the next version, not back.
2. **Deprecate the bad version.** On nuget.org, use the package's **Manage** page to deprecate the version of each
   affected package. Choose the reason (usually *Has critical bugs*), select the fixed version as the alternative,
   and explain the problem in the message.
3. **Unlist it** if nobody should take it any more. Unlisting hides the version from search and from
   `dotnet add package`, but restore still works for projects that already reference it.
4. **Update the GitHub release** notes to say that the version is withdrawn and which version replaces it. Keep the
   tag: versioning depends on it. Delete the release only if its assets are harmful to download.
5. **Record it in the changelog**, with the reason and a link to the fixed version.
