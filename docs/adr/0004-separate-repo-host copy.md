# Git repository URL not determined automatically

## Status

Accepted.

## Context

Since v1, the `Endjin.RecommendedPractices` NuGet package has required that the Git repository URL be specified as `EndjinRepositoryUrl`. As of V2, this is only required by the `Endjin.RecommendedPractices.GitHub` package.

- using `Endjin.RecommendedPractices` on projects hosted in Azure DevOps
- using `Endjin.RecommendedPractices` in spikes that might later be incorporated into other projects

The first of these is important because although Microsoft has signalled that they ultimately want to move everyone onto GitHub, as of the start of 2022 this is a long way from being reality. There are many good reasons to want to continue to use Azure DevOps, and many of our customers do. Some of our internal projects have remained there. We want to be able to use this package on such projects.

The second scenario has come up many times. It is common to develop little prototypes of something for experimental purposes, with the intention being to incorporate it into some existing repository if the results of the experiment look good. In the cases where the spike does get promoted to production code, we will want it to conform to our usual conventions. And it is very much easier to conform to these conventions from the very start—you can avoid having a large "fix all the warnings" phase if you have been constantly nudged in the right direction from early on. So it is unhelpful that we have been unable to add in the recommended practices package to projects at this stage.


## Decision

Split the GitHub-specific aspects that are in v1 of `Endjin.RecommendedPractices` into a separate `Endjin.RecommendedPractices.GitHub` package. That package will:

- contain the GitHub-specific elements
- have a transient dependency on `Endjin.RecommendedPractices`

That second point is important because it enables projects that are happy with how v1 works today can continue to have a single package reference. It will be to `Endjin.RecommendedPractices.GitHub` instead of `Endjin.RecommendedPractices`, but it's a relatively small change.


## Unresolved issue

All projects using v1 currently use the GitHub functionality. What do we want the behaviour to be when they upgrade to v2? A downside of this split is that the upgrade would cause this functionality to stop working silently. The effect of this would be that projects currently enjoying source-level debugging through VS's GitHub integration would suddenly stop doing that.

One way to avoid this would be for the main `Endjin.RecommendedPractices` package to detect whether a source code host package is present. (We could have that package set some build variable to indicate this.) And it could then issue a warning suggesting that the developer might want to change the reference to `Endjin.RecommendedPractices.GitHub`. And for those who don't want it, we'd need to advise them to set a variable themselves to indicate that they know about this issue and specifically don't want the GitHub bits.

An alternative would be to keep `Endjin.RecommendedPractices` doing exactly what it does now, but to move all the guts into some `Endjin.RecommendedPractices.NonSourceHostSpecific` component, so that developers who need the scenarios outlined above can get them.

## Consequences

This solves the problems above:

- `Endjin.RecommendedPractices` v2 will be usable on projects hosted in Azure DevOps
- spikes not yet checked into a hosted repo will be able to use `Endjin.RecommendedPractices`

It has an additional benefit:

- It it were to look useful in the future, we could add other host-specific packages


It also has a downsides—none of the solutions to the unresolved issue above looks ideal.
