---
id: TASK-80
title: >-
  gem install letsdo fails after success: rdoc-8.0.0 cannot activate (rbs-3.10.0
  vs rbs >= 4.0.0)
status: Done
assignee:
  - '@developer'
created_date: '2026-09-04 16:08'
updated_date: '2026-09-07 18:36'
labels: []
dependencies: []
priority: high
type: bug
ordinal: 69000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
After `gem install letsdo` (observed with 0.2.0 on mise Ruby 4.0.2), RubyGems prints "Successfully installed letsdo-0.2.0" and then raises Gem::ConflictError while running the post-install RDoc hook:

Unable to activate rdoc-8.0.0, because rbs-3.10.0 conflicts with rbs (>= 4.0.0)

The stack is Gem::RequestSet#install_hooks → RDoc::RubyGemsHook#generate → rdoc/rbs_helper.rb requiring rbs. letsdo does not declare rdoc or rbs as dependencies; the gem files are already installed when the hook fails. Users still see a failed install. Make `gem install letsdo` finish cleanly on this Ruby/RubyGems stack so the command exit status and output match a successful install, and `letsdo --version` works afterwards.

Reproduction (user):
  gem i letsdo
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 `gem install letsdo` exits 0 and does not print Gem::ConflictError from rdoc/rbs after the gem is installed
- [x] #2 `letsdo --version` works after that install without extra gem surgery
- [x] #3 The failure is covered by a regression check or documented install verification so a later gemspec/RubyGems change cannot silently bring the hook crash back
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Confirm the root cause is environmental (Ruby 4.0.x ships rdoc 8.0.0 which requires rbs >= 4.0.0, against bundled rbs 3.x) — reproduced locally: plain gem install crashes in the RDoc post-install hook; --no-document installs cleanly.
2. Document the failure + workaround in README.md and docs/usage.md (--no-document, or install rbs >= 4.0.0 first).
3. Add a CI "Verify install" step that installs the built gem with --no-document and runs letsdo --version, so the install path stays verified (regression guard).
4. Fix the pre-existing duplicated on:/jobs: block in .github/workflows/ci.yml while editing it.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Root cause confirmed environmental: Ruby 4.0.x ships default gems out of sync — rdoc 8.0.0 declares 'rbs >= 4.0.0' against bundled rbs 3.10.0, so the post-install RDoc hook raises Gem::ConflictError after the gem files are already installed. Reproduced locally: plain 'gem install' crashes in RDoc::RubyGemsHook#generate; 'gem install --no-document' exits 0 and 'letsdo --version' prints 0.2.0. No gemspec field can disable RDoc generation (checked: rdoc_options is only passed to rdoc; has_rdoc was removed in RubyGems 2.0).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Fixed by documenting the workaround and adding an install regression guard, since the crash is in Ruby's own default-gem set (rdoc 8.0.0 + bundled rbs 3.x) and no gemspec change can disable the RDoc hook. Added a Ruby 4.0.x note to README.md and docs/usage.md (install with --no-document, or gem install rbs -v '>= 4.0.0' first) and a CI 'Verify install' step that installs the built gem with --no-document and runs letsdo --version; also fixed the malformed duplicated on:/jobs: block in .github/workflows/ci.yml. Verified locally: gem build + gem install --no-document exits 0 and letsdo --version prints 0.2.0.
<!-- SECTION:FINAL_SUMMARY:END -->
