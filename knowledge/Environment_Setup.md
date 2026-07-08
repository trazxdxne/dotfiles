# Настройка окружения: Инструкции и рецепты

Практическое руководство по быстрой настройке звука, редактора, тем оформления, раскладки клавиатуры и терминала. Все настройки ориентированы на Wayland-композитор Niri и интегрированы с репозиторием [dotfiles](file:///home/trazxdxne/dotfiles).

---

## 📌 Содержание

1. [Как быстро восстановить окружение из дотфайлов](#1-как-быстро-восстановить-окружение-из-дотфайлов)
2. [Как настроить безопасное редактирование системных файлов через sudoedit](#2-как-настроить-безопасное-редактирование-системных-файлов-через-sudoedit)
3. [Как применить темную тему Velvet Night](#3-как-применить-темную-тему-velvet-night)
4. [Как синхронизировать тему и размер курсора во всех приложениях](#4-как-синхронизировать-тему-и-размер-курсора-во-всех-приложениях)
5. [Как настроить границы окон, отступы и автозапуск в Niri](#5-как-настроить-границы-окон-отступы-и-автозапуск-в-niri)
6. [Как настроить Discord без вылетов под NVIDIA и с обходом блокировок](#6-как-настроить-discord-без-вылетов-под-nvidia-и-с-обходом-блокировок)
7. [Как починить сброс громкости USB-гарнитуры и настроить объемный звук 7.1](#7-как-починить-сброс-громкости-usb-гарнитуры-и-настроить-объемный-звук-71)
8. [Как активировать русскую типографскую раскладку клавиатуры](#8-как-активировать-русскую-типографскую-раскладку-клавиатуры)
9. [Как настроить WezTerm для плавной работы под Wayland и русских шорткатов](#9-как-настроить-wezterm-для-плавной-работы-под-wayland-и-русских-шорткатов)
10. [Как настроить дисплейный менеджер (greetd + regreet) и автоблокировку сессии (hyprlock)](#10-как-настроить-дисплейный-менеджер-greetd-regreet-и-автоблокировку-сессии-hyprlock)

---

## 1. Как быстро восстановить окружение из дотфайлов

Для переноса настроек и развертывания рабочей среды на новой системе используйте пошаговый сценарий из инструкции:
* [Restore_Prompt.md](file:///home/trazxdxne/dotfiles/knowledge/Restore_Prompt.md)

Сценарий автоматизирует установку необходимых утилит (git, gh, rclone), создание структуры папок в домашней директории, создание символических ссылок и конфигурацию резервного копирования.

---

## 2. Как настроить безопасное редактирование системных файлов через sudoedit

Для безопасной правки конфигурационных файлов в `/etc` от имени суперпользователя используйте `sudoedit` в связке с редактором **Zed**. Это исключает запуск графического приложения с root-привилегиями.

### Шаг 1. Настройка скрипта ожидания
Создайте скрипт, который заставит терминал ждать закрытия файла в Zed:
```bash
mkdir -p ~/.local/bin
echo -e '#!/bin/sh\nexec zed --wait "$@"' > ~/.local/bin/zed-wait
chmod +x ~/.local/bin/zed-wait
```

### Шаг 2. Добавление функции-интеграции
Добавьте вызов `sudoedit` при попытке редактировать защищенный файл.

#### Для Fish-оболочки (создайте файл `~/.config/fish/functions/zed.fish`):
```fish
function zed
    if test -n "$argv[1]"; and test -f $argv[1]; and not test -w $argv[1]
        env SUDO_EDITOR=$HOME/.local/bin/zed-wait sudoedit $argv
    else
        command zed $argv
    end
end
```

#### Для Bash / Zsh (добавьте в `~/.bashrc` или `~/.zshrc`):
```bash
zed() {
    if [ -n "$1" ] && [ -f "$1" ] && [ ! -w "$1" ]; then
        SUDO_EDITOR="$HOME/.local/bin/zed-wait" sudoedit "$@"
    else
        command zed "$@"
    fi
}
```

Теперь команда `zed /etc/hosts` автоматически сработает через `sudoedit`.

---

## 3. Как применить темную тему Velvet Night

Настройка сквозного оформления с единой палитрой Velvet Night для всех типов интерфейсов (GTK3, GTK4/Libadwaita, Qt5/Qt6).

### Шаг 1. Установка необходимых пакетов
```bash
yay -S catppuccin-gtk-theme-mocha && sudo pacman -S qt6ct qt5ct
```

### Шаг 2. Конфигурация GTK3
Пропишите название темы в файле настроек [gtk-3.0/settings.ini](file:///home/trazxdxne/dotfiles/gtk-3.0/settings.ini):
```ini
[Settings]
gtk-theme-name=Velvet-Night
gtk-application-prefer-dark-theme=1
gtk-font-name=Adwaita Sans 11
```
### Шаг 3. Конфигурация GTK4 (Libadwaita)
Для корректного применения стиля в современных GNOME-приложениях (например, Nautilus) свяжите стили темы с директорией GTK4:
```bash
mkdir -p ~/.config/gtk-4.0
ln -sf /usr/share/themes/yay -S adw-gtk-theme
# The custom colors are configured in ~/.config/gtk-4.0/gtk.css and ~/.config/gtk-3.0/gtk.css

## GTK Settings
[~/.config/gtk-3.0/settings.ini]
[Settings]
gtk-theme-name=adw-gtk3-dark
gtk-application-prefer-dark-theme=1
gtk-font-name=Adwaita Sans 11
gtk-cursor-theme-name=ArchCursorComplete
gtk-cursor-theme-size=20

[~/.config/gtk-4.0/settings.ini]
[Settings]
gtk-application-prefer-dark-theme=1
gtk-cursor-theme-name=ArchCursorComplete
gtk-cursor-theme-size=20

### Applying GTK configuration
gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface font-name 'Adwaita Sans 11'
```

### Шаг 5. Конфигурация Qt5 и Qt6
1. Укажите Niri использовать `qt5ct` в качестве бэкенда тем. В файле [niri/config.kdl](file:///home/trazxdxne/dotfiles/niri/config.kdl) добавьте:
   ```kdl
   environment {
       QT_QPA_PLATFORMTHEME "qt5ct"
   }
   ```
2. Создайте файл палитры `~/.config/qt6ct/colors/Velvet-Night.conf` (и продублируйте его для `qt5ct` по пути `~/.config/qt5ct/colors/Velvet-Night.conf`):
   ```ini
   [ColorScheme]
   active_colors=#ffcdd6f4, #ff313244, #ff45475a, #ff585b70, #ff11111b, #ff181825, #ffcdd6f4, #fff5c2e7, #ffcdd6f4, #ff1e1e2e, #ff1e1e2e, #ff11111b, #fff5c2e7, #ff11111b, #ff89b4fa, #ffcba6f7, #ff181825, #00000000, #ff1e1e2e, #ffcdd6f4, #ff6c7086
   disabled_colors=#ff585b70, #ff313244, #ff45475a, #ff585b70, #ff11111b, #ff181825, #ff585b70, #fff5c2e7, #ff585b70, #ff1e1e2e, #ff1e1e2e, #ff11111b, #ff45475a, #ff11111b, #ff89b4fa, #ffcba6f7, #ff181825, #00000000, #ff1e1e2e, #ff585b70, #ff6c7086
   inactive_colors=#ffcdd6f4, #ff313244, #ff45475a, #ff585b70, #ff11111b, #ff181825, #ffcdd6f4, #fff5c2e7, #ffcdd6f4, #ff1e1e2e, #ff1e1e2e, #ff11111b, #fff5c2e7, #ff11111b, #ff89b4fa, #ffcba6f7, #ff181825, #00000000, #ff1e1e2e, #ffcdd6f4, #ff6c7086
   ```
3. Примените созданные схемы в конфигурационных файлах `~/.config/qt6ct/qt6ct.conf` и `~/.config/qt5ct/qt5ct.conf`:
   ```ini
   [Appearance]
   color_scheme_path=/home/trazxdxne/.config/qt6ct/colors/Velvet-Night.conf
   custom_palette=true
   style=Fusion
   ```

---

## 4. Как синхронизировать тему и размер курсора во всех приложениях

Для устранения скачков размера и сброса темы курсора при наведении на разные окна (Wayland, XWayland, Steam, Flatpak) необходимо настроить параметры в нескольких местах.

### Вариант А: Использование курсора Bibata Modern Classic
1. В файле [niri/config.kdl](file:///home/trazxdxne/dotfiles/niri/config.kdl) укажите параметры для самого композитора и экспортируйте переменные в окружение приложений:
   ```kdl
   cursor {
       xcursor-theme "Bibata-Modern-Classic"
       xcursor-size 20
   }

   environment {
       XCURSOR_THEME "Bibata-Modern-Classic"
       XCURSOR_SIZE "20"
   }
   ```
2. Обновите тему в конфигах GTK [gtk-3.0/settings.ini](file:///home/trazxdxne/dotfiles/gtk-3.0/settings.ini) и [gtk-4.0/settings.ini](file:///home/trazxdxne/dotfiles/gtk-4.0/settings.ini):
   ```ini
   gtk-cursor-theme-name=Bibata-Modern-Classic
   gtk-cursor-theme-size=20
   ```
3. Синхронизируйте через GSettings:
   ```bash
   gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Classic'
   gsettings set org.gnome.desktop.interface cursor-size 20
   ```
4. Исправьте отображение в Steam и X11-приложениях через конфигурационный файл `~/.icons/default/index.theme`:
   ```ini
   [Icon Theme]
   Inherits=Bibata-Modern-Classic
   ```

### Вариант Б: Использование темы ArchCursorComplete
Если вы хотите установить и использовать тему курсора Arch:
1. Склонируйте репозиторий темы:
   ```bash
   git clone https://github.com/aleksator/arch-cursor-complete.git ~/Projects/arch-cursor-complete
   ```
2. Скопируйте файлы темы:
   ```bash
   mkdir -p ~/.icons
   cp -r ~/Projects/arch-cursor-complete/ArchCursorComplete ~/.icons/
   ```
3. Укажите тему `ArchCursorComplete` в настройках [niri/config.kdl](file:///home/trazxdxne/dotfiles/niri/config.kdl) в блоках `cursor` и `environment`.
4. Обновите наследование в файле `~/.icons/default/index.theme`:
   ```ini
   [Icon Theme]
   Inherits=ArchCursorComplete
   ```

---

## 5. Как настроить границы окон, отступы и автозапуск в Niri

### Шаг 1. Отключение клиентского декорирования (CSD) и исправление углов
Чтобы избежать конфликтов с закруглениями окон приложений и убрать просвечивающие цветные пятна фокус-ринга по углам, добавьте в [niri/config.kdl](file:///home/trazxdxne/dotfiles/niri/config.kdl):
```kdl
prefer-no-csd

window-rule {
    geometry-corner-radius 0
    clip-to-geometry true
    draw-border-with-background false
}
```

### Шаг 2. Настройка рамок окон и внешних отступов экрана
Настройте ширину и розовый цвет рамки активного окна, а также внешние отступы `struts` в секции `layout` файла [niri/config.kdl](file:///home/trazxdxne/dotfiles/niri/config.kdl):
```kdl
layout {
    gaps 8
    struts {
        left 0
        right 0
        top 0
        bottom 0
    }
    focus-ring {
        width 1
        active-color "#f5c2e7"
        inactive-color "#45475a"
    }
}
```

### Шаг 3. Настройка запуска базовых системных демонов
Убедитесь, что Niri запускает агент авторизации Polkit и менеджер ключей на старте. Добавьте в [niri/config.kdl](file:///home/trazxdxne/dotfiles/niri/config.kdl):
```kdl
spawn-at-startup "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
spawn-at-startup "gnome-keyring-daemon" "--start" "--components=secrets"
```

### Шаг 4. Настройка лаунчера приложений Fuzzel
Для идеального соответствия теме настройте файл конфигурации лаунчера [fuzzel/fuzzel.ini](file:///home/trazxdxne/dotfiles/fuzzel/fuzzel.ini):
```ini
[main]
font=monospace:size=12
prompt="❯ "
terminal=wezterm

[colors]
background=1e1e2edd
text=cdd6f4ff
match=f5c2e7ff
selection=f5c2e7ff
selection-text=11111bff
selection-match=cba6f7ff
border=f5c2e7ff

[border]
width=1
radius=0
```

---

## 6. Как настроить Discord без вылетов под NVIDIA и с обходом блокировок

Для стабильной работы Discord (Equicord/Vesktop) в Wayland-окружении на видеокартах NVIDIA рекомендуется запускать его принудительно через XWayland, а для обхода блокировок голосовых каналов использовать библиотеку `discord-linux-bypass`.

### Шаг 1. Настройка XWayland в Niri
1. Установите прослойку XWayland:
   ```bash
   sudo pacman -S xwayland-satellite
   ```
2. Экспортируйте переменную `DISPLAY` при старте Niri в файле [niri/config.kdl](file:///home/trazxdxne/dotfiles/niri/config.kdl):
   ```kdl
   spawn-at-startup "dbus-update-activation-environment" "--systemd" "DISPLAY" "WAYLAND_DISPLAY" "XAUTHORITY"
   ```

### Шаг 2. Сборка discord-linux-bypass
Склонируйте и скомпилируйте библиотеку для обхода ТСПУ/DPI:
```bash
git clone https://codeberg.org/nik9/discord-linux-bypass.git ~/Projects/discord-linux-bypass
cd ~/Projects/discord-linux-bypass
make
```

### Шаг 3. Создание скрипта запуска
Создайте скрипт `~/Projects/discord-linux-bypass/discord_run.sh`:
```bash
#!/usr/bin/env bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_PATH="$DIR/libdiscordbypass.so"
CONFIG_PATH="$DIR/config.env"

if [ -f "$CONFIG_PATH" ]; then
    source "$CONFIG_PATH"
fi

if [ -z "$PORT" ]; then
    PORT=9050
    echo "PORT=$PORT" > "$CONFIG_PATH"
fi

export BYPASS_DELAY=50
export BYPASS_FAKE_PACKETS=2
export LD_PRELOAD="$LIB_PATH"

proxy_server="--proxy-server=socks5://127.0.0.1:$PORT"

if command -v vesktop &> /dev/null; then
    exec vesktop $proxy_server "$@"
elif command -v discord &> /dev/null; then
    exec discord $proxy_server "$@"
fi
```
Сделайте его исполняемым: `chmod +x ~/Projects/discord-linux-bypass/discord_run.sh`.

### Шаг 4. Настройка SOCKS5-порта, ярлыка и автозапуска
1. Укажите порт локального прокси в файле `~/Projects/discord-linux-bypass/config.env`:
   ```env
   PORT=9050
   ```
2. Скопируйте и отредактируйте ярлык запуска `~/.local/share/applications/discord.desktop`, заменив строку выполнения:
   ```ini
   Exec=/home/trazxdxne/Projects/discord-linux-bypass/discord_run.sh --url -- %u
   ```
3. Если вы используете автозапуск в Niri, обновите команду запуска Discord в файле [niri-autostart/config.kdl](file:///home/trazxdxne/dotfiles/niri-autostart/config.kdl), указав полный путь к скрипту обхода:
   ```kdl
   window app-id="discord" {
       command "/home/trazxdxne/Projects/discord-linux-bypass/discord_run.sh"
       height { proportion 1.0; }
   }
   ```

---

## 7. Как починить сброс громкости USB-гарнитуры и настроить объемный звук 7.1

При использовании внешних USB-гарнитур часто возникают проблемы: сброс громкости на 100% при перезагрузке, отключение звука при простое устройства и неверный баланс каналов.

### Шаг 1. Системное отключение встроенного звука (PCI/HDMI)
Чтобы исключить конфликты устройств в alsamixer, заблокируйте встроенный аудиомодуль Intel.
Создайте системный файл конфигурации [modprobe.d/disable-hda.conf](file:///home/trazxdxne/dotfiles/modprobe.d/disable-hda.conf) (требуются root-права):
```ini
blacklist snd_hda_intel
```
*(Для применения настроек перезагрузите систему).*

### Шаг 2. Предотвращение автосна USB-аудио и сброса громкости
Создайте правила WirePlumber в директории репозитория [wireplumber/wireplumber.conf.d/](file:///home/trazxdxne/dotfiles/wireplumber/wireplumber.conf.d/):

1. **Отключение программного микшера (использование аппаратного)** в [50-audio-rules.conf](file:///home/trazxdxne/dotfiles/wireplumber/wireplumber.conf.d/50-audio-rules.conf):
   ```conf
   monitor.alsa.rules = [
     {
       matches = [ { device.name = "~alsa_card.usb-.*" } ]
       actions = { update-props = { api.alsa.soft-mixer = false } }
     }
   ]
   ```
2. **Отключение приостановки (suspend/idle) для USB-устройств** в [51-usb-volume-fix.conf](file:///home/trazxdxne/dotfiles/wireplumber/wireplumber.conf.d/51-usb-volume-fix.conf):
   ```conf
   monitor.alsa.rules = [
     {
       matches = [ { node.name = "~alsa_output.usb-.*" } ]
       actions = { update-props = { node.pause-on-idle = false, session.suspend-timeout-seconds = 0 } }
     }
   ]
   ```
3. **Фиксация начальной громкости на безопасном уровне** в [99-force-volume.conf](file:///home/trazxdxne/dotfiles/wireplumber/wireplumber.conf.d/99-force-volume.conf):
   ```conf
   wireplumber.settings = {
     node.stream.default-playback-volume = 0.2
   }
   ```

### Шаг 3. Автоматическое восстановление баланса гарнитуры при старте
Если левый и правый каналы гарнитуры сбрасываются до разных уровней, настройте автовосстановление:
1. Найдите точное имя вашего аудиовыхода в PipeWire:
   ```bash
   pactl list sinks | grep Name
   ```
   *(Например: `alsa_output.usb-3142_fifine_Headset-00.analog-stereo`)*
2. Создайте пользовательскую службу systemd `~/.config/systemd/user/alsa-volume-restore.service`:
   ```ini
   [Unit]
   Description=Restore PipeWire USB volume and balance
   After=wireplumber.service pipewire.service
   Requires=wireplumber.service

   [Service]
   Type=oneshot
   ExecStartPre=/bin/sleep 2
   ExecStart=/usr/bin/pactl set-sink-volume alsa_output.usb-3142_fifine_Headset-00.analog-stereo 54741 65536
   RemainAfterExit=yes

   [Install]
   WantedBy=default.target
   ```
3. Активируйте службу:
   ```bash
   systemctl --user daemon-reload
   systemctl --user enable --now alsa-volume-restore.service
   ```

### Шаг 4. Настройка EasyEffects (HeSuVi 7.1 Virtual Surround)
Чтобы избежать бесконечной петли звука при выводе 7.1 через EasyEffects:
1. В конфигурации filter chain PipeWire (`~/.config/pipewire/pipewire.conf.d/99-virtual-surround.conf`) направьте вывод в EasyEffects:
   ```conf
   playback.props = {
       target.object = "easyeffects_sink"
   }
   ```
2. В интерфейсе EasyEffects:
   * На вкладке **Players**: снимите галочку с **Process All Outputs** (или снимите её с конкретных игр, которые выводят многоканальный звук напрямую в Virtual Surround Sink).
   * На вкладке **PipeWire**: принудительно переключите **Output Device** с *Default* на вашу физическую USB-гарнитуру (разорвет петлю обратной связи).

---

## 8. Как активировать русскую типографскую раскладку клавиатуры

Настройка переключения языков по Caps Lock, включение правого Alt в качестве переключателя 3-го уровня (для ввода символов « » — — и т.д.).

### В среде Niri
Настройка выполняется прямо в файле [niri/config.kdl](file:///home/trazxdxne/dotfiles/niri/config.kdl) в секции `input`:
```kdl
input {
    keyboard {
        xkb {
            layout "us,ru"
            options "grp:caps_toggle,lv3:ralt_switch,misc:typo"
        }
    }
}
```

### В других средах (для справки)
* **Hyprland** (`hyprland.conf`): `kb_options = grp:caps_toggle,lv3:ralt_switch,misc:typo`
* **Sway** (`config`): `xkb_options grp:caps_toggle,lv3:ralt_switch,misc:typo`
* **GNOME** (в терминале):
  ```bash
  gsettings set org.gnome.desktop.input-sources xkb-options "['grp:caps_toggle', 'lv3:ralt_switch', 'misc:typo']"
  ```

---

## 9. Как настроить WezTerm для плавной работы под Wayland и русских шорткатов

Устранение задержек запуска WezTerm на связке Wayland + NVIDIA и настройка копирования/вставки в русской раскладке.

### Шаг 1. Исправление медленного запуска (зависаний OpenGL)
На видеокартах NVIDIA под Wayland нативный OpenGL-рендерер WezTerm может медленно открывать новые окна. Чтобы исправить это, настройте шорткат запуска в [niri/config.kdl](file:///home/trazxdxne/dotfiles/niri/config.kdl) с флагами `--always-new-process`:
```kdl
Mod+Return { spawn "wezterm" "start" "--always-new-process"; }
```

### Шаг 2. Настройка темы, цветовой палитры и горячих клавиш
Настройте файл конфигурации терминала [wezterm/wezterm.lua](file:///home/trazxdxne/dotfiles/wezterm/wezterm.lua):

1. **Цветовая схема Velvet Night** с переопределением ANSI-палитры (для лучшей читаемости в alsamixer/TUI):
   ```lua
   config.colors = {
     background = '#1e1e2e',
     foreground = '#cdd6f4',
     cursor_bg = '#f5e0dc',
     cursor_fg = '#1e1e2e',
     cursor_border = '#f5e0dc',
     selection_bg = '#585b70',
     selection_fg = '#cdd6f4',
     ansi = {
       '#1e1e2e', -- 0 black
       '#f38ba8', -- 1 red (высокая нагрузка)
       '#cba6f7', -- 2 green -> mauve (низкая нагрузка / бары в alsamixer)
       '#fab387', -- 3 yellow -> peach (средняя нагрузка)
       '#89b4fa', -- 4 blue
       '#f5c2e7', -- 5 magenta -> pink
       '#f5e0dc', -- 6 cyan -> rosewater (текст в alsamixer)
       '#45475a', -- 7 white -> dark grey (выделение фона)
     },
     brights = {
       '#585b70', '#f38ba8', '#cba6f7', '#fab387',
       '#89b4fa', '#f5c2e7', '#f5e0dc', '#585b70',
     }
   }
   ```
2. **Кириллические горячие клавиши**:
   Чтобы Ctrl+C и Ctrl+V работали в русской раскладке, добавьте в секцию клавиш:
   ```lua
   local act = wezterm.action
   config.keys = {
       -- Вставка на обеих раскладках (Ctrl+V / Ctrl+М)
       { key = 'v', mods = 'CTRL', action = act.PasteFrom('Clipboard') },
       { key = 'м', mods = 'CTRL', action = act.PasteFrom('Clipboard') },

       -- Копирование на обеих раскладках (Ctrl+C / Ctrl+С)
       { key = 'c', mods = 'CTRL', action = act.CopyTo('Clipboard') },
       { key = 'с', mods = 'CTRL', action = act.CopyTo('Clipboard') },

       -- Сигнал прерывания SIGINT (Ctrl+Shift+C / Ctrl+Shift+С)
       { key = 'C', mods = 'CTRL|SHIFT', action = act.SendKey{ key='c', mods='CTRL' } },
       { key = 'С', mods = 'CTRL|SHIFT', action = act.SendKey{ key='c', mods='CTRL' } },
   }
   ```

### Шаг 3. Настройка порогов нагрузки в Fastfetch
Поскольку зеленый цвет переназначен на пастельный Mauve для читаемости alsamixer, измените цветовые пороги в `~/.config/fastfetch/config.jsonc`, чтобы проценты нагрузки диска, оперативной памяти и Swap имели логичную палитру (Mauve -> Peach -> Red):
```jsonc
{
  "modules": [
    {
      "type": "memory",
      "percent": {
        "green": 35,
        "yellow": 75
      }
    },
    {
      "type": "swap",
      "percent": {
        "green": 10,
        "yellow": 40
      }
    },
    {
      "type": "disk",
      "percent": {
        "green": 70,
        "yellow": 90
      }
    }
  ]
}
```

---

## 10. Как настроить дисплейный менеджер (ly) и автоблокировку сессии (hyprlock)

Для обеспечения легкого графического входа при запуске системы и безопасной блокировки сессии при переходе в спящий режим используется связка `ly` (в качестве консольного TUI дисплейного менеджера) и `hyprlock` (в качестве блокировщика экрана).

### Шаг 1. Настройка ly
Ly — это легковесный консольный дисплейный менеджер. Его конфигурационный файл находится по пути `/etc/ly/config.ini`.
Убедитесь, что установлены пакеты `ly` и `kmscon`, затем отредактируйте конфиг с помощью привилегий суперпользователя. В нашей конфигурации мы применяем цвета из темы Velvet Night напрямую в виде hex-кодов (поддерживаются 24-битные цвета в формате `0xSSRRGGBB`):

> [!IMPORTANT]
> Обратите внимание: Обычная Linux-консоль не поддерживает 24-битные цвета (TrueColor). Поэтому Ly запускается через `kmscon` (с помощью шаблона `ly-kmsconvt@.service`), который эмулирует терминал с поддержкой TrueColor поверх фреймбуфера.

Включите службу `ly-kmsconvt` на нужном TTY (например, TTY2) и отключите старый дисплейный менеджер:
```bash
pkexec systemctl disable greetd
pkexec systemctl enable ly-kmsconvt@tty2.service
```

> [!TIP]
> **Скрытие пользователя root из Ly:**
> По умолчанию Ly отображает пользователя `root`, так как у него есть активная командная оболочка `/usr/bin/bash`. Чтобы убрать его с экрана авторизации (и сделать прямой вход под ним невозможным, сохранив при этом работу `sudo`), замените его оболочку на заглушку `nologin`:
> ```bash
> pkexec usermod -s /usr/bin/nologin root
> ```
> *Примечание: После этого команды вроде `su -` или `sudo su` работать перестанут. Для интерактивного входа от имени root используйте `sudo bash`.*

### Шаг 1.1. Настройка автоматического разблокирования GNOME Keyring
Чтобы при входе через `ly` автоматически разблокировалась связка ключей (GNOME Keyring), отредактируйте файл конфигурации PAM `/etc/pam.d/ly` (потребуются root-привилегии), добавив `pam_gnome_keyring.so`:
```pam
#%PAM-1.0

auth       required     pam_securetty.so
auth       requisite    pam_nologin.so
auth       include      system-local-login
auth       optional     pam_gnome_keyring.so

account    include      system-local-login

password   include      system-local-login
password   optional     pam_gnome_keyring.so use_authtok

session    include      system-local-login
session    optional     pam_gnome_keyring.so auto_start
```
Это позволит передавать пароль пользователя при входе в диспетчер ключей gnome-keyring-daemon.

### Шаг 2. Конфигурация hyprlock
Настройки блокировщика экрана находятся в файле `~/.config/hypr/hyprlock.conf` (который ссылается на `~/dotfiles/hypr/hyprlock.conf`). Основные параметры:
* `path = screenshot` и `blur_passes = 3` для размытия текущего изображения на экране.
* Отображение текущего времени через `$TIME` и раскладки клавиатуры через `$LAYOUT`.
* Применение шрифта `Adwaita Sans` для текстовых полей и заголовков.

Горячая клавиша для ручной блокировки экрана настраивается в файле `~/.config/niri/config.kdl`:
```kdl
Super+Alt+L hotkey-overlay-title="Lock the Screen" { spawn "hyprlock"; }
```

### Шаг 3. Автоматическая блокировка при переходе в спящий режим
Для вызова блокировки перед засыпанием компьютера создана пользовательская служба systemd `~/.config/systemd/user/lock-on-sleep.service` (ссылающаяся на `~/dotfiles/systemd/lock-on-sleep.service`):
```ini
[Unit]
Description=Lock screen before sleep listener
After=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/sh -c "dbus-monitor --system \"type='signal',interface='org.freedesktop.login1.Manager',member='PrepareForSleep'\" | while read -r line; do if echo \"$line\" | grep -q 'boolean true'; then /usr/bin/hyprlock; fi; done"
Restart=always

[Install]
WantedBy=default.target
```
Служба отслеживает сигнал `PrepareForSleep` от `systemd-logind` через шину D-Bus и вызывает `hyprlock` до начала процесса приостановки системы.

Активируйте и запустите службу для текущего пользователя:
```bash
systemctl --user daemon-reload
systemctl --user enable --now lock-on-sleep.service
```
