---
name: telegram-icon-finder
description: Discover and bind monochrome vector custom emoji icons (icon_custom_emoji_id) to Telegram inline buttons using Bot API getStickerSet.
---

# Telegram UI Icon Finder & Button Styling (Bot API 9.4+)

Autonomous workflow for attaching monochrome vector custom emojis (`icon_custom_emoji_id`) and color hierarchy (`style`) to Telegram inline buttons without human intervention.

## Leading concepts
- `monochrome`: adaptive vector icon (`needs_repainting=True`) matching button text color dynamically.
- `clean`: button text containing only functional text labels.
- `style`: color accent token (`primary` for active state, `danger` for dismiss/delete, omitted for neutral).
- `cache`: single source of truth in `src/utils/ui_icons.py`.

---

## 1. System Icon Packs
Telegram provides official system packs containing monochrome vector glyphs:
- `tgmacicons`: macOS/iOS SF Symbols contour aesthetic.
- `TgAndroidIcons`: Android system outline glyphs.
- `vector_icons_by_fStikBot`: Minimalist UI icon set (folders, cards, chat, info).

Every sticker in these packs has:
- `custom_emoji_id`: String identifier passed to `InlineKeyboardButton(icon_custom_emoji_id=...)`.
- `emoji`: Semantic unicode character the contour icon corresponds to (e.g. ➕ for new, 📁 for projects, 💬 for chat, ℹ️ for help, ❌ for dismiss).
- `needs_repainting`: Set to `true`, allowing the Telegram client to repaint the glyph in the button's label color.

---

## 2. Autonomous Discovery Workflow

When an inline button requires an icon ID:

### Step 1: Check Local Cache
Inspect `src/utils/ui_icons.py`. If the semantic key exists in `UI_ICONS`, use `UI_ICONS[key]`.

### Step 2: Fetch Pack via Telegram Bot API
If the key is missing or icons need updating, query Telegram Bot API `getStickerSet` using `TELEGRAM_BOT_TOKEN` (or `BOT_TOKEN`) from `.env`.

**Terminal Command (UTF-8 safe):**
```bash
python -c "import os, sys, urllib.request, json; from dotenv import load_dotenv; sys.stdout.reconfigure(encoding='utf-8') if sys.platform=='win32' else None; load_dotenv(); token=os.getenv('TELEGRAM_BOT_TOKEN') or os.getenv('BOT_TOKEN'); res=json.loads(urllib.request.urlopen(f'https://api.telegram.org/bot{token}/getStickerSet?name=tgmacicons').read()); print(json.dumps({s['emoji']: s['custom_emoji_id'] for s in res['result']['stickers']}, ensure_ascii=False, indent=2))"
```

**Alternative CLI Toolkit:**
If `telegram-premium-emojis` is installed:
```bash
python -m telegram_premium_emojis.scanner tgmacicons TgAndroidIcons --token $TELEGRAM_BOT_TOKEN --format json --out ui_icons.json
```

### Step 3: Map Semantic Emoji to Keys
Match target button actions with corresponding emoji:
| Action | Semantic Emoji | System Pack Key |
| :--- | :--- | :--- |
| New dialogue | ➕ | `new_chat` |
| Dialogue history | 🕘, 🗓, 🕒 | `history` |
| Workspace / projects | 📁, 📂 | `projects` |
| Profile / memory | 👤, 🧠 | `profile` |
| System status | ⚡️, ⚙ | `status` |
| Help / instructions | ℹ️ | `help` |
| Close / dismiss | ❌ | `close` |
| Delete | 🗑 | `delete` |
| Navigation back | ⬅️ | `back` |
| Navigation forward | ➡️ | `forward` |
| Refresh | 🔄 | `refresh` |
| Dev role | 💻 | `role_dev` |
| Finance role | 💰, 🪙 | `role_fin` |
| Food role | 🍴 | `role_food` |

### Step 4: Persist to `src/utils/ui_icons.py`
Save the resolved IDs in `UI_ICONS`:
```python
UI_ICONS = {
    "new_chat": "5359529383319084413",
    "projects": "5452165780579843515",
    "close": "5267123797600783095",
}
```

---

## 3. Inline Button Implementation Rules

### 1. Clean Button Text
- Write purely functional labels in `text`: `"Новый диалог"`, `"История"`, `"DEV"`, `"FIN"`.
- Keep text free of bracket indicators (`[DEV]`, `[+]`, `[✓]`, `[✕]`) and text-based emojis. Visual state belongs exclusively in `icon_custom_emoji_id` and `style`.

### 2. Mandatory Vector Icon
Pass `icon_custom_emoji_id` to `InlineKeyboardButton`:
```python
from aiogram.types import InlineKeyboardButton
from src.utils.ui_icons import get_icon

InlineKeyboardButton(
    text="Новый диалог",
    icon_custom_emoji_id=get_icon("new_chat"),
    callback_data="hub_new_conv"
)
```

### 3. Color Accents (`style`)
Apply `style` parameter according to role hierarchy:
- Active state / primary call-to-action: `style="primary"`
- Dismissal / destructive action: `style="danger"`
- Standard neutral action: omit `style`

**Example (Single-message hub row):**
```python
# Active agent switch row
InlineKeyboardButton(
    text="FIN",
    icon_custom_emoji_id=get_icon("role_fin"),
    style="primary" if active_agent == "finance" else None,
    callback_data="hub_set_agent:finance"
)
```

---

## 4. Header Typography
Structure headers above inline keyboards:
- 2–3 compact lines.
- Separate metadata properties with middle dots (` · `) or bullets (` • `).
- Format hierarchy with `<b>` and `<code>`.

```html
<b>Antigravity</b> · Воркспейс <code>Projects</code>
<b>Роль: Финансы (ДБТ) · Новый диалог</b>
```

---

## 5. Completion Criteria
- [ ] Every functional action button has `icon_custom_emoji_id` populated from `UI_ICONS`.
- [ ] Active role tab or primary CTA has `style="primary"`.
- [ ] Button labels contain clean readable text.
- [ ] Test suite executes cleanly (`pytest tests/`).
