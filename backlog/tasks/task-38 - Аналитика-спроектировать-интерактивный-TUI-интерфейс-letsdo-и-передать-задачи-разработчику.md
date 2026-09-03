---
id: TASK-38
title: >-
  Аналитика: спроектировать интерактивный TUI-интерфейс letsdo и передать задачи
  разработчику
status: Done
assignee:
  - '@analyst'
created_date: '2026-09-03 20:31'
updated_date: '2026-09-03 21:09'
labels: []
dependencies: []
ordinal: 27000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Сейчас letsdo запускается как неинтерактивный поток: мысли и действия агента идут вверх, управлять окном нельзя. Нужен интерактивный терминальный интерфейс: (1) верхняя зона — какой агент запущен и прогресс выполнения: сколько задач назначено, сколько сделано, сколько осталось (или иной статус/интерактив); кроме имени агента в шапке показывать: идентификатор агента, сколько задач он сделал в текущей сессии, сколько длится сессия (таймер сессии), сколько задач осталось, сколько времени идёт работа над текущей задачей; (2) центральная зона — живой поток мыслей и действий агента с возможностью прокрутки. Задача аналитика: исследовать варианты реализации (известные TUI-библиотеки: ratatui (Rust), bubbletea (Go), и другие; Ruby-решения — Cursive, экосистема TTY (tty-screen/tty-cursor/tty-reader), чистые ANSI/альтернативный буфер экрана); выбрать стек с учётом того, что letsdo — Ruby-джем, потребляющий поток pi --mode json (Letsdo::OutputStreamer уже разделяет текст ответа и служебные строки инструментов); сформулировать требования и UX-спецификацию, включая источники данных для метрик шапки (кто считает сессию, откуда берутся сделано/осталось — backlog CLI или состояние Letsdo::Loop); по итогам создать в бэклоге задачи для разработчика с подробным описанием того, что нужно реализовать (раскладка, интерактив, интеграция с Letsdo::Loop/PiRunner/OutputStreamer, получение прогресса задач из backlog CLI). Результат работы аналитика — новые задачи в бэклоге, назначенные на @developer, готовые к выполнению.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Исследованы минимум 3 подхода к TUI (например Ruby ANSI/TTY-экосистема, Ruby ncurses/Cursive, внешний хелпер на ratatui/bubbletea) с оценкой применимости к letsdo (Ruby-джем, поток pi --mode json)
- [x] #2 Выбран стек с письменным обоснованием, решение зафиксировано
- [x] #3 UX-спецификация: раскладка экрана (шапка: имя агента + зона прогресса; центральная скроллируемая область потока) и список интерактивных действий (прокрутка, пауза/возобновление, выход, обновление прогресса/статуса)
- [x] #4 В бэклоге созданы задачи(и) на @developer с описанием реализации, критериями приёмки и указанием затрагиваемых компонентов letsdo
- [x] #5 Созданные аналитиком задачи учитывают TASK-35/36/37: тексты интерфейса на английском, код проходит rubocop, rake test зелёный
- [x] #6 UX-спецификация: раскладка экрана (шапка: имя и идентификатор агента, счётчик выполненных в сессии задач, таймер длительности сессии, сколько задач осталось, время работы над текущей задачей; центральная скроллируемая область потока) и список интерактивных действий (прокрутка, пауза/возобновление, выход, обновление прогресса/статуса)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Survey current stream architecture (PiRunner --mode json events, OutputStreamer stdout/stderr split, Loop/AgentLoop, CLI.run_agent) — data sources for header metrics.
2. Research >=3 TUI stacks: (a) pure-Ruby ANSI + tty-screen/tty-cursor/tty-reader primitives; (b) Ruby curses/ncursesw (C extension); (c) external TUI binary (ratatui/Rust, bubbletea/Go) as a helper process. Evaluate per stack: distribution cost for a Ruby gem (native deps/toolchains), Unicode, key input handling, signal/SIGWINCH interplay, fit with the line-based pi --mode json stream, maintenance.
3. Decide the stack with written rationale; record decision in the task.
4. Write the UX spec: header layout + metric data sources (agent name/ID, done count, session timer, tasks remaining, current-task elapsed), central scrollable stream, interactive actions (scroll, pause/resume, refresh, quit), non-TTY fallback.
5. Create @developer implementation task(s): renderer, input loop, loop metrics wiring (callbacks on Letsdo::Loop/AgentLoop), terminal setup/teardown (alternate screen, raw mode), gemspec deps, tests; ACs list affected letsdo components (CLI, Loop, AgentLoop, OutputStreamer, PiRunner, gemspec, bin/letsdo, tests, CI).
6. Verify ACs #1-#6 (research >=3 approaches recorded, decision recorded, UX spec recorded, developer tasks exist with ACs), final summary, Done, commit.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Дополнено пользователем (2026-09-03): в шапке интерфейса кроме имени агента должны быть: идентификатор агента; сколько задач сделано в текущей сессии; сколько длится сессия (таймер); сколько задач осталось; сколько времени идёт работа над текущей задачей.

Validation: all analysis artifacts recorded in TASK-38 comments (ARCHITECTURE SURVEY, TUI RESEARCH — 4 approaches A-D, UX SPECIFICATION); deliverable TASK-42 created, assigned to @developer (priority high, type enhancement, depends on TASK-39), 7 ACs incl. affected letsdo components and TASK-35/36/37 compliance. No code changed by the analyst — no tests to run for this analysis task.
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: @analyst
created: 2026-09-03 21:08
---
ARCHITECTURE SURVEY (data sources for header metrics):
Components and where each metric can come from:
- Agent name: CLI arg (letsdo <name>).
- Agent identifier: no backend agent-ID concept exists. The de-facto identity used by the backlog is the assignee handle, currently AGENT_ASSIGNEE_HANDLE or '@'+name (CLI#assignee_handle). Decision: header shows name + handle as the identifier (e.g. 'developer (@developer)').
- Tasks done in session: counts completed agent runs — known only to the loop driver (AgentLoop/Loop), not currently exposed. Needs a metrics facade with callbacks (on_run_start/on_run_end/on_batch).
- Session timer: monotonic clock (Process.clock_gettime CLOCK_MONOTONIC) from TUI start.
- Tasks remaining: open task count from the last BacklogTasks provider call — Loop knows it per iteration; expose latest count via the same facade.
- Current-task elapsed: measured in the driver between run start and run end (monotonic clock).
Stream/rendering integration point: OutputStreamer already splits agent text (stdout) from service tool lines (stderr). The TUI renders both into one scrollable buffer; PiRunner keeps its line-based JSON event loop unchanged. pi child spawn keeps pipes for its stdout (events); its stdin should be closed/null so the TUI owns the keyboard.
Key conflict: Letsdo::Loop is generic and injectable (task_provider, run_task, sleeper) — keep it generic; the metrics facade is a separate small object wired at CLI level (like AgentLoop already is). AgentLoop's wrapped_provider/wrapped_run already centralize per-iteration messages — the natural place to emit metrics events.
---

author: @analyst
created: 2026-09-03 21:08
---
TUI RESEARCH — 4 approaches evaluated (AC #1).
Environment facts: Ruby 4.0.2 locally (gem requires >=3.0); no Rust/cargo on this machine; Go and Node present; rubygems network OK; tty-screen 0.8.2, tty-cursor 0.7.1, tty-reader 0.9.0, curses 1.7.0 all published.

(A) Pure-Ruby ANSI + TTY primitives (tty-screen + tty-cursor + tty-reader [+ unicode-display_width]):
  - tty-screen: terminal size; tty-cursor: movement/hide/show/alt-screen helpers; tty-reader: raw-mode key decoding (arrows, Ctrl-*, Esc) → clean symbols.
  - Zero native deps: works anywhere Ruby runs (Linux/macOS/Windows via ANSI). Gem install stays trivial — fits letsdo's dependency-free gemspec (only runtime deps we choose ourselves).
  - We own the render loop: full repaint of header+log on data/tick/key events; complete control over Unicode (we already print ✓/✖/⚙ in OutputStreamer).
  - Costs: hand-rolled alt-screen setup, scroll math, resize (SIGWINCH re-query), key loop; must design for testability (inject render target/keys).
  - Verdict: strong fit — layout is just header + scrollable log, exactly the 'small composable primitives' scenario.

(B) Ruby curses / ncursesw (C extension gem):
  - Full ncurses toolkit: windows, getch, KEY_RESIZE, panels — least custom render code.
  - Cons: C extension compiled at install (needs ncurses dev headers; on many systems absent → install breaks — hostile for a gem); removed from Ruby default gems since 3.0; classic ncurses is byte-oriented, Unicode/combining-char rendering weak; markup/color limited.
  - Verdict: rejected — distribution friction + Unicode stream risk exceed the saved render code for a two-zone layout.

(C) External TUI helper binary (ratatui/Rust, bubbletea/Go):
  - Best UX toolkits (layouts, mouse, theming) but: compiled binary per OS/arch must be shipped or built at install (toolchain requirement — no Rust on this machine at all); cross-language IPC (JSON lines over stdio/PTY) must be designed, versioned, tested; two language ecosystems to maintain; packaging a native binary into a gem is heavy.
  - Verdict: rejected as overkill — no perf/pixel-exact needs; header + scrollable log does not justify a compiled helper.

(D) Raw ANSI with no gems (termios + hand-rolled escape parsing):
  - Zero deps, same ownership as (A) but we re-implement what tty-* already solved (size probing, key decode, cursor ops) and lose portability win.
  - Verdict: rejected — only wins vs (A) if we refuse ANY runtime dependency; maintainability favors the tty-* primitives.

DECISION (AC #2): Approach (A) — pure-Ruby in-process TUI built on tty-screen/tty-cursor/tty-reader, added as runtime deps to letsdo.gemspec. Renderer is a pure function over (metrics, log buffer) → framed text so tests need no terminal; automatic fallback to the current line-stream when stdout is not a TTY (pipes/CI/tests) — plain path byte-identical to today. No PTY, no wrapper process: integration point is OutputStreamer callbacks (log buffer) + a metrics facade fed by the loop driver at CLI level; Letsdo::Loop stays generic (injectable).
---

author: @analyst
created: 2026-09-03 21:09
---
UX SPECIFICATION (AC #3, #6).
Mode selection: TUI is active when stdout is a TTY and TERM != 'dumb'; otherwise the current plain line-stream output is used unchanged (tests/CI/pipes unaffected).

Screen layout (alternate screen buffer, full repaint):
  ┌ letsdo · developer (@developer)             session 00:12:34 ┐   <- line 1: name + identifier (assignee handle); session timer
  │ done 3 · left 2 · current task TASK-42 · 00:03:21 running    │   <- line 2: done in session / tasks remaining / current task elapsed
  │   (waiting mode: 'no open tasks, retrying in 10s' / 'PAUSED' overlay)  <- state line, line 2 variant
  ├─────────────────────────────────────────────────────────────┤
  │ agent text deltas + tool lines (HH:MM:SS ⚙ name: args,       │   <- central zone: scrollable combined log, newest at bottom
  │ ✓/✖ completions) — exactly what OutputStreamer produces      │
  ├─────────────────────────────────────────────────────────────┤
  │ ↑/↓ PgUp/PgDn scroll · p pause · r refresh · q quit          │   <- footer: persistent key help
  └─────────────────────────────────────────────────────────────┘
Header metrics — data sources:
  - agent name: CLI arg; identifier: assignee handle (AGENT_ASSIGNEE_HANDLE, default '@'+name) — no backend agent-ID concept exists, the handle is the de-facto identity (recorded decision).
  - tasks done in session: counter in the metrics facade, incremented on each completed run (driver callback), not backlog-derived.
  - session timer: monotonic clock (Process.clock_gettime CLOCK_MONOTONIC) since TUI start; repaint tick ~1s.
  - tasks remaining: length of the latest open-task list from BacklogTasks provider (Loop refetches per iteration; facade exposes the last count; 'r' forces an immediate re-fetch).
  - current-task elapsed: monotonic time since the current run started (driver run_start callback), reset on run end; header shows 'waiting for tasks' when no run is active.

Central zone behavior:
  - Auto-follow: view sticks to newest line while scrolled to the bottom; scrolling up leaves follow mode; any new line while in follow mode re-sticks (classic tail -f semantics).
  - Divider: a separator line marks the current agent run boundary when multiple tasks run in one session.

Interactive actions (footer lists them):
  - ↑ / ↓ — scroll one line; PgUp/PgDn — page; Home/End — top/bottom; back to bottom (or any of ↑/PgUp/etc. followed by End) resumes follow.
  - p — pause/resume: display freeze (log keeps buffering, view stays, 'PAUSED' shown in header); second press resumes. Pausing the agent run itself (SIGSTOP) is explicitly out of scope — recorded decision.
  - r — refresh: re-query open-task count from backlog CLI now (updates 'left'), repaint.
  - q — quit: identical to SIGINT/SIGTERM handling (terminate pi child, stop the loop, leave alt screen, restore terminal, exit 0). Ctrl-C keeps working through the existing signal path.
  - SIGWINCH: re-query terminal size, repaint. Alt-screen/raw-mode restored on any exit path (q, signal, crash via ensure block).

Testability contract: renderer = pure function (metrics snapshot, log buffer, width/height) -> framed String; input = injected key stream; no test touches a real TTY; existing non-TTY tests stay as the plain-mode regression guard.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Analysis done (TASK-38): surveyed the letsdo stream architecture (PiRunner/OutputStreamer/Loop/AgentLoop/CLI), evaluated 4 TUI approaches with feasibility assessment and selected a pure-Ruby in-process stack (tty-screen/tty-cursor/tty-reader) with written rationale — rejected curses (native dep, weak Unicode) and external ratatui/bubbletea binaries (toolchain/portability) as overkill. Recorded in TASK-38 comments: architecture/data-source survey, research + decision, and the full UX spec (header metrics incl. name+handle, done-in-session, session timer, remaining, current-task elapsed; central scrollable stream; ↑/↓/PgUp/PgDn/Home/End scroll, p pause, r refresh, q quit; SIGWINCH; non-TTY fallback). Deliverable: TASK-42 (TUI, @developer, high, dep TASK-39) with 7 ACs covering implementation, testability without a real TTY, English UI (TASK-35), rubocop (TASK-37), CI-safe non-TTY fallback (TASK-36) and affected components. Verified: ACs #1-#6 by the recorded comments + existing TASK-42; rake test / rubocop not run — no code touched.
<!-- SECTION:FINAL_SUMMARY:END -->
