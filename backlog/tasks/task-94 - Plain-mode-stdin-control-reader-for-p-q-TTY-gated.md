---
id: TASK-94
title: 'Plain mode: stdin control reader for p/q (TTY-gated)'
status: Done
assignee:
  - '@developer'
created_date: '2026-09-13 13:29'
updated_date: '2026-09-13 14:09'
labels: []
dependencies:
  - TASK-74
priority: medium
type: enhancement
ordinal: 83000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add a small control reader used only in plain line-stream mode (stdout not a TTY / TERM=dumb / CI) when stdin IS a terminal. A dedicated thread reads Enter-terminated lines and maps: `p` toggles pause (the same Control::PauseGate + PiRunner#pause/resume as the TUI `p`, TASK-74), `q` requests a clean stop (Thread.main.raise Letsdo::Stopped, the same as a stop signal). The reader is never started when stdin is not a TTY (pipes, /dev/null, CI), must exit quietly on EOF or read error, and must never steal stdin bytes when stdin is a pipe.

This task delivers the reader class and its unit tests only. Wiring it into the CLI and the PTY integration test are a separate task.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A new reader class (e.g. Letsdo::Control::Reader) reads Enter-terminated commands from an injected TTY stream and maps p to pause toggle and q to stop (Thread.main.raise Letsdo::Stopped)
- [x] #2 Non-TTY input: the reader is not started and consumes no bytes
- [x] #3 EOF or read error: the reader exits quietly with no crash and no partial output
- [x] #4 Unit tests use an injected fake/pipe, no real TTY; rake test 0 failures; rubocop 0 offenses
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add Letsdo::Control::Reader (new lib/letsdo/control/reader.rb, required from control.rb): TTY-gated background reader over an injected stdin, Enter-terminated commands: 'p' toggles the shared PauseGate + current backend pause/resume (callable runner, nil no-op), 'q' raises Letsdo::Stopped into the main thread; injectable on_stop for tests; tty override so unit tests can drive a pipe.
2. Guarantees: start returns nil and reads nothing when stdin is not a terminal (available? gate); reader writes no output; EOF/read error exits the thread quietly; report_on_exception off.
3. Unit tests (test/control_reader_test.rb, no real TTY): pipe + tty override drives p (gate + runner), q default raises Stopped into main; non-TTY start is nil and leaves pipe bytes untouched; EOF and injected read-error exit quietly; no stdout/stderr output.
4. Verify: rake test 0 failures; rubocop --no-server lib bin test 0 offenses.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented Letsdo::Control::Reader in lib/letsdo/control/reader.rb (required from control.rb). TTY-gated: #available? checks input.tty? (overridable via tty: for tests); #start returns nil for a pipe/devnull and reads no bytes. Injected IO + optional PauseGate + callable runner; 'p' toggles @paused then invokes gate and current runner pause/resume (nil/no-op when absent); 'q' calls the stop action (default: Thread.main.raise(Letsdo::Stopped)). read_loop rescues IOError/SystemCallError, thread has report_on_exception=false, writes nothing. Unit tests test/control_reader_test.rb: pipe + tty override, FakeRunner, FailingInput; 10 runs/15 assertions. Manual real-PTY check: 'p' -> paused=true, second 'p' -> paused=false, 'q' -> Letsdo::Stopped in main -> exit 0. Verification: rake test 378 runs, 0 failures/0 errors; rubocop --no-server lib bin test 79 files, no offenses; new file 10 consecutive green runs (no thread flakiness).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added Letsdo::Control::Reader (lib/letsdo/control/reader.rb): a TTY-gated background reader for plain line-stream mode that maps Enter-terminated 'p' to a PauseGate + backend pause/resume toggle and 'q' to Thread.main.raise(Letsdo::Stopped), with an injectable stop action for tests. Non-TTY stdin never starts the reader and consumes no bytes; EOF/read errors end the thread quietly and the reader writes nothing. Wired nothing yet (CLI/PTY integration is TASK-75). Verified with 10 unit tests over IO.pipe + fakes (no real TTY), a manual PTY run (p toggles, q stops with exit 0), rake test 378 runs/0 failures and rubocop 79 files/0 offenses.
<!-- SECTION:FINAL_SUMMARY:END -->
