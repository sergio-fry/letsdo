---
id: TASK-76
title: 'CI: automatic gem release on version tag (build, test, publish to RubyGems)'
status: To Do
assignee:
  - '@human'
created_date: '2026-09-04 09:19'
updated_date: '2026-09-13 13:29'
labels: []
dependencies: []
references:
  - .github/workflows/ci.yml
  - letsdo.gemspec
  - TASK-36
priority: medium
ordinal: 65000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Publishing letsdo to RubyGems should be a single, repeatable action: push a version tag (e.g. v0.1.0) and get a built, tested, published gem. Today the gem is built and tested by CI on every push (TASK-36), but pushing to RubyGems is a manual gem build + gem push step (v0.1.0 released manually on 2026-09-04). Add a release workflow that turns tag creation into the full release: verify the tag matches lib/letsdo/version.rb, build letsdo.gemspec, run rake test, and publish the artifact with an API key from repository secrets.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A .github/workflows/release.yml (or similar) triggers on pushes of tags matching v* (e.g. v0.1.0).
- [ ] #2 Workflow builds the gem (gem build letsdo.gemspec) and runs rake test; the job fails the release if either step fails.
- [ ] #3 The tag version matches lib/letsdo/version.rb — a mismatch (e.g. tag v0.2.0 while VERSION is 0.1.0) fails the job with a clear error before publishing.
- [ ] #4 Published artifact equals the tagged revision: the workflow pushes the gem built in the same run (gem push) to rubygems.org using an API key from a repository secret (e.g. GEM_HOST_API_KEY / RUBYGEMS_API_KEY), not a locally built file.
- [ ] #5 README or docs mention the release procedure (tag vX.Y.Z → automated publish).
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Assigned to @human (2026-09-13 review): the release needs a RubyGems API key stored as a repository secret plus the publish decision, which only a human can perform. A developer can draft the workflow YAML, but the human owns the secret and the actual release.
<!-- SECTION:NOTES:END -->
