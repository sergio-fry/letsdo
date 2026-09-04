---
id: TASK-46
title: >-
  README: open-source-grade project description (value prop, features, install,
  alternatives, badges, contributing)
status: To Do
assignee:
  - '@analyst'
created_date: '2026-09-04 06:42'
labels: []
dependencies:
  - TASK-43
  - TASK-44
type: docs
ordinal: 35000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Rewrite README.md to open-source best practices so letsdo is attractive for adoption and contribution (per user request). Current README is a dry technical rundown (usage + internal class structure); it needs a proper pitch: what the project is in one line, why use it (value proposition), what it can do (features), how to install and run, how it compares to similar tools on the market, badges, and how to contribute.

Sources of truth: README.md (current), letsdo.gemspec, agents/ (developer, analyst prompts), LICENSE (MIT), .github/workflows/ci.yml (CI badge), test/ (rake test, Minitest, fixtures/fake_pi). Keep everything in English per project convention. The Usage/Install sections must reflect the final CLI surface, including the built-in default prompt and --init (TASK-43, TASK-44) — hence dependencies on those tasks.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 README rewritten following open-source README best practices: concise tagline, badge row, table of contents, sections below
- [ ] #2 Value proposition section answers 'why letsdo' and when to use it (local agent worker over Backlog.md/markdown tasks, orchestrator loop, multi-agent)
- [ ] #3 Features/capabilities section covers what the tool does today: one-command agent run (bin/letsdo <name>), --version/--help, agents as prompt files, orchestrator loop, built-in default prompt and --init fallback, streaming output with HH:MM:SS-prefixed tool lines
- [ ] #4 Install/getting started section: requirements (Ruby >= 3.0), gem build/install, first run, LETSDO_ROOT / LETSDO_PI_FLAGS / LETSDO_PI_COMMAND knobs
- [ ] #5 Alternatives section: comparison with at least 2-3 related tools on the market (honest what-is-similar / what-is-different, with links); conclusions why letsdo is still worth using
- [ ] #6 Badges are real and justified: GitHub Actions CI status; others (e.g. gem version, license) only if they resolve correctly and add value — no fake badges
- [ ] #7 Contributing section: how to run tests (rake test, single-file test runs), build the gem (gem build letsdo.gemspec), where key code lives; English only, MIT LICENSE link preserved
<!-- AC:END -->
