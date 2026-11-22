# TASK: Overhaul Network Bypass & DPI Circumvention (Arch / CachyOS)

You have access to the complete repository context via C:\Users\trazxdxne\Projects\dotfiles

## The Problem
The current network bypass setup (AWG, WARP, Zapret) in this Arch/CachyOS environment is fragile, frustrating to maintain, and failing against modern Russian DPI/filtering:
- Tunnels and connections drop frequently; swapping or tuning `.conf` files on the fly is painful.
- Zapret is clunky to invoke, with confusing leftovers from Windows scripts.
- DNS routing is opaque and hard to control.
- In Windows, tools like Wiresock (quick `.conf` profile switching) and Flowseal (simple interactive menus) provide a smooth experience. On this Linux system, the UX currently feels neglected and tedious.
- There is zero automated verification to test whether target services (YouTube, Discord, general blocked sites) actually resolve and stream.

## The Mission
Take ownership of the networking and bypass layer. You have full creative freedom:
1. Overhaul and streamline the current stack into an effortless Linux-native experience, OR
2. Introduce and benchmark modern all-in-one tools and protocols that can supersede the existing setup entirely.

## What Success Looks Like
- **Effortless UX:** Instant switching between configs or strategies without digging into system paths or wrestling with manual commands.
- **Automated Healthchecks:** A fast, automated way to test target domains from a general list (YouTube, Discord, blocked sites) to verify what actually works.
- **Resilient & Relevant:** Proven effectiveness against current Russian TSPU/DPI blocks, with predictable and configurable DNS.
- **Clean Architecture:** Aligns with the repository's unprivileged GNU Stow structure (`modules/`), Fish shell, and Niri Wayland environment.

Propose your vision, explore the best modern options, and outline a concrete solution.
