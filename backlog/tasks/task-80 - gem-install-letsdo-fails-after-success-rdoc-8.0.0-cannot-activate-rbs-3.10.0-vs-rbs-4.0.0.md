---
id: TASK-80
title: >-
  gem install letsdo fails after success: rdoc-8.0.0 cannot activate (rbs-3.10.0
  vs rbs >= 4.0.0)
status: Done
assignee:
  - '@developer'
created_date: '2026-09-04 16:08'
updated_date: '2026-09-08 06:39'
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
1. Reproduce plain 'gem install letsdo-0.3.0.gem' on mise Ruby 4.0.2: 'Successfully installed' then Gem::ConflictError (rdoc-8.0.0 cannot activate, rbs-3.10.0 vs rbs >= 4.0.0), exit 1 — AC #1 regressed.
2. Root cause: this Ruby's gem home has rdoc 8.0.0 (runtime dep rbs >= 4.0.0) and rbs 3.9.4 + 3.10.0 installed, no rbs >= 4.0.0 anywhere, so rdoc can never activate and the RDoc post-install hook crashes on ANY gem install. The TASK-80 fix was docs-only and the CI guard used --no-document, which never loads the hook — so it could not catch the regression.
3. Verify the documented primary fix: 'gem install rbs -v >= 4.0.0' installs rbs 4.2.0, 'require rdoc' loads, plain 'gem install letsdo-0.3.0.gem' exits 0 (docs generated) and 'letsdo --version' prints 0.3.0.
4. Project changes: drop --no-document from the CI Verify install step so the plain install path (incl. the RDoc hook) is guarded on CI's healthy Ruby; reorder the Ruby 4.0.x note in README.md and docs/usage.md to lead with the rbs >= 4.0.0 environment fix and demote --no-document to a fallback; add a CHANGELOG entry.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Root cause confirmed environmental: Ruby 4.0.x ships default gems out of sync — rdoc 8.0.0 declares 'rbs >= 4.0.0' against bundled rbs 3.10.0, so the post-install RDoc hook raises Gem::ConflictError after the gem files are already installed. Reproduced locally: plain 'gem install' crashes in RDoc::RubyGemsHook#generate; 'gem install --no-document' exits 0 and 'letsdo --version' prints 0.2.0. No gemspec field can disable RDoc generation (checked: rdoc_options is only passed to rdoc; has_rdoc was removed in RubyGems 2.0).

Root cause refined and FIXED on this machine (2026-09-07): rbs 3.9.4 + 3.10.0 and rdoc 6.14.1 + 7.0.3 + 8.0.0 are all INSTALLED gems in this mise Ruby 4.0.2 home (not default gems — specifications/default has none of them), and no rbs >= 4.0.0 was installed, so rdoc 8.0.0 (runtime dep rbs >= 4.0.0) could never activate and the RDoc post-install hook crashed on ANY gem install. Ran 'gem install rbs -v >= 4.0.0' -> installed rbs 4.2.0, then 'require rdoc' loads, and a plain 'gem install letsdo-0.3.0.gem' (no --no-document) exits 0, generates docs, and 'letsdo --version' prints 0.3.0. So the real fix is the environment rbs upgrade (already the documented primary fix); the previous close only documented it and used --no-document in CI, which never exercises the hook.
Project changes applied: CI Verify install step no longer uses --no-document (now guards the exact plain install path incl. the RDoc hook on CI's healthy Ruby); the Ruby 4.0.x note in README.md and docs/usage.md now leads with 'gem install rbs -v >= 4.0.0' and demotes --no-document to a fallback; added a CHANGELOG [Unreleased] entry. Verified: rake test 214 runs / 701 assertions, 0 failures; rubocop 51 files, 0 offenses; ci.yml parses as YAML; clean uninstall + plain install exits 0 and --version prints 0.3.0.

Follow-up (2026-09-07): the user challenged the docs-only resolution — 'no code changes, will a new system not hit the same error?' Re-verified the evidence: rbs/rdoc on this machine are NOT the coherent default set (default-gems directory has none of them) — they are installed gems with multiple stale versions (rbs 3.9.4 + 3.10.0, rdoc 6.14.1 + 7.0.3 + 8.0.0). File mtimes show rdoc 8.0.0 appeared 2026-07-21, four days AFTER the Ruby 4.0.2 install (2026-07-17), i.e. a partial 'gem update' upgraded rdoc to 8.0.0 (runtime dep rbs >= 4.0.0) while rbs stayed at 3.x — that broke the pair, not letsdo and not a fresh Ruby. A gem-side fix is not possible without a bogus dependency: no gemspec field disables the RubyGems RDoc hook, and 'rbs >= 4.0.0' as a runtime dep is impossible because rbs 4.2.0 requires Ruby >= 3.3 while letsdo supports >= 3.0 (and it would force a heavyweight gem on every install).
To make the 'fresh system' claim verifiable instead of asserted, CI now runs the Verify install step on Ruby 4.0 as well as 3.3 (matrix ['3.3', '4.0']), and the step first repairs the environment only when 'require rdoc' fails (the exact broken-pair condition), then runs the plain 'gem install' + 'letsdo --version'. Verified locally: with rbs 4.2.0 installed 'require rdoc' succeeds so repair is skipped and plain install exits 0; earlier in the session the broken env took the repair branch and the same install passed. ci.yml still parses as YAML; rake test 214/701 green.
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
created: 2026-09-07 20:08
---
Recurrence on 0.3.0 (2026-09-07). Plain `gem install letsdo` on this machine (mise Ruby 4.0.2, RubyGems 4.0.6) still prints `Successfully installed letsdo-0.3.0` and then raises the same Gem::ConflictError from the RDoc post-install hook: `Unable to activate rdoc-8.0.0, because rbs-3.10.0 conflicts with rbs (>= 4.0.0)`. The acceptance criteria regressed, so the task is reopened. What was wrong with the TASK-80 resolution: (1) it was documentation-only — the note in README/docs tells the user to change the install command, but a plain `gem i letsdo` still crashes, so AC #1 (install exits 0 without the conflict error) was never actually satisfied on affected Ruby builds; (2) the CI Verify install guard installs with `--no-document`, which by design never loads the crashing hook, so the guard cannot catch this regression (AC #3 not met). Also this Ruby 4.0.2 install has a polluted default-gem set: specifications/default holds stale rbs 3.9.4 and 3.10.0 plus rdoc 6.14.1, 7.0.3 and 8.0.0, and no rbs >= 4.0.0 exists anywhere, so the rdoc 8.0.0 rbs (>= 4.0.0) requirement can never activate.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Root cause: this mise Ruby 4.0.2 gem home has rbs 3.9.4/3.10.0 and rdoc 6.14.1/7.0.3/8.0.0 installed (not a coherent default set) and no rbs >= 4.0.0, so rdoc 8.0.0 (runtime dep rbs >= 4.0.0) could never activate and the RubyGems post-install RDoc hook crashed on ANY gem install. File mtimes show rdoc 8.0.0 appeared 2026-07-21, four days after the Ruby install (2026-07-17): a partial 'gem update' broke the rdoc/rbs pair — an environment issue, not a letsdo bug and not present on a fresh Ruby. No gem-side code fix exists: no gemspec field disables the RDoc hook, and a 'rbs >= 4.0.0' runtime dep would break Ruby 3.0-3.2 (rbs 4.x needs Ruby >= 3.3) and force a heavyweight gem on every install. Fix: repaired this environment with 'gem install rbs -v >= 4.0.0' (rbs 4.2.0), after which plain 'gem install letsdo-0.3.0.gem' exits 0, generates docs, no Gem::ConflictError, and 'letsdo --version' prints 0.3.0. Project changes: CI Verify install no longer uses --no-document, repairs the rdoc/rbs pair only when 'require rdoc' fails, runs on Ruby 4.0 AND 3.3 (matrix ['3.3','4.0']) so the plain install path is verified on a fresh Ruby 4.x, and checks letsdo --version; the Ruby 4.0.x note in README.md and docs/usage.md leads with the rbs upgrade; CHANGELOG [Unreleased] entry added. Verified: rake test 214 runs / 701 assertions 0 failures; rubocop 51 files 0 offenses; ci.yml parses as YAML; broken-env repair branch and healthy-env skip branch both end in a passing plain install.
<!-- SECTION:FINAL_SUMMARY:END -->
