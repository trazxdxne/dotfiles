# Полная настройка Equicord и плагина OSDisplayName (Linux & Windows) 🌸

Инструкция, как настроить автоматическую смену отображаемого имени в Дискорде в зависимости от операционной системы (`C:\Users\username` на Windows, `/home/username` на Linux).

---

## 🛠️ Шаг 1. Установка Node.js и pnpm

Для сборки плагина на обеих системах нужны Node.js (v22+) и pnpm.

### На Arch Linux
1. Установи Node.js и pnpm через pacman:
   ```bash
   sudo pacman -Syu nodejs pnpm
   ```

### На Windows
1. Скачай и установи **Node.js** (LTS или последнюю версию) с [nodejs.org](https://nodejs.org/).
2. Открой PowerShell от имени Администратора и установи `pnpm`:
   ```powershell
   npm install -g pnpm
   ```

---

## 📂 Шаг 2. Клонирование репозитория

Сделай это на обеих системах (на Linux мы положили его в `/home/username/Programs/`, на Windows можно положить, например, в `C:\Programs\`).

1. Склонируй Equicord:
   ```bash
   git clone https://github.com/Equicord/Equicord.git
   cd Equicord
   ```
2. Установи зависимости:
   ```bash
   pnpm install
   ```

---

## 📝 Шаг 3. Создание плагина

В папке Equicord создай файл `src/userplugins/osDisplayName.ts` и вставь туда следующий код:

```typescript
import { definePluginSettings } from "@api/Settings";
import definePlugin, { OptionType } from "@utils/types";
import { UserStore, RestAPI } from "@webpack/common";

const settings = definePluginSettings({
    enabled: {
        type: OptionType.BOOLEAN,
        description: "Включить автоматическую смену никнейма при входе",
        restartNeeded: false,
        default: false
    },
    windowsTemplate: {
        type: OptionType.STRING,
        description: "Формат для Windows (используй {username} для юзернейма)",
        restartNeeded: false,
        default: "C:\\Users\\{username}"
    },
    linuxTemplate: {
        type: OptionType.STRING,
        description: "Формат для Linux (используй {username} для юзернейма)",
        restartNeeded: false,
        default: "/home/{username}"
    },
    macTemplate: {
        type: OptionType.STRING,
        description: "Формат для macOS (используй {username} для юзернейма)",
        restartNeeded: false,
        default: "/Users/{username}"
    }
});

let interval: any = null;

function runNicknameUpdate(user: any) {
    if (!settings.store.enabled) {
        console.log("[OSDisplayName] Plugin is disabled in settings");
        return;
    }

    const platform = (window as any).DiscordNative?.process?.platform || "";
    const userAgent = navigator.userAgent.toLowerCase();
    
    let isWindows = platform === "win32" || userAgent.includes("win");
    let isLinux = platform === "linux" || userAgent.includes("linux");
    let isMac = platform === "darwin" || userAgent.includes("mac");
    
    let template = "";
    const username = user.username;

    if (isWindows) {
        template = settings.store.windowsTemplate;
    } else if (isLinux) {
        template = settings.store.linuxTemplate;
    } else if (isMac) {
        template = settings.store.macTemplate;
    }

    if (!template) return;

    const targetName = template.replace("{username}", username);

    if (user.globalName === targetName) {
        console.log("[OSDisplayName] Display name is already correct:", targetName);
        return;
    }

    RestAPI.patch({
        url: "/users/@me",
        body: {
            global_name: targetName
        }
    }).then(() => {
        console.log("[OSDisplayName] Successfully updated display name to:", targetName);
    }).catch((err: any) => {
        console.error("[OSDisplayName] Error updating display name:", err);
    });
}

export default definePlugin({
    name: "OSDisplayName",
    description: "Changes your display name depending on the operating system you are on",
    authors: [
        {
            name: "Hannah",
            id: 100000000000000000n
        }
    ],
    settings,
    start() {
        interval = setInterval(() => {
            const user = UserStore.getCurrentUser();
            if (user) {
                clearInterval(interval);
                interval = null;
                runNicknameUpdate(user);
            }
        }, 5000);
    },
    stop() {
        if (interval) {
            clearInterval(interval);
            interval = null;
        }
    }
});
```

---

## 🚀 Шаг 4. Сборка и установка (Инжект)

### На обеих системах:
1. Собери проект:
   ```bash
   pnpm build
   ```
2. Выполни инъекцию в установленный клиент Discord:
   ```bash
   pnpm inject
   ```
3. Полностью перезапусти Дискорд.
4. Открой **Настройки пользователя** -> **Equicord** -> **Плагины** (Plugins).
5. Найди плагин **OSDisplayName**, включи его и нажми на иконку шестерёнки рядом, чтобы настроить шаблоны и включить автоматическую смену отображаемого имени)

---

## 🔄 Шаг 5. Как обновлять всё в будущем

Так как мы используем локальную сборку из исходников, обычные обновления работать не будут. Вот как правильно обновляться:

### 1. Если обновился сам Equicord (вышла новая версия)
Перейди в терминале в папку с клоном Equicord и выполни:
```bash
git pull
pnpm install
pnpm build
```
*Инжект перезапускать не нужно! Дискорд привязан к этой папке и сразу подтянет новые файлы при следующем запуске.*

### 2. Если обновился сам клиент Discord (и слетел Equicord)
Когда Дискорд скачивает свои крупные обновления, он может стереть наш патч. Чтобы вернуть Equicord на место, просто зайди в папку проекта и введи:
```bash
pnpm inject
```

### 3. Если ты изменил код плагина
После любого изменения кода в `src/userplugins/osDisplayName.ts` просто запусти сборку:
```bash
pnpm build
```
И перезапусти Дискорд, чтобы изменения применились.

