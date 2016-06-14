# Snappy Nextcloud Contribution Guide

Welcome! We're a pretty friendly community and we're thrilled that you want to
help make this snap even better. However, we do ask that you follow some general
guidelines while doing so, just so we can keep things organized around here.

1. Make sure an [issue][1] is created for the bug you're about to fix, or
   feature you're about to add. Keep them as small as possible.

2. We use a forking, feature-based workflow.

   Make a fork of this repository, and create a branch based on `develop` named
   specifically for the feature on which you'd like to work. Make your changes
   there. Commit often.

3. Squash commits into one, well-formatted commit. Mention the issue being
   resolved in the commit message on a line all by itself like `Fixes #<bug>`
   (refer to [closing issues via commit messages][2] for more keywords you can
   use).

   If you really feel like there should be more than one commit in your branch,
   then you're probably trying to introduce more than one feature and you should
   make another branch (and issue) for it.

4. Submit a pull request to get changes from your branch into `develop` (no
   merge requests should be made into `master`). Mention which bug is being
   resolved in the description.

[1]: https://github.com/kyrofa/nextcloud-snap/issues/new
[2]: https://help.github.com/articles/closing-issues-via-commit-messages/
