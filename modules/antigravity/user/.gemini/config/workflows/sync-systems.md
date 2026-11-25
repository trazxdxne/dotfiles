---
description: Check and synchronize dotfiles and Projects repositories across Windows and CachyOS.
---

# Sync Systems Workflow

1. Run `reposync status --fetch` to inspect dirty, unpushed (`ahead`), and behind repositories across `~/Projects/*` and `dotfiles`.
2. For clean behind repositories, run `reposync pull`.
3. For repositories with unpushed local commits, run `reposync push`.
4. After pulling `dotfiles`:
   - On **CachyOS**: run `./install.sh` (and `./system/setup-system.sh` if `system/` changed).
   - On **Windows**: run `.\modules\antigravity\install-windows.ps1`.
