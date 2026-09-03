---
id: TASK-36
title: 'GitHub Actions: сборка джема и автотесты на каждый push'
status: Done
assignee:
  - '@developer'
created_date: '2026-09-03 20:26'
updated_date: '2026-09-03 20:33'
labels: []
dependencies: []
ordinal: 25000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Настроить GitHub Actions для репозитория sergio-fry/letsdo, чтобы на каждый push в любую ветку выполнялась сборка проекта: (1) проверка, что джем собирается — gem build letsdo.gemspec проходит успешно; (2) проверка, что автотесты запускаются и проходят — rake test даёт 0 failures. Тесты используют только встроенный Minitest (внешние гемы не нужны), так что workflow должен работать на чистом Ruby без bundler-установки зависимостей. Сейчас в репо нет .github/workflows — добавить первый workflow-файл.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 В репозитории есть .github/workflows/ci.yml с триггером на push (все ветки)
- [x] #2 Step «Сборка джема»: gem build letsdo.gemspec завершается успешно
- [x] #3 Step «Автотесты»: rake test завершается с 0 failures, 0 errors
- [x] #4 Workflow зелёный на main после добавления (проверено на GitHub Actions)
- [x] #5 Резолв Ruby-версии явный (>= 3.0, например 3.x) и совпадает с required_ruby_version джема
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Create .github/workflows/ci.yml: trigger on push (all branches), job on ubuntu-latest with explicit Ruby 3.3 (satisfies letsdo.gemspec required_ruby_version '>= 3.0').
2. Steps: checkout -> ruby/setup-ruby -> gem build letsdo.gemspec (build check) -> rake test (tests). No bundler/bundle install: rake and minitest are default gems of the Ruby distribution, tests use only built-in Minitest.
3. Verify locally by simulating CI steps exactly (gem build + rake test without bundler).
4. Commit workflow + commit, push to origin/main, watch Actions run on GitHub until green (repo is public, checkable via API).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Workflow .github/workflows/ci.yml: on push (branches: **), ubuntu-latest, ruby/setup-ruby@v1 with matrix ruby 3.3 (matches gemspec required_ruby_version '>= 3.0'). Steps: checkout -> setup Ruby -> gem build letsdo.gemspec -> rake test. No bundler/bundle install — rake and minitest are default Ruby gems. Local CI simulation (env -i, no bundler): gem build OK, rake test 61 runs / 0 failures / 0 errors. GitHub Actions run #33802817912 on main (commit 086066e): conclusion success, job ci (3.3) — steps Build gem and Run tests both success.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added .github/workflows/ci.yml: on push (all branches), ubuntu-latest, explicit Ruby 3.3 matrix (satisfies gem's >= 3.0), steps: checkout -> setup-ruby -> 'gem build letsdo.gemspec' -> 'rake test'. No bundler used (tests use only built-in Minitest; rake/minitest ship as default Ruby gems). Verified: (1) local simulation without bundler — gem build OK, rake test 61 runs / 0 failures / 0 errors; (2) real run on GitHub Actions main commit 086066e — run #33802817912 success, both Build gem and Run tests steps green.
<!-- SECTION:FINAL_SUMMARY:END -->
