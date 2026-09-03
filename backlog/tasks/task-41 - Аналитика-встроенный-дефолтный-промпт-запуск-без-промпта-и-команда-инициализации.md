---
id: TASK-41
title: >-
  Аналитика: встроенный дефолтный промпт, запуск без промпта и команда
  инициализации
status: Done
assignee:
  - '@analyst'
created_date: '2026-09-03 20:48'
updated_date: '2026-09-03 21:13'
labels: []
dependencies: []
type: spike
ordinal: 30000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Сейчас агента нельзя запустить без готового файла промпта: letsdo <имя> требует agents/<имя>.md, иначе 'Unknown agent: <имя>' и exit 1. Требование пользователя: (1) встроенный дефолтный промпт — агент запускается даже если файла промпта нет, как независимый сотрудник: просто внимательно выполняет поставленные на него задачи (всё, что описано в отдельном процессе работы над задачами); (2) при запуске без промпта — уведомление: по каким путям искался промпт, где его можно разместить; сообщение может показываться ограниченное время — решение за аналитиком; (3) команда инициализации, например letsdo <имя> --init: агента НЕ запускает, только создаёт в нужной папке (agents/) файл <имя>.md со стартовым дефолтным промптом; (4) дефолтный промпт без какой-либо специфики проекта — только процесс работы над задачами: взять одну задачу, выполнить её по протоколу, завершить прогон; ориентир — текущий agents/developer.md без его специфики (роль, проект, язык); настройки — позже, пока только текст. Задача аналитика: продумать сценарии и UX (fallback при отсутствии промпта, уведомление о путях поиска и месте размещения файла, семантика и синтаксис команды инициализации, где хранится шаблон, как дефолтный промпт сочетается с циклом оркестратора), спроектировать решение и по итогам создать несколько задач для разработчика, которые решат эту проблему.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Сценарии проанализированы и зафиксированы: запуск без промпта (fallback на встроенный дефолтный промпт), уведомление о путях поиска и месте размещения промпта, семантика команды инициализации
- [x] #2 Спроектирован текст встроенного дефолтного промпта: без специфики проекта, процессный (одна задача за прогон, протокол выполнения задач), совместим с циклом оркестратора (TASK-39)
- [x] #3 Определена команда инициализации (флаг или подкоманда, например --init): только создаёт agents/<имя>.md со стартовым промптом, агента не запускает; указано, где хранится шаблон
- [x] #4 Определено уведомление при запуске без промпта: какие пути проверялись, куда положить файл, как долго показывать сообщение
- [x] #5 В бэклоге созданы задачи(и) на @developer: реализация fallback-промпта, команда инициализации, шаблон, тесты — с AC и указанием затрагиваемых компонентов (Letsdo::CLI, Letsdo::PromptStore, errors, bin/letsdo)
- [x] #6 Задачи разработчика учитывают TASK-35/37/39: тексты на английском, rubocop 0 offenses, rake test зелёный; дефолтный промпт согласован с циклом из TASK-39
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Study current state: CLI#run_agent (PromptStore#read raises UnknownAgentError -> exit 1), PromptStore (agents/<name>.md under LETSDO_ROOT), Agent (prompt read per run), TASK-39 AgentLoop wiring, tests (prompt_store/cli/agent), gemspec packaging (spec.files = lib/**/*.rb only).
2. Define scenarios + UX: (A) prompt exists — unchanged; (B) no prompt, plain run — fallback to built-in default prompt + one-time stderr notification (paths checked, placement hint, 'letsdo <name> --init'); (C) 'letsdo <name> --init' — create agents/<name>.md with the default prompt, never run the agent, refuse overwrite; (D) '--init' without a name — usage exit 1; (E) unsafe name (path separators) — refuse, exit 1.
3. Design canonical default prompt text: process-only (one task per run, task execution protocol, no role/project/language specifics), aligned with the TASK-39 loop (one run = one task, loop handles waiting).
4. Decide component ownership: new Letsdo::DefaultPrompt (constant, single source of truth for fallback + --init template, no gemspec/packaging change); PromptStore#read -> nil when missing + #agent_path + #create_agent (no overwrite, safe names); Agent#run falls back to DefaultPrompt.text; CLI prints notification and handles --init (argv[0]='--init' <name> or <name> '--init'); errors.rb — UnknownAgentError removed (no unknown agents), Letsdo::Error kept.
5. Create @developer tasks (2): (TASK-43) default prompt + fallback run; (TASK-44) --init command. Each with ACs, affected letsdo components, TASK-35/37/39 compliance.
6. Verify ACs #1-#6, final summary, Done, commit backlog files only (developer's TASK-39 work in lib/bin/test stays uncommitted).
<!-- SECTION:PLAN:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: @analyst
created: 2026-09-03 21:12
---
SCENARIO ANALYSIS (AC #1).

Current behavior: CLI#run_agent calls PromptStore#read(name), which raises
UnknownAgentError when agents/<name>.md is missing -> message + agent list,
exit 1. PromptStore knows exactly one lookup path: <LETSDO_ROOT|pwd>/agents/<name>.md.
Agent#run re-reads the prompt on every run via PromptStore. The TASK-39 loop
(AgentLoop, current uncommitted state of the repo) does not depend on the
prompt existing — it only needs the agent name (handle @<name>) and the
provider.

Scenarios (all English texts per TASK-35):

A) Prompt file exists (normal). Unchanged: read agents/<name>.md, run the
   loop, no notification.

B) No prompt file, plain run: `letsdo <name>`. The agent STILL starts — the
   built-in default prompt is used; the loop semantics are untouched
   (all open tasks for @<name> one run per task, wait when none, SIGINT/
   SIGTERM stop, exit 0). Identity = the name: the same name defines the
   assignee handle and the would-be prompt path. Rationale: the requirement
   "runs as an independent employee" means ANY name is a valid worker; the
   file is an optimization (custom instructions), not a precondition.
   Before the first loop message, CLI prints a ONE-TIME notification on
   stderr (see DESIGN comment #2).

C) `letsdo <name> --init`. Does NOT run the agent. Creates
   agents/<name>.md with the starter default prompt, exit 0. Existing file
   -> message "already exists", exit 1, never overwritten. Missing name
   (`letsdo --init`) -> usage + exit 1. Unsafe name (contains "/" or "..")
   -> refused, exit 1 (path-safety: creation must never write outside agents/).

D) Other combinations: `--version`/`--help` keep their current priority when
   argv[0]; unknown options still exit 1; extra plain args after a name
   (without --init) are ignored as today.

E) agents/ directory missing: --init creates it (mkdir_p); plain run with
   no agents/ simply falls back (B) — the notification still names the
   would-be path.

Notification "limited time" decision: in the current line-stream CLI the
message is printed exactly once at process start on stderr (service output
channel), before the first loop message, and is NOT repeated on later loop
iterations — that is the line-stream analog of a transient banner. When the
TUI from TASK-42 lands, it can render the same notice once as a header
banner; no design change needed here.
---

author: @analyst
created: 2026-09-03 21:12
---
DESIGN DECISIONS (AC #3, #4): template storage, component ownership, notification spec.

Template storage: one canonical prompt text, embedded as a Ruby constant in
a new file lib/letsdo/default_prompt.rb — Letsdo::DefaultPrompt::TEXT
(frozen string). Single source of truth used by BOTH the fallback run and
--init file creation, so an initialized file always matches what a
fallback run uses. Chosen over a packaged .md asset because the gemspec
packages only lib/**/*.rb (spec.files = Dir["lib/**/*.rb", "README.md",
"LICENSE"]) — an .md asset would force a gemspec files-pattern change and
data-dir plumbing; a constant needs none, is trivially testable and has no
install-time I/O. No per-agent settings yet (out of scope — "settings later,
text only" per task).

Component ownership (affected letsdo components):
- Letsdo::DefaultPrompt (NEW, lib/letsdo/default_prompt.rb): the prompt
  text constant. Required in lib/letsdo.rb.
- Letsdo::PromptStore (lib/letsdo/prompt_store.rb): contract change —
  #read(name) returns nil when agents/<name>.md is missing (no raise);
  new #agent_path(name) -> absolute path (for the notification);
  new #create_agent(name, content) -> true when created, false when the
  file exists or the name is unsafe (contains "/" or "\" or is "."/"..")
  — never raises, never overwrites, mkdir_p the agents/ dir.
- Letsdo::Agent#run (lib/letsdo/agent.rb): prompt = PromptStore#read(name)
  || DefaultPrompt::TEXT — a run always has a prompt; the fallback lives
  here so a single run is self-sufficient (same place the old raise came
  from).
- Letsdo::CLI (lib/letsdo/cli.rb): (1) run_agent no longer rescues
  UnknownAgentError; when store.read(name) is nil it prints the one-time
  notification and proceeds (Agent falls back itself); (2) --init handling:
  recognized as argv[0] (then argv[1] = name) or as argv[1] after a name
  (letsdo <name> --init); on success "created <path>" to stdout, exit 0;
  already exists / unsafe name / missing name — error to stderr, exit 1.
- Letsdo::Errors (lib/letsdo/errors.rb): UnknownAgentError is REMOVED —
  with the fallback there are no unknown agents; the base Letsdo::Error
  class is kept as the package error surface.
- bin/letsdo header comment and README.md: document --init and the
  fallback announcement; README code-structure section gains DefaultPrompt.
- Tests: prompt_store_test (read -> nil, create_agent create/skip/unsafe/
  mkdir, agent_path), agent_test (unknown name runs with the default
  prompt via fake pi argv), cli_test (fallback notification once +
  content, --init creates file / skips existing / missing name / does not
  run pi / unsafe name), errors tests removed with the class.

Notification spec (AC #4): printed once, on stderr, before the first loop
message. Paths checked: exactly one — <resolved root>/agents/<name>.md
(root = LETSDO_ROOT, default pwd); no legacy paths are probed. Wording
(English, exact strings to implement):
  letsdo: no prompt for <name> at <root>/agents/<name>.md
  letsdo: using the built-in default prompt (create a prompt file with
  'letsdo <name> --init')
The second line is the placement hint; the command is copy-pasteable. Test
asserts both lines appear exactly once for a missing-prompt run.
---

author: @analyst
created: 2026-09-03 21:12
---
BUILT-IN DEFAULT PROMPT — canonical text (AC #2). Process-only: no role, no
project, no language specifics; one task per run (orchestrator loop from
TASK-39 supplies one task per agent run — the prompt never picks multiple).
This exact text goes into Letsdo::DefaultPrompt::TEXT and is what
'letsdo <name> --init' writes to agents/<name>.md. Modeled on
agents/developer.md with all specifics stripped (role, project, backlog
commands, language policy).

---8<--- agents/default_prompt.md (canonical text) ---8<---

# Task agent

You are an autonomous task agent. You pick up the tasks assigned to you and
execute them one at a time following the task-work process below. You do not
implement features or designs on your own initiative: your work is defined
by the assigned tasks, one task per run.

## Main rule: exactly one task per run

In a single run you pick up and complete exactly one task assigned to you,
then stop. The next task is started only in the next run of the orchestrator
loop.

If there are no tasks assigned to you — do not invent work and do not create
tasks yourself. End the run with a message that there are no tasks.

## Choosing a task

Take the highest priority task assigned to you in order:

0. if a task is already in progress
1. priority
2. order (ordinal), if priorities are equal

If the chosen task is currently blocked, take the task that blocks it into
work, using the same selection algorithm: first the highest priority, then
in order.

## Task-work process

Execute the task according to the established protocol:

1. **Start**: read the task instructions, check its status and Acceptance
   Criteria, move it to an active status and assign it to yourself.
2. **Plan**: study the current state of the system, draft an implementation
   plan and record it in the task.
3. **Work**: do the work in short iterations, checking intermediate results
   and recording progress in the task as you go.
4. **Completion**: verify each Acceptance Criterion with objective evidence,
   mark the completed items, write a final summary and move the task to the
   terminal status.
5. Commit your changes, including any project bookkeeping affected by the
   task.

## Prohibitions

- Do not take work that is not assigned to you.
- Do not complete several tasks in one run.

---8<--- end of canonical text ---8<---

Conformance notes:
- Compatible with TASK-39: the loop owns task selection and waiting; the
  prompt only constrains a single run (one task, no invented work).
- No references to Backlog.md CLI commands or project conventions — the
  protocol steps are described generically so the template is project-agnostic.
- 'Task agent' is used as the heading instead of any real name: the same
  text serves every fallback run and --init regardless of the agent's name.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Analysis complete: scenarios, design and canonical default prompt recorded in TASK-41 comments (SCENARIO ANALYSIS, DESIGN DECISIONS, BUILT-IN DEFAULT PROMPT). Deliverables handed to @developer: TASK-43 (built-in default prompt + fallback run: latest Letsdo::DefaultPrompt constant, PromptStore#read -> nil + #agent_path, Agent Truth fallback, one-time stderr notification, UnknownAgentError removed) and TASK-44 (init command 'letsdo <name> --init': PromptStore#create_agent with no-overwrite/unsafe-name guards, CLI arg handling, docs), each with 6 ACs and affected letsdo components. Verified: ACs #1-#6 checked against recorded comments and created tasks (no code changed by the analyst — nothing to test). Both dev tasks comply with TASK-35/37/39 (English, rubocop 0, tests green, loop untouched).
<!-- SECTION:FINAL_SUMMARY:END -->
