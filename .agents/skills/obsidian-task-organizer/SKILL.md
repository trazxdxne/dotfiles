---
name: obsidian-task-organizer
description: Triage Obsidian tasks, split impromptu task lists into star-rated task files, or organize Inbox notes into category folders (Today, Linux, Windows, General). Use when user asks to organize tasks or process Inbox.
---

Triage impromptu task lists from `/home/trazxdxne/Documents/Obsidian Vault/Inbox.md` into structured, star-rated task files in `Tasks/<Category>/`.

## Categories

- `Tasks/Today/`: Urgent tasks, immediate daily focus items, or tasks explicitly assigned to today.
- `Tasks/Linux/`: Linux-specific system, desktop, tool, or script tasks.
- `Tasks/Windows/`: Windows-specific tasks.
- `Tasks/General/`: Platform-agnostic or general tasks.

## Formatting Rules

- **Priority Prefix**:
  - `★★★ ` — High priority, urgent, or quick fix (<= 1 min).
  - `★★☆ ` — Medium priority.
  - `★☆☆ ` — Low priority.
- **Filename**: `<Priority Prefix><Concise Actionable Title>.md`
- **File Body**:
  1. Original bullet text as context.
  2. `**Детали:**` heading followed by actionable subtasks with `- [ ] ` checkboxes.

## Execution Steps

1. **Read Inbox**: Read `/home/trazxdxne/Documents/Obsidian Vault/Inbox.md`. Extract all bullet items.
   - *Completion criterion*: All bullet items extracted.
2. **Deduplicate**: Search `Tasks/` subdirectories (`Today/`, `Linux/`, `Windows/`, `General/`) for existing similar tasks.
   - Merge duplicate bullets into one item.
   - If a matching task file exists, append new details to it rather than duplicating.
   - *Completion criterion*: Zero duplicate files targeted for creation.
3. **Format & Categorize**: Assign category (`Today`, `Linux`, `Windows`, `General`), priority prefix, polished filename, and structured body with `**Детали:**` checkboxes.
   - *Completion criterion*: Every item mapped to a category, priority prefix, and formatted body.
4. **Write Files**: Save markdown files to `/home/trazxdxne/Documents/Obsidian Vault/Tasks/<Category>/`.
   - *Completion criterion*: All files written to disk.
5. **Clean Inbox**: Remove processed bullets from `Inbox.md`, preserving vault structure/headers.
   - *Completion criterion*: `Inbox.md` pruned of all processed tasks.
