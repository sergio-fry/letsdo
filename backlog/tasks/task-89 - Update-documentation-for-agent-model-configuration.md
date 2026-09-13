---
id: TASK-89
title: Update documentation for agent model configuration
status: Done
assignee:
  - '@analyst'
created_date: '2026-09-10 10:29'
updated_date: '2026-09-13 16:26'
labels: []
dependencies: []
priority: medium
ordinal: 78000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Document how to set the model per agent via the YAML front-matter config block (agents/<name>.md). After TASK-88, users need clear docs on the front-matter format, model syntax, and examples for per-agent model selection.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 docs describe the YAML front-matter block with model field
- [x] #2 README or docs include at least one concrete example
- [x] #3 docs mention default behavior when model is absent
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Verify the shipped behavior from source: PromptStore#config / parse_front_matter, Agent#run, Backends::Pi#initialize (model precedence vs a --model already in flags), and the covering tests in test/prompt_store_test.rb / test/agent_test.rb.
2. Decide placement: the config block lives in the agent prompt file, so document the mechanism/semantics in docs/config.md (configuration reference) and correct its current claim that nothing is configured in files; add a concrete example to docs/prompts.md (prompt-authoring guide) and a short mention in README.
3. Write the docs with one canonical example and cross-links (no duplication), covering: front-matter format, the model field, precedence (LETSDO_PI_FLAGS --model wins), default when model is absent, and extensibility.
4. Verify with objective evidence: parse the documented example through the real PromptStore, check doc links, run the test suite.
5. Finalize: check ACs, write the final summary, move to Done, commit.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Docs written (docs-only change, no code):
- docs/config.md — new section 'Per-agent configuration (YAML front matter)': block format, the model field, strip-before-prompt behavior, default when absent, precedence (LETSDO_PI_FLAGS --model wins), extensibility; corrected the intro claim that nothing is configured in files; added the model precedence bullet and updated the LETSDO_PI_FLAGS row.
- docs/prompts.md — new section 'Optional: per-agent configuration' with a concrete example, TOC entry and checklist item.
- README.md — agent-files feature bullet, a concrete front-matter example in Getting started, LETSDO_PI_FLAGS table note, and updated guide descriptions.

Verification:
- Parsed the exact documented example through the real Letsdo::PromptStore: config('developer') => {model: 'anthropic/claude-sonnet-4-5'}; front matter is stripped from the prompt text.
- Confirmed fallbacks with the real class: missing file / no front matter / invalid YAML all => {} (no --model, pi default); unknown keys (tags) parsed and ignored.
- Model precedence confirmed against test/agent_test.rb#test_run_agent_does_not_override_cli_model_flag and test/prompt_store_test.rb (both green: 10 runs / 18 assertions and 18 runs / 40 assertions, 0 failures).
- Markdown fences balanced in README.md, docs/prompts.md, docs/config.md; anchor links (#per-agent-configuration-yaml-front-matter, #optional-per-agent-configuration) match the headings.
Note: the full suite was flaky during verification because another agent (TASK-95) was editing lib/letsdo/providers/* and test/providers/* concurrently; those files are unrelated to this docs change and are not part of this task's commit.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Documented per-agent model configuration introduced in TASK-88. docs/config.md gained a 'Per-agent configuration (YAML front matter)' section (block format, the model field, strip-before-prompt, fallback when absent, precedence: LETSDO_PI_FLAGS --model wins; extensible block) and its outdated 'nothing is configured in files' intro was corrected; docs/prompts.md gained an 'Optional: per-agent configuration' section with TOC entry and checklist item; README.md gained a feature-bullet mention, a concrete front-matter example in Getting started, a LETSDO_PI_FLAGS note and updated guide descriptions. Verified by parsing the exact documented example through the real Letsdo::PromptStore (model => 'anthropic/claude-sonnet-4-5', front matter stripped), confirming empty-hash fallbacks for missing/no-front-matter/invalid YAML and ignored unknown keys, and by the green targeted tests test/prompt_store_test.rb (18 runs/40 assertions) and test/agent_test.rb (10 runs/18 assertions), which cover the documented precedence.
<!-- SECTION:FINAL_SUMMARY:END -->
