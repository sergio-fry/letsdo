---
id: TASK-39
title: >-
  letsdo <имя> выполняет одну задачу вместо цикла оркестратора (все задачи +
  ожидание новых)
status: Done
assignee:
  - '@developer'
created_date: '2026-09-03 20:33'
updated_date: '2026-09-04 04:43'
labels: []
dependencies: []
priority: high
type: bug
ordinal: 28000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Сейчас letsdo <имя> делает ровно один прогон агента (одна задача) и завершается с кодом выхода pi. По замыслу (TASK-6/7/8, прежний bin/agent-loop) команда должна запускать оркестратор-цикл: последовательно выполнить все открытые задачи, назначенные на агента (одна задача за прогон), а когда задач нет — перейти в режим ожидания новых (периодическая проверка каждые ~10 с; желательно мгновенное пробуждение по изменениям файлов backlog/, как inotify-режим bin/agent-loop) и выполнять появившиеся, пока процесс не остановят (SIGINT/SIGTERM → чистый выход, exit 0). Причина: CLI (run_agent в lib/letsdo/cli.rb) вызывает Letsdo::Agent напрямую; Letsdo::Loop существует, но не подключён в CLI, не имеет реального провайдера задач из backlog CLI и обработки сигналов. В bin/ только letsdo; эталон поведения — bin/agent-loop из /mnt/storage/projects/sandbox/news-tracker.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 letsdo <имя> выполняет подряд все открытые задачи агента (один прогон агента = одна задача), а не останавливается после первой
- [x] #2 Когда открытых задач нет — процесс не завершается: ждёт появления новых (периодическая проверка с интервалом по умолчанию ~10 с, в ожидании выводится сообщение) и выполняет появившиеся
- [x] #3 Остановка — только снаружи: SIGINT/SIGTERM останавливают цикл чисто (exit 0); реакция на сигнал быстрая даже в режиме ожидания
- [x] #4 Провайдер задач — реальный backlog CLI: backlog task list --assignee @<имя> --exclude-status Done; правило хендла '@' + имя агента (переопределение, как AGENT_ASSIGNEE_HANDLE); недоступный/пустой бэклог — пауза без запуска агента
- [x] #5 Поведение покрыто тестами (N задач → N прогонов, ожидание без задач, stop); rake test зелёный (0 failures)
- [x] #6 Контракт агента не меняется: один прогон агента = ровно одна задача (промпты agents/*.md не меняются)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. New Letsdo::BacklogTasks: task provider via real backlog CLI (backlog task list --assignee <handle> --exclude-status Done --json, cwd=project root); returns tasks array, nil when the backlog is unavailable (CLI missing/failed/non-JSON).
2. New Letsdo::AgentLoop: wires Letsdo::Loop + provider + agent run (one run = one task) + SIGINT/SIGTERM traps + interruptible wait (self-pipe wake: Ruby sleep does NOT return early on trapped signals). Messages on stderr: started, running <name> for <task>, no open tasks / backlog unavailable + interval, exited with code, stopped. Exit code 0 on stop (and on empty/inavailable backlog loop stays alive by design).
3. Letsdo::PiRunner: spawn pi in its own process group (pgroup: true) + new terminate (TERM to the group, bounded grace, then KILL) so a running pi is stopped promptly when the loop stops.
4. Letsdo::Agent: expose the current runner (attr_reader) so the signal handler can terminate it.
5. Letsdo::CLI.run_agent: validate the prompt first (unknown agent still exits 1), then enter the AgentLoop. Env: AGENT_ASSIGNEE_HANDLE (handle override, reference-compatible), LETSDO_WAIT_SECONDS (fallback AGENT_WAIT_SECONDS, default 10), LETSDO_BACKLOG_COMMAND (default 'backlog'). CLI.run accepts injected sleeper: for tests.
6. bin/letsdo header + README updated (loop mode, env vars).
7. Tests: fake_backlog fixture (open/empty/fail/malformed scenarios, ARGV recorder); backlog_tasks_test; agent_loop_test (N tasks → N runs, wait mode message, unavailable backlog, run-code logging, exit 0, SIGINT/SIGTERM subprocess tests incl. fast stop in wait mode); cli_test loop-path tests reworked (sleeper injection, fake backlog). Contract: agents/*.md untouched.
<!-- SECTION:PLAN:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
letsdo <имя> теперь запускает оркестратор-цикл: Letsdo::AgentLoop (цикл) + Letsdo::BacklogTasks (провайдер реального backlog CLI: task list --assignee @<имя> --exclude-status Done --json) + Letsdo::PiRunner (pi в собственной группе). Все открытые задачи агента выполняются подряд (одна задача за прогон), затем режим ожидания (опрос каждые ~10 с, сообщение в stderr), остановка — только SIGINT/SIGTERM с чистым exit 0. Ключевые исправления за время работы: (1) гонка @pid в terminate (типичный TypeError at kill(0,nil)); (2) DBG-вывод в обработчике сигнала вызывал deadlock; recursive locking — трап больше не пишет в IO, только SIGTERM в группу pi + raise Letsdo::Stopped, который прерывает main-поток из любого места (чтение pi, ожидание задач, провайдер); (3) чтение потока pi — только main-потоком (ридер-потоки и Thread#join несовместимы с трапами в CRuby 4.0 — выяснено эмпирически); (4) BacklogTasks передаёт env ребёнку явно (ENV.to_h.merge) — тестовые сценарии fake_backlog доходили до фикстур; (5) в тестах убран Tempfile-финализер из done-файла (флаки). Добавлен отладочный режим LETSDO_DEBUG=1: трассы [letsdo] loop/pi (спавн, reader EOF, exit-status, итерации). Проверено: rake test 83 runs, 244 assertions, 0 failures, 0 errors (подпроцессные тесты SIGINT/SIGTERM в т.ч. mid-run и в режиме ожидания); полный прогон 8x стабилен, зависших процессов не остаётся.
<!-- SECTION:FINAL_SUMMARY:END -->
