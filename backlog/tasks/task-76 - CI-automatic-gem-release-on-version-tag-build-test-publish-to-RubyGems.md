---
id: TASK-76
title: 'CI: automatic gem release on version tag (build, test, publish to RubyGems)'
status: Done
assignee:
  - developer
created_date: '2026-09-04 09:19'
updated_date: '2026-09-18 11:07'
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
- [x] #1 A .github/workflows/release.yml (or similar) triggers on pushes of tags matching v* (e.g. v0.1.0).
- [x] #2 Workflow builds the gem (gem build letsdo.gemspec) and runs rake test; the job fails the release if either step fails.
- [x] #3 The tag version matches lib/letsdo/version.rb — a mismatch (e.g. tag v0.2.0 while VERSION is 0.1.0) fails the job with a clear error before publishing.
- [x] #4 Published artifact equals the tagged revision: the workflow pushes the gem built in the same run (gem push) to rubygems.org using an API key from a repository secret (e.g. GEM_HOST_API_KEY / RUBYGEMS_API_KEY), not a locally built file.
- [x] #5 README or docs mention the release procedure (tag vX.Y.Z → automated publish).
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Create .github/workflows/release.yml: trigger on push of tags v*, single release job on Ruby 3.4 (stable line from the CI matrix).
2. Job steps: checkout -> verify tag version (strip leading v from GITHUB_REF_NAME, compare with Letsdo::VERSION loaded from lib/letsdo/version.rb, fail with a clear ::error on mismatch) -> gem build letsdo.gemspec -> rake test -> gem push of the exact letsdo-<version>.gem built in this run, with GEM_HOST_API_KEY taken from the repository secret RUBYGEMS_API_KEY.
3. Document the release procedure in README (Development section): CHANGELOG + VERSION bump, commit, tag vX.Y.Z, push tag -> automated build/test/publish; note the maintainer-owned repository secret.
4. Validate the workflow YAML locally (ruby yaml parse) and dry-run the version-check snippet against the current tag v0.6.1; run rake test to confirm a green baseline.
5. Per the task's implementation note: the workflow is drafted by developer; the RUBYGEMS_API_KEY secret and the actual next release remain human-owned.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Assigned to @human (2026-09-13 review): the release needs a RubyGems API key stored as a repository secret plus the publish decision, which only a human can perform. A developer can draft the workflow YAML, but the human owns the secret and the actual release.

Validation evidence:
- YAML parses (ruby -ryaml); triggers = push.tags [v*]; steps: Checkout, Set up Ruby, Verify tag, Build gem, Run tests, Publish.
- Version-check logic exercised locally in bash: tag v0.6.1 vs VERSION 0.6.1 -> match, proceeds; tag v0.2.0 vs 0.6.1 -> fails with '::error::Tag v0.2.0 does not match lib/letsdo/version.rb (0.6.1).' and exit 1.
- Publish step pushes the exact letsdo-${GITHUB_REF_NAME#v}.gem built in the same run (fixed a cross-step variable bug found in self-review: tag_version is not visible in a later step; GITHUB_REF_NAME is used directly).
- rake test: 421 runs, 1223 assertions, 0 failures, 0 errors; rubocop 1.77: 84 files, no offenses; gem build succeeds.
- Scope note per the 2026-09-13 review note: developer drafted the workflow; the RUBYGEMS_API_KEY repository secret and the actual next release remain human-owned (README states the owner configures the secret).
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: developer
created: 2026-09-18 10:04
---TASK-96 data migration: stored assignee '@human' reassigned to the canonical bare name 'human' (the '@' prefix is prose-only notation; exact-string filters miss '@'-prefixed values).
---

author: human
created: 2026-09-18 12:04
---
added RUBYGEMS_API_KEY to github secrets 
---

<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added .github/workflows/release.yml: a push of a v* tag now runs the full release on a clean Ruby 3.4 — verify tag == lib/letsdo/version.rb (clear ::error on mismatch, before any build/publish), gem build letsdo.gemspec, rake test, then gem push of the letsdo-<version>.gem built in the same run using GEM_HOST_API_KEY fed from the RUBYGEMS_API_KEY repository secret. Documented the release procedure in README (Development -> Releasing): bump VERSION + CHANGELOG, tag vX.Y.Z, push the tag; the owner configures the secret once. Verified by local execution of the version-check logic (match and mismatch paths), YAML parse, rake test (421 runs, 0 failures), rubocop (no offenses) and gem build. Residual human-owned items: add the RUBYGEMS_API_KEY secret in GitHub repo settings; the first automated release happens on the next tag push.
<!-- SECTION:FINAL_SUMMARY:END -->
