---
id: TASK-47
title: >-
  Gemspec: best-practice description, Ruby version floor, runtime vs dev
  dependencies
status: Done
assignee:
  - '@developer'
created_date: '2026-09-04 07:06'
updated_date: '2026-09-08 08:05'
labels: []
dependencies:
  - TASK-46
  - TASK-37
priority: medium
type: enhancement
ordinal: 36000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Bring letsdo.gemspec up to RubyGems packaging best practices (per user request): a real user-facing description, correct Ruby version constraints, and properly separated runtime vs development dependencies.

Current problems:
- spec.description dumps internal class names (PromptStore/OutputStreamer/PiRunner) instead of telling what the gem does and why (should mirror the TASK-46 README pitch).
- spec.summary exists; homepage is missing (gem build warns), no metadata URIs (source_code_uri, bug_tracker_uri, changelog_uri, documentation_uri, allowed_push_host).
- required_ruby_version is '>= 3.0', but CI only tests Ruby 3.3 (ruby/setup-ruby matrix, single entry); Ruby 3.0 is EOL. Supported floor must match what is actually tested: either widen the CI matrix or narrow required_ruby_version — decide and document.
- No dependencies declared at all. Important nuance: the gem shells out to the external 'pi' CLI binary (LETSDO_PI_COMMAND, default 'pi') — that is a runtime REQUIREMENT, not a rubygem: do not add_dependency 'pi'; document the external requirement. Dev deps: rake/minitest are bundled default gems (CI runs on clean Ruby without bundle install — README states this); TASK-37 adds RuboCop as a dev dependency, coordinate so this task does not fight that change.
- spec.files should package everything that belongs in the gem (gemspec, README, LICENSE; CHANGELOG/CONTRIBUTING/CODE_OF_CONDUCT once they appear) and nothing else.

Sources: letsdo.gemspec, Gemfile, bin/letsdo, .github/workflows/ci.yml, lib/letsdo/version.rb. English only, per project convention. gem build must stay clean and CI green (rake test).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 spec.summary and spec.description rewritten per RubyGems best practices: short summary, user-facing description (what the gem does, why to use it) consistent with the TASK-46 README — no internal class inventory
- [x] #2 spec.homepage added and metadata URIs set: source_code_uri (github.com/sergio-fry/letsdo), bug_tracker_uri, changelog_uri, documentation_uri; allowed_push_host for rubygems.org when publishing; rubygems_mfa_required kept
- [x] #3 required_ruby_version matches reality: either CI matrix widened to every claimed supported version or the floor narrowed to tested versions (Ruby 3.0 is EOL — justification documented in the task notes/commit)
- [x] #4 Dependencies correct: no fake runtime dep on 'pi' (external CLI binary — requirement stated in README and/or metadata instead); dev dependencies (rake, minitest, rubocop per TASK-37) declared only if they don't break the no-bundle-install CI approach — otherwise CI adjusted accordingly
- [x] #5 spec.files packages exactly the right artifacts (gemspec, README, LICENSE; CHANGELOG/CONTRIBUTING/CODE_OF_CONDUCT when added); gem build letsdo.gemspec succeeds with no warnings; CI (gem build + rake test) green
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Rewrite spec.summary/spec.description to be user-facing (what letsdo does, why use it), consistent with the README pitch; drop the internal class inventory and the 'will later split into a repo' line.
2. Fix gemspec metadata URIs: add bug_tracker_uri and documentation_uri; drop the redundant homepage_uri metadata key (spec.homepage already carries the homepage, and an identical homepage_uri+source_code_uri triggers a gem build warning).
3. Narrow required_ruby_version from '>= 3.0' to '>= 3.3' to match what CI actually tests (3.3 + 4.0); Ruby 3.0/3.1/3.2 are EOL. Update the README and ci.yml comment references accordingly.
4. Keep dependencies as-is (real tty-* runtime deps, rubocop dev dep, no fake 'pi' dep); the external pi CLI requirement is already documented in README.
5. Extend spec.files with CHANGELOG.md and the gemspec itself.
6. Verify: gem build with no warnings, rake test green, rubocop clean.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Baseline before change: rake test 214 runs / 707 assertions, 0 failures; gem build emits one warning (identical homepage_uri/source_code_uri).

Verification (Ruby 4.0.2): gem build letsdo.gemspec exits 0 with zero warnings (the identical homepage_uri/source_code_uri warning is gone); the built gem ships lib/**/*.rb, README.md, LICENSE, CHANGELOG.md, letsdo.gemspec and bin/letsdo, with required_ruby_version >= 3.3 and metadata source_code_uri/bug_tracker_uri/changelog_uri/documentation_uri/rubygems_mfa_required/allowed_push_host all present; rake test 214 runs / 707 assertions, 0 failures; rubocop --no-server lib bin test — 51 files, 0 offenses.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Brought letsdo.gemspec to RubyGems packaging best practices. spec.description is now user-facing (what letsdo does and why) instead of an internal class inventory; added bug_tracker_uri and documentation_uri and dropped the redundant homepage_uri metadata key that made gem build warn; narrowed required_ruby_version from >= 3.0 to >= 3.3 to match the CI-tested 3.3/4.0 (Ruby 3.0-3.2 are EOL) and updated the README + ci.yml references; extended spec.files with CHANGELOG.md and the gemspec; kept the real tty-* runtime deps, the rubocop dev dep, and no fake 'pi' dep (the external pi CLI is a documented runtime requirement, not a rubygem). Verified: gem build with zero warnings, correct gem contents and metadata, rake test 214/707 0 failures, rubocop 51 files 0 offenses.
<!-- SECTION:FINAL_SUMMARY:END -->
