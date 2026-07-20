# Инструкция по восстановлению окружения на новом ПК

Скопируй текст ниже и отправь его агенту на новой системе, чтобы полностью восстановить все настройки, симлинки и бэкапы:

```markdown
Я на новом ПК и хочу полностью восстановить свою базу знаний, системные настройки и бэкапы.

Действуй автономно с помощью инструментов run_command и write_to_file везде, где это возможно. Сделай следующее:

1. Установка: Проверь наличие git и github-cli (gh) в системе. Если чего-то нет, определи мою ОС и установи их. ВАЖНО: для установки используй графический запрос пароля через pkexec (например, `pkexec pacman -S ...`), чтобы не заблокировать терминал в фоне.
2. Авторизация GitHub и Клонирование: 
   - Выведи мне инструкцию запустить `gh auth login` в терминале для авторизации в GitHub. После этого приостанови выполнение и жди моего подтверждения "Готово".
   - После подтверждения, автоматически склонируй мой приватный репозиторий дотфайлов: `git clone https://github.com/trazxdxne/dotfiles.git ~/dotfiles`.
3. Восстановление и Симлинки:
    - Создай необходимые системные директории: `~/.config/niri`, `~/.config/niri-autostart`, `~/.config/fuzzel`, `~/.config/gtk-3.0`, `~/.config/gtk-4.0`, `~/.agents/skills`, `~/.gemini/antigravity-cli/knowledge/`, `~/.config/swappy`, `~/.local/bin`, `~/.config/qt5ct/colors`, `~/.config/qt6ct/colors`, `~/.config/hypr`, `~/.config/uwsm`.
    - Создай симлинки из `~/dotfiles` в систему:
      • `~/.config/niri/config.kdl` -> `~/dotfiles/niri/config.kdl`
      • `~/.config/niri-autostart/config.kdl` -> `~/dotfiles/niri-autostart/config.kdl`
      • `~/.config/ags` -> `~/dotfiles/ags`
      • `~/.config/systemd/user/ags.service` -> `~/dotfiles/ags/ags.service`
      • `~/.config/fuzzel/fuzzel.ini` -> `~/dotfiles/fuzzel/fuzzel.ini`
      • `~/.wezterm.lua` -> `~/dotfiles/wezterm/wezterm.lua`
      • `~/.config/gtk-3.0/settings.ini` -> `~/dotfiles/gtk-3.0/settings.ini`
      • `~/.config/gtk-3.0/gtk.css` -> `~/dotfiles/gtk-3.0/gtk.css`
      • `~/.config/gtk-4.0/settings.ini` -> `~/dotfiles/gtk-4.0/settings.ini`
      • `~/.config/gtk-4.0/gtk.css` -> `~/dotfiles/gtk-4.0/gtk.css`
      • `~/.config/gtk-4.0/libadwaita.css` -> `~/.themes/Velvet-Night/gtk-4.0/libadwaita.css`
      • `~/.config/gtk-4.0/libadwaita-tweaks.css` -> `~/.themes/Velvet-Night/gtk-4.0/libadwaita-tweaks.css`
      • `~/.config/gtk-4.0/assets` -> `~/.themes/Velvet-Night/gtk-4.0/assets`
      • `~/.config/qt5ct/colors/Velvet-Night.conf` -> `~/dotfiles/qt5ct/colors/Velvet-Night.conf`
      • `~/.config/qt6ct/colors/Velvet-Night.conf` -> `~/dotfiles/qt6ct/colors/Velvet-Night.conf`
      • `~/.themes/Velvet-Night` -> `~/dotfiles/.themes/Velvet-Night`
      • `~/.config/wireplumber/wireplumber.conf.d` -> `~/dotfiles/wireplumber/wireplumber.conf.d`
      • `~/.config/quickshell` -> `~/dotfiles/quickshell`
      • `~/.agents/AGENTS.md` -> `~/dotfiles/AGENTS.md`
      • `~/.gemini/antigravity-cli/knowledge/Environment_Setup.md` -> `~/dotfiles/knowledge/Environment_Setup.md`
      • `~/.gemini/antigravity-cli/knowledge/Clipboard_Guide.md` -> `~/dotfiles/knowledge/Clipboard_Guide.md`
      • `~/.gemini/antigravity-cli/knowledge/Equicord_Setup_Guide.md` -> `~/dotfiles/knowledge/Equicord_Setup_Guide.md`
      • `~/.config/swappy/config` -> `~/dotfiles/swappy/config`
      • `~/.local/bin/screenshot` -> `~/dotfiles/scripts/screenshot`
      • `~/.config/hypr/hyprlock.conf` -> `~/dotfiles/hypr/hyprlock.conf`
      • `~/.config/hypr/hyprland.lua` -> `~/dotfiles/hypr/hyprland.lua`
      • `~/.config/topgrade.toml` -> `~/dotfiles/topgrade/topgrade.toml`
      • `~/.config/fish/config.fish` -> `~/dotfiles/fish/config.fish`
      • `~/.bashrc` -> `~/dotfiles/bash/.bashrc`
      • `~/.config/micro` -> `~/dotfiles/micro`
      • `~/.agents/skills/review` -> `~/dotfiles/.agents/skills/review`
      • `~/.agents/skills/qt-qml` -> `~/dotfiles/.agents/skills/qt-qml`
      • `~/.agents/skills/qt-qml-docs` -> `~/dotfiles/.agents/skills/qt-qml-docs`
      • `~/.agents/skills/arch-linux-triage` -> `~/dotfiles/.agents/skills/arch-linux-triage`
      • `~/.agents/skills/baby` -> `~/dotfiles/.agents/skills/baby`
      • `~/.agents/skills/obsidian-task-organizer` -> `~/dotfiles/.agents/skills/obsidian-task-organizer`
      • `~/.config/uwsm/env` -> `~/dotfiles/uwsm/env`
      • `~/.config/fish/functions/fastfetch.fish` -> `~/dotfiles/fish/functions/fastfetch.fish`
      • `~/.config/fish/functions/dotpush.fish` -> `~/dotfiles/fish/functions/dotpush.fish`
      • `~/.config/fastfetch/config.jsonc` -> `~/dotfiles/fastfetch/config.jsonc`
      • `~/.config/fastfetch/config.jsonc.template` -> `~/dotfiles/fastfetch/config.jsonc.template`
      • `~/obsidian-livesync/docker-compose.yml` -> `~/dotfiles/obsidian-livesync/docker-compose.yml`
      • `~/obsidian-livesync/local.d` -> `~/dotfiles/obsidian-livesync/local.d`
   - Скопируй системные конфигурации и файлы тем (потребуется pkexec):
     • `pkexec cp ~/dotfiles/modprobe.d/disable-hda.conf /etc/modprobe.d/disable-hda.conf`
     • `pkexec cp ~/dotfiles/noctalia-greeter/config.toml /etc/greetd/config.toml`
     • `pkexec cp -r ~/.themes/Velvet-Night /usr/share/themes/Velvet-Night`
     • `pkexec cp ~/dotfiles/polkit-1/10-power.rules /etc/polkit-1/rules.d/10-power.rules`
     • `pkexec cp ~/dotfiles/polkit-1/20-noctalia-greeter.rules /etc/polkit-1/rules.d/20-noctalia-greeter.rules`
     • `pkexec cp ~/dotfiles/polkit-1/org.freedesktop.Flatpak.rules /etc/polkit-1/rules.d/org.freedesktop.Flatpak.rules`
     • `pkexec mkdir -p /usr/lib/firmware/edid && pkexec cp ~/dotfiles/edid/combined.bin /usr/lib/firmware/edid/combined.bin`
     • `pkexec cp ~/dotfiles/tailscale/99-tailscale.conf /etc/sysctl.d/99-tailscale.conf`
    - Настрой системные службы для Noctalia Greeter (потребуется pkexec):
      • `pkexec systemctl disable ly`
      • `pkexec systemctl disable getty@tty1.service`
      • `pkexec systemctl enable greetd`
    - Установи и включи Docker и Tailscale:
      • `pkexec pacman -S docker docker-compose tailscale`
      • `pkexec systemctl enable --now docker tailscaled`
      • `pkexec usermod -aG docker $USER` (перелогиниться после)
    - Авторизуйся в Tailscale: `sudo tailscale up` (одноразово, при первом подключении)
    - Создай `~/obsidian-livesync/.env` по образцу `~/dotfiles/obsidian-livesync/.env.example`
    - `docker compose -f ~/obsidian-livesync/docker-compose.yml up -d`
    - Инициализируй CouchDB (curl-команды из Environment_Setup.md, секция 14)
    - `tailscale serve --bg http://127.0.0.1:5984` (персистентно, переживает перезагрузки)
    - `pkexec sysctl --system` (применить forwarding)
    - `tailscale set --advertise-exit-node`
4. Напиши мне красивый отчет, когда всё будет готово!
```
ln -s ~/dotfiles/noctalia/settings.toml ~/.local/state/noctalia/settings.toml
ln -s ~/dotfiles/noctalia/patches/telegram.tdesktop-theme ~/.local/state/noctalia/community-templates/telegram/telegram.tdesktop-theme
ln -s ~/dotfiles/noctalia/custom-templates/micro ~/.local/state/noctalia/community-templates/micro
ln -sf ~/dotfiles/noctalia/patches/obsidian-apply.sh ~/.local/state/noctalia/community-templates/obsidian/apply.sh
