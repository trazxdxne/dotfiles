---
name: obsidian-task-organizer
description: Use when the user wants to organize Obsidian tasks, convert task lists into individual files, or sort tasks by importance (stars).
---

The goal is to structure the user's impromptu task lists into individual files categorized by platform (`Tasks/Linux`, `Tasks/Windows`, `Tasks/General`) and sorted by importance using a star prefix.

## Core Rules

- **Deduplication & Merging**: Never split a single bullet into multiple tasks (no hallucinations). HOWEVER, you must actively avoid duplicates:
  1. If multiple bullets in the Inbox are essentially the same task, MERGE them into a single new file.
  2. Before creating a new file, check the `Tasks/` or  directory to see if a highly similar task already exists. If it does, do NOT create a new file. Instead, you may append the new bullet's context to the existing file if it adds valuable details.
- **Polishing**: The user writes impromptu. You must polish the task.
  - **Filename**: Create a concise, actionable filename without typos.
  - **Content**: Place the original impromptu bullet text inside the file as context. Below it, add a `**Детали:**` section. Under details, provide structured steps or a breakdown, and you MUST use Markdown checkboxes (`- [ ] `) for every item in the list, fixing any errors.
- **Priority Prefix**: Evaluate the task's importance or speed. 
  - `★★★ ` - High priority, urgent bugfix, or something very quick (1 minute).
  - `★★☆ ` - Medium priority.
  - `★☆☆ ` - Low priority.
  Prefix the filename with this exact string.
- **Target Directories**: Move/create the files in `Tasks/Linux/`, `Tasks/Windows/`, or `Tasks/General/` inside the Obsidian Vault.

## Steps

1. **Locate Source Files**: Read the `/home/trazxdxne/Documents/Obsidian Vault/Inbox.md` file. This is the only file you should process unless the user specifies otherwise.
2. **Read Content**: Read the source files to extract all bullet points.
3. **Draft Transformations**: For each bullet point, decide the target category, the priority prefix (★★★, ★★☆, ★☆☆), the polished filename, and the polished content.
4. **Create Files**: Create the new individual `.md` files in the target directories (`Tasks/Linux/`, `Tasks/Windows/`, `Tasks/General/`).
5. **Clean Up**: Remove the processed bullet points from the source files, leaving the rest of the file intact.
