---
id: TASK-87
title: Replace up/down navigation buttons with mouse scroll in agent output view
status: To Do
assignee: []
created_date: '2026-09-10 07:34'
labels: []
dependencies: []
priority: medium
type: enhancement
ordinal: 76000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
In the agent output view (TUI / terminal UI), the current navigation uses up/down keyboard buttons for scrolling through the agent's operation output. This is inconvenient.\n\nReplace the up/down button navigation with standard mouse scrollwheel support: the user should be able to scroll up and down using the mouse wheel, as expected in any normal scrollable view.\n\nThe up/down buttons should be removed — they clutter the UI and are not ergonomic.\n\nMouse scrollwheel must work naturally: scrolling down moves forward through output, scrolling up moves backward.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Up/down navigation buttons are removed from the agent output view
- [ ] #2 Mouse scrollwheel scrolls the output vertically (up = backwards, down = forwards)
- [ ] #3 Scroll behaves naturally — no jumpiness, follows standard terminal scroll behavior
- [ ] #4 No regressions: all existing output content remains readable and accessible
<!-- AC:END -->
