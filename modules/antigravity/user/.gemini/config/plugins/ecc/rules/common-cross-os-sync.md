# Cross-System Git Sync (Windows & CachyOS)

You work across **Windows** and **CachyOS (`ryoku`)**. Unpushed commits or stale clones on either OS cause divergence and merge conflicts.

## Rules

1. **Pull before editing:** At the start of work in `dotfiles` or any `~/Projects/*` repository, inspect `git status -sb` and `git fetch` (or run `reposync status --fetch`). If behind `origin`, run `git pull --rebase` before editing.
2. **No unpushed work left behind:** When finishing a task that modifies tracked files, verify `git status -sb` and `reposync status` so no completed work remains uncommitted or unpushed (`ahead > 0`).
3. **Cross-platform paths & line endings:** Never commit machine-specific absolute home paths (`/home/<user>`, `/c/Users/<user>`) into shared configs when a template/installer substitution can resolve them at deploy time. Respect `.gitattributes` LF/CRLF rules.
