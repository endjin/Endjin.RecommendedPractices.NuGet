# Separate repository-host-specific elements

## Status

Accepted.

## Context

In v1, the `Endjin.RecommendedPractices` NuGet package presumed that you were hosting your project on GitHub, and would produce errors if you didn't. This blocked two important scenarios:

- using `Endjin.RecommendedPractices` on projects hosted in Azure DevOps
- using `Endjin.RecommendedPractices` in spikes that might later be incorporated into other projects

The first of these is important because although Microsoft has signalled that they ultimately want to move everyone onto GitHub, as of the start of 2022 this is a long way from being reality. There are many good reasons to want to continue to use Azure DevOps, and many of our customers do. Some of our internal projects have remained there. We want to be able to use this package on such projects.

The second scenario has come up many times. It is common to develop little prototypes of something for experimental purposes, with the intention being to incorporate it into some existing repository if the results of the experiment look good. In the cases where the spike does get promoted to production code, we will want it to conform to our usual conventions. And it is very much easier to conform to these conventions from the very start—you can avoid having a large "fix all the warnings" phase if you have been constantly nudged in the right direction from early on. So it is unhelpful that we have been unable to add in the recommended practices package to projects at this stage.


## Decision

Split the GitHub-specific aspects that are in v1 of `Endjin.RecommendedPractices` into a separate `Endjin.RecommendedPractices.GitHub` package. That package will:

- contain the GitHub-specific elements
- have a transient dependency on `Endjin.RecommendedPractices`

That second point is important because it enables projects that are happy with how v1 works today to continue to have a single package reference. It will be to `Endjin.RecommendedPractices.GitHub` instead of `Endjin.RecommendedPractices`, but it's a relatively small change. To ease the transition, the new `Endjin.RecommendedPractices` will detect when it is in use on a GitHub-backed project, and will suggest using `Endjin.RecommendedPractices.GitHub` instead. (This warning can be disabled by setting a property in cases where someone really wants to use `Endjin.RecommendedPractices` without Source Link in a GitHub repo.)


## Consequences

This solves the problems above:

- `Endjin.RecommendedPractices` v2 will be usable on projects hosted in Azure DevOps
- spikes not yet checked into a hosted repo will be able to use `Endjin.RecommendedPractices`

It has an additional benefit:

- It it were to look useful in the future, we could add other host-specific packages

This also leaves the door open for supporting other source hosts, most notably Azure DevOps. We've not added support for Source Link to Azure DevOps yet, because we don't currently have any scenarios that require it, but this split means it would become a relatively straightforward thing to add.