---
id: TASK-37
title: 'RuboCop: дефолтные стили, исправление кода, проверка в CI'
status: To Do
assignee:
  - '@developer'
created_date: '2026-09-03 20:27'
labels: []
dependencies:
  - TASK-36
ordinal: 26000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Подключить RuboCop в проект letsdo. Свои стили/правила не добавляем: используется дефолтная конфигурация RuboCop как есть (как он пришёл «из коробки»), никаких .rubocop.yml с отключениями или собственными копами. Нужно: (1) добавить rubocop как dev-зависимость; (2) прогнать rubocop с дефолтным конфигом по lib/, bin/, test/; (3) исправить нарушения — autocorrect (rubocop -A) плюс вручную оставшиеся, добиться 0 offenses. На момент создания задачи дефолтный прогон даёт 554 offenses (513 autocorrectable) в 21 файле — количество в задаче, не критерий, эталон — 0 offenses; (4) проверка стиля становится шагом CI-сборки из TASK-36 (workflow падает при нарушениях). Поведение и логика не меняются: только стиль кода.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 rubocop подключён как dev-зависимость, запускается из корня проекта
- [ ] #2 Конфигурация — только дефолтная, собственных стилей/исключений в .rubocop.yml нет
- [ ] #3 rubocop по lib/, bin/, test/ даёт 0 offenses
- [ ] #4 rake test остаётся зелёным (0 failures) после правок стиля
- [ ] #5 В CI workflow из TASK-36 добавлен шаг rubocop: сборка падает при нарушениях стиля
<!-- AC:END -->
