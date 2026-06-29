# Инструкция по восстановлению окружения на новом ПК

Скопируй текст ниже и отправь его агенту на новой системе, чтобы полностью восстановить все настройки, симлинки и бэкапы:

```markdown
Я на новом ПК и хочу полностью восстановить свою базу знаний, системные настройки и бэкапы.

Действуй автономно с помощью инструментов run_command и write_to_file везде, где это возможно. Сделай следующее:

1. Установка: Проверь наличие git, github-cli (gh) и rclone в системе. Если чего-то нет, определи мою ОС и установи их. ВАЖНО: для установки используй графический запрос пароля через pkexec (например, `pkexec pacman -S ...`), чтобы не заблокировать терминал в фоне.
2. Авторизация GitHub и Клонирование: 
   - Выведи мне инструкцию запустить `gh auth login` в терминале для авторизации в GitHub. После этого приостанови выполнение и жди моего подтверждения "Готово".
   - После подтверждения, автоматически склонируй мой приватный репозиторий дотфайлов: `git clone https://github.com/trazxdxne/dotfiles.git ~/dotfiles`.
3. Авторизация Google Drive: Выведи мне пошаговую инструкцию запустить `rclone config` в отдельном терминале (название remote должно быть `gdrive`). Client ID и Client Secret оставь пустыми, проигнорируй сообщение про low performance. Приостанови выполнение и жди моего подтверждения "Готово".
4. Восстановление и Симлинки:
   - Создай необходимые системные директории: `~/.config/niri`, `~/.config/fuzzel`, `~/.config/gtk-3.0`, `~/.config/gtk-4.0`, `~/.agents`, `~/.gemini/antigravity-cli/knowledge/`.
   - Создай симлинки из `~/dotfiles` в систему:
     • `~/.config/niri/config.kdl` -> `~/dotfiles/niri/config.kdl`
     • `~/.config/ags` -> `~/dotfiles/ags`
     • `~/.config/fuzzel/fuzzel.ini` -> `~/dotfiles/fuzzel/fuzzel.ini`
     • `~/.wezterm.lua` -> `~/dotfiles/wezterm/wezterm.lua`
     • `~/.config/gtk-3.0/settings.ini` -> `~/dotfiles/gtk-3.0/settings.ini`
     • `~/.config/gtk-4.0/settings.ini` -> `~/dotfiles/gtk-4.0/settings.ini`
     • `~/.config/wireplumber/wireplumber.conf.d` -> `~/dotfiles/wireplumber/wireplumber.conf.d`
     • `~/.agents/AGENTS.md` -> `~/dotfiles/AGENTS.md`
     • `~/.gemini/antigravity-cli/knowledge/Environment_Setup.md` -> `~/dotfiles/knowledge/Environment_Setup.md`
     • `~/.gemini/antigravity-cli/knowledge/Equicord_Setup_Guide.md` -> `~/dotfiles/knowledge/Equicord_Setup_Guide.md`
   - Отключи встроенный звук, скопировав конфигурационный файл modprobe (потребуется pkexec):
     • `pkexec cp ~/dotfiles/modprobe.d/disable-hda.conf /etc/modprobe.d/disable-hda.conf`
   - Скачай файлы бэкапа с Google Drive:
     • `rclone copy gdrive:Antigravity/Knowledge/ ~/.gemini/antigravity-cli/knowledge/ --copy-links`
     • `rclone copy gdrive:Antigravity/Skills/AAA-CRITICAL-KNOWLEDGE-CHECK/ ~/.agents/skills/AAA-CRITICAL-KNOWLEDGE-CHECK/ --copy-links`
     • `rclone copy gdrive:Antigravity/Skills/baby/ ~/.agents/skills/baby/ --copy-links`
5. Права доступа и логирование: Сделай скрипт бэкапа исполняемым: `chmod +x ~/.gemini/antigravity-cli/knowledge/backup_to_gdrive.sh`.
6. Планировщик: Настрой ежедневный бэкап с помощью пользовательского systemd таймера. Создай файлы:
   - `~/.config/systemd/user/backup-gdrive.service` (запуск скрипта бэкапа с `Type=oneshot`, StandardOutput/StandardError направь в `~/.gemini/antigravity-cli/knowledge/backup_gdrive.log`).
   - `~/.config/systemd/user/backup-gdrive.timer` (настрой `OnCalendar=*-*-* 22:00:00` и `Persistent=true`).
   Выполни `systemctl --user daemon-reload`, `systemctl --user enable --now backup-gdrive.timer` и `systemctl --user start backup-gdrive.service`.
7. Напиши мне красивый отчет, когда всё будет готово!
```
