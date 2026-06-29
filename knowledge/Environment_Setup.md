# Настройка окружения

Звук, редактор, теминг, клавиатура и терминал — для любого DE/WM: **Niri, GNOME, Hyprland, Sway, i3, MangoWM, DriftWM**.

---

## 📌 Содержание

1. [Интеграция редактора с sudoedit](#1-интеграция-редактора-с-sudoedit)
2. [Внешний вид и теминг (Catppuccin Mocha Pink)](#2-внешний-вид-и-теминг-catppuccin-mocha-pink)
3. [Окружение Niri: Фиксы, рамки, игры и тонкая настройка](#3-окружение-niri-фиксы-рамки-игры-и-тонкая-настройка)
4. [Звук и автоматическое восстановление громкости](#4-звук-и-автоматическое-восстановление-громкости)
5. [Типографская раскладка клавиатуры](#5-типографская-раскладка-клавиатуры)
6. [Эмулятор терминала WezTerm (Тема и Кириллические шорткаты)](#6-эмулятор-терминала-wezterm-тема-и-кириллические-шорткаты)

---

## 1. Интеграция редактора с sudoedit

`sudoedit` — безопасный способ редактировать системные файлы от имени суперпользователя. При попытке открыть файл без прав записи функция-обёртка автоматически запустит `sudoedit`.

### Установка
В качестве редактора используется **Zed**. Если он не установлен:
```bash
sudo pacman -S zed
```

### Настройка
1. Создайте скрипт-обёртку для ожидания закрытия файла:
```bash
mkdir -p ~/.local/bin
echo -e '#!/bin/sh\nexec zed --wait "$@"' > ~/.local/bin/zed-wait
chmod +x ~/.local/bin/zed-wait
```

2. Добавьте функцию-интеграцию в вашу оболочку:

#### Fish (`~/.config/fish/functions/zed.fish`):
```fish
function zed
    if test -n "$argv[1]"; and test -f $argv[1]; and not test -w $argv[1]
        env SUDO_EDITOR=$HOME/.local/bin/zed-wait sudoedit $argv
    else
        command zed $argv
    end
end
```

#### Bash (`~/.bashrc`) / Zsh (`~/.zshrc`):
```bash
zed() {
    if [ -n "$1" ] && [ -f "$1" ] && [ ! -w "$1" ]; then
        SUDO_EDITOR="$HOME/.local/bin/zed-wait" sudoedit "$@"
    else
        command zed "$@"
    fi
}
```

### Проверка
Попробуйте открыть системный файл. Он должен открыться в Zed без ошибок доступа:
```bash
zed /etc/hosts
```

---

## 2. Внешний вид и теминг (Catppuccin Mocha Pink)

Настройка единого темного оформления с розовыми акцентами для GTK3, GTK4 (Libadwaita) и Qt6/Qt5 приложений.

### Установка тем и утилит
Установите тему Catppuccin Mocha для GTK и конфигураторы Qt:
```bash
yay -S catppuccin-gtk-theme-mocha && sudo pacman -S qt6ct qt5ct
```

### Настройка GTK3 и GTK4
1. Включите темную тему и установите шрифт интерфейса в GTK3 (`~/.config/gtk-3.0/settings.ini`):
```ini
[Settings]
gtk-theme-name=catppuccin-mocha-pink-standard+default
gtk-application-prefer-dark-theme=1
gtk-font-name=Adwaita Sans 11
```

2. Свяжите ассеты темы с GTK4, чтобы Libadwaita приложения (Nautilus, Text Editor) тоже применили стиль:
```bash
mkdir -p ~/.config/gtk-4.0
ln -sf /usr/share/themes/catppuccin-mocha-pink-standard+default/gtk-4.0/gtk.css ~/.config/gtk-4.0/gtk.css
ln -sf /usr/share/themes/catppuccin-mocha-pink-standard+default/gtk-4.0/gtk-dark.css ~/.config/gtk-4.0/gtk-dark.css
ln -sfn /usr/share/themes/catppuccin-mocha-pink-standard+default/gtk-4.0/assets ~/.config/gtk-4.0/assets
```

Убедитесь, что `~/.config/gtk-4.0/settings.ini` содержит настройки темы и шрифта:
```ini
[Settings]
gtk-application-prefer-dark-theme=1
gtk-font-name=Adwaita Sans 11
```

3. Примените настройки к системному порталу:
```bash
gsettings set org.gnome.desktop.interface gtk-theme 'catppuccin-mocha-pink-standard+default'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface font-name 'Adwaita Sans 11'
gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Classic'
gsettings set org.gnome.desktop.interface cursor-size 20
```

### Настройка Qt6 и Qt5
1. Пропишите переменную окружения для использования конфигуратора `qt5ct` / `qt6ct` (значение `qt5ct` автоматически активирует обе версии).

#### Niri (`~/.config/niri/config.kdl`):
```kdl
environment {
    QT_QPA_PLATFORMTHEME "qt5ct"
}
```

#### Hyprland (`~/.config/hypr/hyprland.conf`):
```conf
env = QT_QPA_PLATFORMTHEME,qt5ct
```

#### Универсально — `~/.config/environment.d/90-qt.conf`:
```ini
QT_QPA_PLATFORMTHEME=qt5ct
```

2. Создайте цветовую схему Catppuccin Mocha Pink для `qt6ct` и `qt5ct`. Создайте файл `~/.config/qt6ct/colors/Catppuccin-Mocha-Pink.conf` (и такой же в `~/.config/qt5ct/colors/`):
```ini
[ColorScheme]
active_colors=#ffcdd6f4, #ff313244, #ff45475a, #ff585b70, #ff11111b, #ff181825, #ffcdd6f4, #fff5c2e7, #ffcdd6f4, #ff1e1e2e, #ff1e1e2e, #ff11111b, #fff5c2e7, #ff11111b, #ff89b4fa, #ffcba6f7, #ff181825, #00000000, #ff1e1e2e, #ffcdd6f4, #ff6c7086
disabled_colors=#ff585b70, #ff313244, #ff45475a, #ff585b70, #ff11111b, #ff181825, #ff585b70, #fff5c2e7, #ff585b70, #ff1e1e2e, #ff1e1e2e, #ff11111b, #ff45475a, #ff11111b, #ff89b4fa, #ffcba6f7, #ff181825, #00000000, #ff1e1e2e, #ff585b70, #ff6c7086
inactive_colors=#ffcdd6f4, #ff313244, #ff45475a, #ff585b70, #ff11111b, #ff181825, #ffcdd6f4, #fff5c2e7, #ffcdd6f4, #ff1e1e2e, #ff1e1e2e, #ff11111b, #fff5c2e7, #ff11111b, #ff89b4fa, #ffcba6f7, #ff181825, #00000000, #ff1e1e2e, #ffcdd6f4, #ff6c7086
```

3. Задайте эту схему в настройках `~/.config/qt6ct/qt6ct.conf`:
```ini
[Appearance]
color_scheme_path=/home/trazxdxne/.config/qt6ct/colors/Catppuccin-Mocha-Pink.conf
custom_palette=true
style=Fusion
```

И аналогично в `~/.config/qt5ct/qt5ct.conf`:
```ini
[Appearance]
color_scheme_path=/home/trazxdxne/.config/qt5ct/colors/Catppuccin-Mocha-Pink.conf
custom_palette=true
style=Fusion
```

### Настройка темы и размера курсора в Niri

Чтобы тема курсора (`Bibata-Modern-Classic`) и его размер (`20`) оставались одинаковыми как на пустом рабочем столе Niri, так и внутри всех запущенных приложений, добавьте параметры в конфигурационный файл Niri. Это исключает необходимость редактирования файлов вроде `.profile` или `config.fish`.

Добавьте в `~/.config/niri/config.kdl`:

```kdl
// Настройка курсора для самого композитора Niri (рабочий стол, рамки окон)
cursor {
    xcursor-theme "Bibata-Modern-Classic"
    xcursor-size 20
}

// Передача настроек во все запускаемые приложения
environment {
    QT_QPA_PLATFORMTHEME "qt5ct"
    XCURSOR_THEME "Bibata-Modern-Classic"
    XCURSOR_SIZE "20"
}
```

#### Механизм работы:
- **Блок `cursor`**: настраивает отображение курсора для самого композитора Niri (на рабочем столе и границах окон).
- **Блок `environment`**: экспортирует переменные `XCURSOR_THEME` и `XCURSOR_SIZE` для запущенных приложений. В Wayland приложения сами отрисовывают курсор при наведении на их окна, поэтому без экспорта этих переменных они будут использовать системный курсор по умолчанию (например, Adwaita размером 24).

#### Фикс для X11 / XWayland и Steam (курсор Adwaita):
Некоторые приложения (включая Steam, старый X11-софт или Flatpak-пакеты) запускаются через XWayland и не могут прочитать переменные окружения напрямую или требуют классического X11-конфига для курсора. Если в них отображается дефолтный курсор Adwaita, создайте файл `~/.icons/default/index.theme`:

```ini
[Icon Theme]
Inherits=Bibata-Modern-Classic
```

---

## 3. Окружение Niri: Фиксы, рамки, игры и тонкая настройка

Настройка визуального стиля самого композитора Niri и интеграция необходимых компонентов.

### Базовые утилиты (Polkit, Fuzzel, Gnome Keyring)
Для вывода запросов паролей, быстрого запуска приложений и хранения секретов установите:
```bash
sudo pacman -S polkit-gnome fuzzel gnome-keyring
```

### Настройка автозапуска
Добавьте запуск агента Polkit и демона связки ключей в `~/.config/niri/config.kdl`:
```kdl
spawn-at-startup "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
spawn-at-startup "gnome-keyring-daemon" "--start" "--components=secrets"
```

### Рамки окон, закругления и отступы
1. Чтобы убрать конфликты клиентских закруглений (CSD), сделать углы квадратными и убрать просвечивающие цветные пятна фокус-ринга в углах окон, добавьте в `~/.config/niri/config.kdl`:

```kdl
prefer-no-csd

window-rule {
    geometry-corner-radius 0
    clip-to-geometry true
    draw-border-with-background false // Фикс просвечивания рамки в углах окон
}
```

2. Настройте рамку активного окна и отступы в секции `layout`. Параметр `gaps` отвечает за расстояние между окнами, а `struts` — за внешние отступы у краев экрана (выставьте в `0` для компактного минималистичного вида):

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

### Конфигурация лаунчера Fuzzel
Создайте файл конфигурации `~/.config/fuzzel/fuzzel.ini` для соответствия цветовой гамме Catppuccin Mocha Pink:
```ini
[main]
font=monospace:size=12
prompt="❯ "
fields=filename,name,generic
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

### Запуск Discord (Equicord) через XWayland и обход блокировок (discord-linux-bypass)
Для стабильности на NVIDIA под Wayland запускаем Discord через XWayland, это спасет от постоянных сегфолтов и ошибок памяти драйвера, которые ломают нативный запуск.

Для этого обязательно установите `xwayland-satellite` из репозитория extra, чтобы Niri мог поднимать XWayland на лету:
```bash
sudo pacman -S xwayland-satellite
```

В `~/.config/niri/config.kdl` добавьте экспорт переменной DISPLAY, чтобы приложения видели XWayland-сервер:
```kdl
spawn-at-startup "dbus-update-activation-environment" "--systemd" "DISPLAY" "WAYLAND_DISPLAY" "XAUTHORITY"
```

Для обхода блокировки голосовых чатов Discord (модификации UDP-пакетов для обхода ТСПУ/DPI) используется библиотека `discord-linux-bypass`.

#### 1. Сборка библиотеки
Склонируйте и соберите библиотеку из репозитория:
```bash
git clone https://codeberg.org/nik9/discord-linux-bypass.git ~/Projects/discord-linux-bypass
cd ~/Projects/discord-linux-bypass
make
```
В результате соберется файл `libdiscordbypass.so`.

#### 2. Создание скрипта запуска
Создайте скрипт `~/Projects/discord-linux-bypass/discord_run.sh`:
```bash
#!/usr/bin/env bash

# Путь к скомпилированной библиотеке и конфигу
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_PATH="$DIR/libdiscordbypass.so"
CONFIG_PATH="$DIR/config.env"

# Загружаем порт из конфига, если он существует
if [ -f "$CONFIG_PATH" ]; then
    source "$CONFIG_PATH"
fi

# Если порт не задан, настраиваем
if [ -z "$PORT" ]; then
    if [ -t 0 ]; then
        read -p "Введи порт для SOCKS5 прокси на localhost (по умолчанию 9050): " input_port
        PORT=${input_port:-9050}
        echo "PORT=$PORT" > "$CONFIG_PATH"
    else
        PORT=9050
        echo "PORT=$PORT" > "$CONFIG_PATH"
    fi
fi

export BYPASS_DELAY=50
export BYPASS_FAKE_PACKETS=2
export LD_PRELOAD="$LIB_PATH"

proxy_server="--proxy-server=socks5://127.0.0.1:$PORT"

# Запуск клиента с передачей аргументов
if command -v vesktop &> /dev/null; then
    exec vesktop $proxy_server "$@"
elif command -v discord &> /dev/null; then
    exec discord $proxy_server "$@"
fi
```
Сделайте его исполняемым: `chmod +x ~/Projects/discord-linux-bypass/discord_run.sh`.

#### 3. Настройка порта
Порт SOCKS5 прокси хранится в файле `~/Projects/discord-linux-bypass/config.env`:
```env
PORT=9050
```

#### 4. Интеграция в систему
Скопируйте системный ярлык Discord в локальную директорию и измените строку запуска:
`~/.local/share/applications/discord.desktop`:
```ini
Exec=/home/trazxdxne/Projects/discord-linux-bypass/discord_run.sh --url -- %u
```

### Запуск Windows-приложений (ярлыки Wine)
Для запуска Windows-экзешников (например, игровых клиентов для забора ежедневок) создайте ярлык в `~/.local/share/applications/имя.desktop`. Чтобы программа запускалась корректно и видела свои DLL-библиотеки, обязательно укажите запуск через `wine` и рабочую директорию `Path`:

```ini
[Desktop Entry]
Type=Application
Name=Fortnite
Exec=wine /home/trazxdxne/Desktop/FortniteClient-Win64-Shipping.exe
Path=/home/trazxdxne/Desktop
Terminal=false
```

---

## 4. Звук и автоматическое восстановление громкости

Решение проблем со звуком в USB-гарнитуре (сброс громкости, отключение автосна) и фиксация баланса каналов через WirePlumber.

### Установка звуковых пакетов
```bash
sudo pacman -S alsa-utils pipewire wireplumber
```

### Отключение встроенного звука (PCI/HDMI) и настройка WirePlumber

Чтобы полностью отключить встроенные PCI и HDMI звуковые карты (Nvidia HDMI, материнская плата) на системном уровне, чтобы они не отображались в alsamixer, заблокируйте модуль `snd_hda_intel`.

1. Создайте файл конфигурации modprobe `/etc/modprobe.d/disable-hda.conf` (потребуются права superuser через `pkexec` или `sudo`):
```bash
echo "blacklist snd_hda_intel" | pkexec tee /etc/modprobe.d/disable-hda.conf
```
*(После этого перезагрузите компьютер).*

2. Для USB-устройств включите аппаратный микшер в WirePlumber. Создайте файл `~/.config/wireplumber/wireplumber.conf.d/50-audio-rules.conf`:
```
monitor.alsa.rules = [
  {
    matches = [
      { device.name = "~alsa_card.usb-.*" }
    ]
    actions = {
      update-props = {
        api.alsa.soft-mixer = false
      }
    }
  }
]
```

2. Запретите USB-аудиоустройствам уходить в сон (что сбрасывает настройки ALSA). Создайте файл `~/.config/wireplumber/wireplumber.conf.d/51-usb-volume-fix.conf`:
```
monitor.alsa.rules = [
  {
    matches = [
      { node.name = "~alsa_output.usb-.*" }
    ]
    actions = {
      update-props = {
        node.pause-on-idle    = false
        session.suspend-timeout-seconds = 0
      }
    }
  }
]
```

### Восстановление баланса громкости
1. Узнайте точное имя вашей USB-гарнитуры в системе PipeWire:
```bash
pactl list sinks | grep Name
```
*Пример вывода: `alsa_output.usb-3142_fifine_Headset-00.analog-stereo`*

2. Создайте пользовательскую службу systemd `~/.config/systemd/user/alsa-volume-restore.service` для восстановления баланса на старте (в примере выставлено 84% на левый канал и 100% на правый):
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

3. Активируйте службу и перезапустите звуковой стек:
```bash
systemctl --user daemon-reload
systemctl --user enable --now alsa-volume-restore.service
systemctl --user restart pipewire wireplumber
```

### Настройка виртуального объемного звука 7.1 (HeSuVi) через EasyEffects

Если при использовании PipeWire Virtual Surround Sink с EasyEffects пропадает звук или возникает бесконечная петля маршрутизации, выполните следующие шаги:

1. **Конфигурация PipeWire (`~/.config/pipewire/pipewire.conf.d/99-virtual-surround.conf`)**
Убедитесь, что цепочка фильтров (filter chain) выводит звук в EasyEffects:
```conf
playback.props = {
    target.object = "easyeffects_sink"
}
```
*(Примечание: может потребоваться увеличить параметр `gain` на узлах конвольвера, если громкость слишком низкая).*

2. **Системные настройки**
Установите **Virtual Surround Sink** в качестве системного устройства вывода по умолчанию.

3. **Настройки EasyEffects**
- Перейдите на вкладку **Players** и отключите **Process All Outputs** (или снимите галочки с конкретных игр/приложений). Это заставит приложения отправлять свой 7.1 звук в Virtual Surround Sink, а не обходить его.
- Перейдите на вкладку **PipeWire** и измените **Output Device** с *Default* напрямую на вашу **аппаратную гарнитуру** (например, Fifine). Это разорвет бесконечную петлю звука.

**Схема маршрутизации:**
Приложение (7.1) -> Virtual Surround Sink (2.0) -> EasyEffects Sink -> Аппаратная гарнитура

---

### Дополнительная настройка: Фикс масштабирования громкости и кэша

Если громкость по умолчанию слишком высокая или ведет себя непредсказуемо, можно сбросить кэш WirePlumber и принудительно задать дефолтный уровень громкости:

1. Остановите службу WirePlumber:
```bash
systemctl --user stop wireplumber.service
```

2. Очистите старый кэш громкости (исправляет баг с громкостью на 100%):
```bash
rm -rf ~/.local/state/wireplumber
```

3. Установите дефолтную громкость воспроизведения (например, `0.2`, что соответствует примерно 58% на линейной шкале из-за кубического масштабирования):
```bash
mkdir -p ~/.config/wireplumber/wireplumber.conf.d/
printf "wireplumber.settings = {\n  node.stream.default-playback-volume = 0.2\n}\n" > ~/.config/wireplumber/wireplumber.conf.d/99-force-volume.conf
```

4. Запустите службу снова:
```bash
systemctl --user start wireplumber.service
```

---


## 5. Типографская раскладка клавиатуры

Настройка переключения раскладок по Caps Lock, правого Alt для спецсимволов и типографской раскладки.

### Параметры XKB
- `layout "us,ru"` — две раскладки (английская и русская).
- `grp:caps_toggle` — переключение по Caps Lock.
- `lv3:ralt_switch` — правый Alt включает 3-й уровень символов.
- `misc:typo` — включает ввод типографских символов (например, правый Alt + Shift + `,` для « и правый Alt + Shift + `.` для »).

### Настройка в различных средах

#### Niri (`~/.config/niri/config.kdl`):
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

#### Hyprland (`~/.config/hypr/hyprland.conf`):
```conf
input {
    kb_layout = us,ru
    kb_options = grp:caps_toggle,lv3:ralt_switch,misc:typo
}
```

#### Sway (`~/.config/sway/config`):
```conf
input type:keyboard {
    xkb_layout us,ru
    xkb_options grp:caps_toggle,lv3:ralt_switch,misc:typo
}
```

#### i3 (`~/.config/i3/config`):
```conf
exec_always --no-startup-id setxkbmap -layout us,ru -option grp:caps_toggle,lv3:ralt_switch,misc:typo
```

#### MangoWM (`~/.config/mango/config.conf`):
```conf
xkb_rules_layout=us,ru
xkb_rules_options=grp:caps_toggle,lv3:ralt_switch,misc:typo
```

#### DriftWM (`~/.config/driftwm/config.toml`):
```toml
[input.keyboard]
layout = "us,ru"
options = "grp:caps_toggle,lv3:ralt_switch,misc:typo"
```

#### GNOME:
```bash
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('xkb', 'ru')]"
gsettings set org.gnome.desktop.input-sources xkb-options "['grp:caps_toggle', 'lv3:ralt_switch', 'misc:typo']"
```

#### Универсальный системный уровень (через `localectl`):
```bash
sudo localectl set-x11-keymap us,ru "" "" grp:caps_toggle,lv3:ralt_switch,misc:typo
```
*Примечание: Wayland-композиторы (Niri, Hyprland, Sway) используют собственные файлы настроек и игнорируют параметры `localectl`.*

---

## 6. Эмулятор терминала WezTerm (Тема и Кириллические шорткаты)

Решение проблем с горячими клавишами (`Ctrl+C`, `Ctrl+V`, `Ctrl+Shift+C`) при включенной русской раскладке в Wayland и применение цветовой схемы.

### Настройка темы и фикс цветов в TUI (Alsamixer)
В WezTerm тема Catppuccin Mocha встроена по умолчанию. Однако консольные утилиты (например, `alsamixer`) жестко используют системные зеленые и голубые ANSI-цвета, что на светлом фоне выделения делает текст нечитаемым. Чтобы принудительно раскрасить их в розовые тона и исправить контраст, переопределите ANSI-палитру в `~/.wezterm.lua`:

```lua
config.color_scheme = 'Catppuccin Mocha'
config.colors = {
  ansi = {
    '#1e1e2e', -- 0 black
    '#f38ba8', -- 1 red (high usage)
    '#cba6f7', -- 2 green -> mauve/purple (low usage in fastfetch, bars in alsamixer)
    '#fab387', -- 3 yellow -> peach (mid usage)
    '#89b4fa', -- 4 blue
    '#f5c2e7', -- 5 magenta -> pink
    '#f5e0dc', -- 6 cyan -> rosewater (text in alsamixer)
    '#45475a', -- 7 white -> dark grey (highlight background)
  },
  brights = {
    '#585b70', -- 8
    '#f38ba8', -- 9
    '#cba6f7', -- 10
    '#fab387', -- 11
    '#89b4fa', -- 12
    '#f5c2e7', -- 13
    '#f5e0dc', -- 14
    '#585b70', -- 15
  }
}
```

### Исправление медленного запуска и зависаний на Wayland + NVIDIA
На видеокартах NVIDIA под Wayland нативный OpenGL-рендерер WezTerm может зависать на старте или требовать двойного нажатия хоткея для открытия окна.

Чтобы полностью решить эту проблему и заставить терминал запускаться мгновенно с первого раза, запускайте WezTerm с флагами `start --always-new-process`.

Например, в конфигурации Niri (`~/.config/niri/config.kdl`):
```kdl
Mod+Return { spawn "wezterm" "start" "--always-new-process"; }
```

### Настройка кириллических шорткатов
Чтобы `Ctrl+C` и `Ctrl+V` работали на русской раскладке, добавьте следующий блок клавиш в секцию `config.keys` вашего `~/.wezterm.lua`:

> [!WARNING]
> Так как копирование переносится на `Ctrl+C`, для отправки сигнала прерывания (SIGINT) используется сочетание `Ctrl+Shift+C`.

```lua
local act = wezterm.action
config.keys = {
    -- Вставка на обеих раскладках (Ctrl+V / Ctrl+М)
    { key = 'v', mods = 'CTRL', action = act.PasteFrom('Clipboard') },
    { key = 'м', mods = 'CTRL', action = act.PasteFrom('Clipboard') },

    -- Копирование на обеих раскладках (Ctrl+C / Ctrl+С)
    { key = 'c', mods = 'CTRL', action = act.CopyTo('Clipboard') },
    { key = 'с', mods = 'CTRL', action = act.CopyTo('Clipboard') },

    -- Прерывание программы (SIGINT) по Ctrl+Shift+C / Ctrl+Shift+С
    { key = 'C', mods = 'CTRL|SHIFT', action = act.SendKey{ key='c', mods='CTRL' } },
    { key = 'С', mods = 'CTRL|SHIFT', action = act.SendKey{ key='c', mods='CTRL' } },
}
```

### Настройка цветов процентов в Fastfetch
По умолчанию `fastfetch` красит все проценты до 50% в зеленый цвет. Из-за переопределения зеленого цвета в Mauve (для читаемости `alsamixer`), большинство показателей сливаются в один оттенок.
Чтобы вернуть визуальную разницу и использовать наши пастельные акценты в зависимости от нагрузки (Mauve -> Peach -> Red), необходимо изменить дефолтные пороги:

1. Сгенерируйте конфигурацию, если ее нет:
```bash
fastfetch --gen-config
```
2. Откройте `~/.config/fastfetch/config.jsonc` и найдите секцию `modules`. Замените простые строки `"memory"`, `"swap"`, `"disk"` на объекты с умными порогами, настроенными под реальную нагрузку:
```jsonc
{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/master/doc/json_schema.json",
  "modules": [
    // ...
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
    },
    // ...
```
