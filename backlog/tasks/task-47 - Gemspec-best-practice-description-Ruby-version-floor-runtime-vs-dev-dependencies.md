---
id: TASK-47
title: >-
  Gemspec: best-practice description, Ruby version floor, runtime vs dev
  dependencies
status: To Do
assignee:
  - '@developer'
created_date: '2026-09-04 07:06'
updated_date: '2026-09-04 10:27'
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
- [ ] #1 spec.summary and spec.description rewritten per RubyGems best practices: short summary, user-facing description (what the gem does, why to use it) consistent with the TASK-46 README — no internal class inventory
- [ ] #2 spec.homepage added and metadata URIs set: source_code_uri (github.com/sergio-fry/letsdo), bug_tracker_uri, changelog_uri, documentation_uri; allowed_push_host for rubygems.org when publishing; rubygems_mfa_required kept
- [ ] #3 required_ruby_version matches reality: either CI matrix widened to every claimed supported version or the floor narrowed to tested versions (Ruby 3.0 is EOL — justification documented in the task notes/commit)
- [ ] #4 Dependencies correct: no fake runtime dep on 'pi' (external CLI binary — requirement stated in README and/or metadata instead); dev dependencies (rake, minitest, rubocop per TASK-37) declared only if they don't break the no-bundle-install CI approach — otherwise CI adjusted accordingly
- [ ] #5 spec.files packages exactly the right artifacts (gemspec, README, LICENSE; CHANGELOG/CONTRIBUTING/CODE_OF_CONDUCT when added); gem build letsdo.gemspec succeeds with no warnings; CI (gem build + rake test) green
<!-- AC:END -->
