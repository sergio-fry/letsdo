---
id: TASK-20
title: 'Джем letsdo: каркас Ruby-библиотеки в отдельной папке'
status: Done
assignee:
  - '@developer'
created_date: '2026-09-03 16:20'
updated_date: '2026-09-03 16:38'
labels: []
dependencies: []
priority: high
type: feature
ordinal: 2000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Создать в корне проекта отдельную папку letsdo/ — каркас Ruby-джема letsdo (локальный агент-работник задач Backlog.md/markdown; в будущем — отдельный репозиторий). Минимальный скелет, но рабочий: letsdo.gemspec (name=letsdo, executables=bin/letsdo), Gemfile, Rakefile, lib/letsdo.rb (module Letsdo), lib/letsdo/version.rb, исполняемый bin/letsdo (chmod +x, базовый CLI: --version и usage), README.md, LICENSE (MIT), .gitignore. Код — ООП-заготовки (структура проектируется в отдельной задаче про структуру и тесты).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Папка letsdo/ с letsdo.gemspec: name=letsdo, executables=["bin/letsdo"]
- [x] #2 ./bin/letsdo --version выводит версию из lib/letsdo/version.rb
- [x] #3 ruby -Ilib -e "require 'letsdo'" и ruby -c на lib/*.rb проходят без ошибок
- [x] #4 bin/letsdo исполняемый (+x)
- [x] #5 README.md с описанием и использованием; LICENSE MIT
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Изучить конвенции текущего кода (bin/agent, lib/agent, версия 0.1.0) и выбрать версию letsdo 0.1.0.
2. Создать letsdo/letsdo.gemspec: name=letsdo, version из lib/letsdo/version.rb, executables=["bin/letsdo"], summary/description/автор/LICENSE (MIT).
3. Создать letsdo/Gemfile (gemspec), letsdo/Rakefile (rake test, rake build), letsdo/.gitignore, letsdo/README.md, letsdo/LICENSE (MIT).
4. Создать lib/letsdo.rb (module Letsdo) и lib/letsdo/version.rb; подключить require_relative-структуру по образцу lib/agent.rb.
5. Создать bin/letsdo (#!/usr/bin/env ruby, chmod +x), базовый CLI: --version из version.rb, usage с exit 1 при неизвестном аргументе.
6. Проверить AC: gem build, bin/letsdo --version, ruby -Ilib -e "require 'letsdo'", ruby -c на lib/*.rb, проверка +x.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Выбрана задача TASK-20 (High, ordinal 2000); TASK-21 зависит от неё и возьмётся следующим запуском.

Проверка AC (объективные доказательства):
#1: ruby -e 'Gem::Specification.load("letsdo.gemspec")' -> name=letsdo, version=0.1.0; gem build собирает letsdo-0.1.0.gem (файлы: LICENSE, README.md, bin/letsdo, lib/letsdo.rb, lib/letsdo/version.rb).
#2: ./bin/letsdo --version -> 0.1.0 (exit 0); версия из lib/letsdo/version.rb.
#3: ruby -Ilib -e "require 'letsdo'" -> OK (выводит 0.1.0); ruby -c на lib/letsdo.rb и lib/letsdo/version.rb -> Syntax OK.
#4: bin/letsdo +x (rwxr-xr-x), запускается напрямую.
#5: README.md с описанием и использованием; LICENSE = MIT License.
Доп. e2e: gem install в чистый GEM_HOME -> команда letsdo --version работает, 'gem letsdo; require letsdo' → 0.1.0. CLI: --help exit 0, без аргументов/неизвестная опция -> usage exit 1. rake -T/test работают.
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: @developer
created: 2026-09-03 16:38
---
Отклонение от буквы AC #1: literal executables=["bin/letsdo"] ломает gem build — RubyGems резолвит executables относительно bindir и ищет bin/bin/letsdo (Gem::InvalidSpecificationException: ["bin/bin/letsdo"] are not files). Использована каноническая форма spec.bindir="bin" + spec.executables=["letsdo"]: исполняемый файл джема — bin/letsdo, в PATH попадает как команда letsdo. Проверено реальной установкой гема.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Создан каркас джема в letsdo/: letsdo.gemspec (name=letsdo, version из lib/letsdo/version.rb, executables через bindir=bin: команда letsdo из bin/letsdo), Gemfile (gemspec), Rakefile (rake test/default), lib/letsdo.rb (module Letsdo) + lib/letsdo/version.rb (VERSION=0.1.0), исполняемый bin/letsdo (+x; CLI: --version, --help, usage с exit 1), README.md, LICENSE (MIT), .gitignore. Проверено: gem build → letsdo-0.1.0.gem; bin/letsdo --version → 0.1.0; ruby -Ilib require и ruby -c — без ошибок; установка гема в чистый GEM_HOME даёт рабочую команду letsdo. Все 5 AC отмечены выполненными.
<!-- SECTION:FINAL_SUMMARY:END -->
