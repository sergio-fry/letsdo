---
id: TASK-34
title: Перенести letsdo и бэклог в новый репозиторий /root/projects/letsdo
status: Done
assignee:
  - '@developer'
created_date: '2026-09-03 16:56'
updated_date: '2026-09-03 17:07'
labels: []
dependencies: []
priority: high
type: chore
ordinal: 1000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Перенести Ruby-библиотеку letsdo и весь рабочий контекст из /mnt/storage/projects/sandbox/news-tracker в новый репозиторий /root/projects/letsdo (git уже инициализирован, файлов нет). Перенести: letsdo/ (gemspec, lib/, bin/letsdo, test/, Rakefile, Gemfile, README.md, LICENSE), бэклог задач (backlog/ целиком — задачи, config.yml, AGENTS.md как протокол работы); config.yml привести к новому имени проекта (letsdo). Git-историю НЕ переносить — обычное копирование файлов, новое репо стартует с чистого коммита. После переноса работа над letsdo продолжается в новом репозитории: backlog CLI должен работать оттуда (backlog task list видит текущие задачи, включая открытые TASK-9/TASK-22).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 В корне /root/projects/letsdo лежит полная библиотека: letsdo.gemspec, lib/letsdo/*.rb, bin/letsdo, test/, Rakefile, Gemfile, README.md, LICENSE
- [x] #2 Из нового каталога работает: ruby -Ilib -e "require 'letsdo'", bin/letsdo --version, rake test (0 failures)
- [x] #3 Backlog перенесён: cd /root/projects/letsdo && backlog task list показывает текущие задачи (открытые TASK-9/TASK-22 и все закрытые)
- [x] #4 AGENTS.md перенесён и адаптирован: протокол backlog-работы действует из нового репо
- [x] #5 Git-история не переносится; исходники в news-tracker не теряются (копирование)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Скопировать содержимое letsdo/ (gemspec, lib/, bin/letsdo, test/, Rakefile, Gemfile, Gemfile.lock, README.md, LICENSE, .gitignore) в корень /root/projects/letsdo (новый чистый git, история не переносится).
2. Скопировать backlog/ целиком (tasks, completed, archive, config.yml, decisions, docs, drafts, milestones) в /root/projects/letsdo/backlog + AGENTS.md в корень нового репо.
3. Адаптировать backlog/config.yml: project_name 'News Tracker' -> 'letsdo'.
4. Проверить AC#2: ruby -Ilib -e "require 'letsdo'", bin/letsdo --version, rake test (0 failures) из нового каталога.
5. Проверить AC#3-#4: cd /root/projects/letsdo && backlog task list (открытые TASK-22 + все закрытые), backlog instructions overview работает.
6. Первый коммит в новом репо (чистый, без истории). Исходники в news-tracker не трогаю (копирование).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Верификация из /root/projects/letsdo:
- AC#1: find показал в корне letsdo.gemspec, lib/letsdo/*.rb, bin/letsdo, test/ (7 тест-файлов + fixture), Rakefile, Gemfile, Gemfile.lock, README.md, LICENSE, .gitignore.
- AC#2: ruby -Ilib -e "require 'letsdo'" — OK (Letsdo::VERSION печатается); bin/letsdo --version — 0.1.0; rake test — 56 runs, 136 assertions, 0 failures, 0 errors.
- AC#3: cd /root/projects/letsdo && backlog task list — открытые TASK-22, TASK-34 (In Progress) и все закрытые (TASK-1..10, 18-21, 23-33).
- AC#4: AGENTS.md лежит в корне нового репо, backlog instructions overview работает оттуда (== Backlog.md Overview (CLI) ==).
- AC#5: новое репо было без коммитов (git status: No commits yet); исходники в news-tracker на месте (letsdo.gemspec, AGENTS.md, backlog/) — только cp, ничего не удалялось.
- config.yml в новом репо: project_name приведён к 'letsdo'.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Перенесён весь рабочий контекст letsdo в /root/projects/letsdo: библиотека (gemspec, lib/, bin/letsdo, test/, Rakefile, Gemfile, README, LICENSE), backlog/ целиком с config.yml (project_name='letsdo'), AGENTS.md. Верифицировано командой из нового каталога: require 'letsdo' и bin/letsdo --version (0.1.0) работают, rake test — 56 runs/0 failures, backlog task list видит все текущие задачи, протокол backlog действует. Git-история не переносилась (начальный коммит в новом репо); исходники в news-tracker не тронуты (копирование).
<!-- SECTION:FINAL_SUMMARY:END -->
