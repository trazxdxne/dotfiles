# Prompt for Linux (CachyOS) Agent: Game Split-Tunneling & AmneziaWG Integration

```markdown
Ты работаешь в среде CachyOS (Arch-based). Твоя задача — внедрить раздельное туннелирование (split tunneling) для игр в обход VPN и перевести VPN-стек dotfiles с официального `warp-cli` на `AmneziaWG` (`awg-quick`). Все изменения должны быть интегрированы в структуру репозитория `~/.dotfiles` согласно правилам `AGENTS.md`, а также отражены в `install.sh`.

---

### Архитектурный контекст репозитория:
- **Целевая система:** CachyOS (Arch-based).
- **Модульная структура:** `~/.dotfiles/modules/network/`
  - Пользовательские скрипты: `modules/network/user/.local/bin/` (линкуются через GNU Stow в `~/.local/bin`).
  - Системные файлы: `modules/network/root-arch/` (копируются в `/` с правами `root:root`).
- **Сетевой стек:** `NetworkManager` + `systemd-resolved` + `zapret` (nfqws) + `AmneziaWG` (`awg-quick@awg0.service`).
- **Безопасность для античитов (EAC / BattlEye):** Прямое изолирование игрового процесса с момента запуска через `cgroup v2` (`systemd-run --user --scope --slice=game-bypass.slice`) в связке с `nftables` (fwmark) и `ip rule` (policy routing). Игры и античит запускаются сразу в обходном пространстве, без внешних инъекций и мониторинга памяти/процессов, что гарантирует защиту от банов и отсутствие задержек (0% CPU).

---

### Задачи агента:

#### 1. Инвентаризация и подготовка AmneziaWG:
1. Проверь наличие пакетов `amneziawg-tools` и `amneziawg-dkms` (или модуля ядра amneziawg в CachyOS):
   ```bash
   pkexec pacman -S --needed --noconfirm amneziawg-tools amneziawg-dkms
   ```
2. Найди конфигурационный файл AmneziaWG (например, `mlwWARP*.conf` из `~/Downloads` или подготовленный пользователем) и разверни его как `/etc/amnezia/amneziawg/awg0.conf`:
   - Установи строгие права доступа: `chmod 600 /etc/amnezia/amneziawg/awg0.conf` и `chown root:root`.
   - Никогда не коммить реальные файлы с приватными ключами в Git репозитория! Добавь `awg0.conf` в `.gitignore` или оставь шаблон `awg0.conf.template` в `modules/network/`.

#### 2. Разработка механизма Split-Tunneling (Game Bypass):
1. **Скрипт запуска `game-bypass`:**
   - Создай исполняемый файл `modules/network/user/.local/bin/game-bypass`:
     ```bash
     #!/usr/bin/env bash
     set -euo pipefail
     if [[ $# -eq 0 ]]; then
         echo "Usage: game-bypass <command> [args...]" >&2
         exit 1
     fi
     exec systemd-run --user --scope --slice=game-bypass.slice "$@"
     ```
   - Назначь права `chmod +x`.
   - Использование в Steam: в свойствах запуска игры (Dead by Daylight, Fortnite / Epic через Proton и др.) прописывается:
     `game-bypass %command%`
   - Использование в Heroic / Lutris / терминале: `game-bypass heroic` или `game-bypass <binary>`.

2. **Системные правила маршрутизации и фаервола:**
   - Для обхода `awg0` пакеты от `game-bypass.slice` должны получать fwmark (например, `0x51`) и направляться через шлюз локального провайдера (таблица маршрутизации `main` или кастомная таблица `default_gw`).
   - Создай systemd-юнит `modules/network/root-arch/etc/systemd/system/game-bypass-routing.service` и сопровождающий скрипт/правила:
     - Определение дефолтного шлюза и интерфейса провайдера (до поднятия туннеля).
     - Добавление `ip rule add fwmark 0x51 lookup main priority 100` (приоритет выше, чем у WireGuard fwmark suppression).
     - Добавление правила `nftables` в хук output mangle:
       ```nft
       table inet game_bypass {
           chain output {
               type route hook output priority mangle; policy accept;
               socket cgroup "game-bypass.slice" mark set 0x51
           }
       }
       ```
     - Отключение строгого `rp_filter` при необходимости (`sysctl -w net.ipv4.conf.all.rp_filter=2`).

#### 3. Обновление репозитория dotfiles:
1. **`modules.toml`:**
   - Добавь `amneziawg-tools` в `modules.network.distro_packages.arch`.
   - Зарегистрируй необходимые системные сервисы (`game-bypass-routing.service`).
2. **`install.sh`:**
   - Обнови проверку и установку AmneziaWG вместо `cloudflare-warp` для Arch/CachyOS.
   - Включи развертывание и активацию `game-bypass-routing.service`.
   - Добавь включение `awg-quick@awg0.service`, если `/etc/amnezia/amneziawg/awg0.conf` существует.
   - Обнови функцию `rollback_network()`:
     - Остановка `awg-quick@awg0`.
     - Остановка и удаление `game-bypass-routing.service`.
     - Удаление nftables таблицы `inet game_bypass`.
     - Удаление `ip rule` с fwmark `0x51`.

#### 4. Верификация:
1. Запусти `awg-quick up awg0` (или `systemctl start awg-quick@awg0`).
2. Проверь общий сетевой трафик системы:
   ```bash
   curl -s https://ipinfo.io/ip
   ```
   Должен возвращать IP Cloudflare / VPN-туннеля.
3. Проверь трафик в обходном режиме через `game-bypass`:
   ```bash
   game-bypass curl -s https://ipinfo.io/ip
   ```
   Должен возвращать прямой публичный IP твоего интернет-провайдера.
4. Проверь запуск игры в Steam/Heroic: сетевое соединение и античит должны работать без разрывов и с минимальным пингом напрямую к игровым серверам.

---

### Критерий приемки:
- Весь интернет-трафик системы и браузеров направляется через зашифрованный AmneziaWG (WARP).
- Любая игра, запущенная с префиксом `game-bypass %command%`, вместе с дочерними процессами и античитом направляет сетевой трафик напрямую через шлюз провайдера.
- Файлы интегрированы в структуру `modules/network/`, `install.sh` обновлен с поддержкой чистой установки и отката (`--rollback-network`), а приватные ключи не попали в Git.
```
