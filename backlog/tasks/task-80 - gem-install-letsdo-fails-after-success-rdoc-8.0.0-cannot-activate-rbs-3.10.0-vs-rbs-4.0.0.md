---
id: TASK-80
title: >-
  gem install letsdo fails after success: rdoc-8.0.0 cannot activate (rbs-3.10.0
  vs rbs >= 4.0.0)
status: To Do
assignee:
  - developer
created_date: '2026-09-04 16:08'
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
- [ ] #1 `gem install letsdo` exits 0 and does not print Gem::ConflictError from rdoc/rbs after the gem is installed
- [ ] #2 `letsdo --version` works after that install without extra gem surgery
- [ ] #3 The failure is covered by a regression check or documented install verification so a later gemspec/RubyGems change cannot silently bring the hook crash back
<!-- AC:END -->
