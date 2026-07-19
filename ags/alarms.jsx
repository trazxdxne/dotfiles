import app from "ags/gtk3/app"
import { Astal, Gtk, Gdk } from "ags/gtk3"
import { execAsync, subprocess } from "ags/process"
import GLib from "gi://GLib"

const ALARMS_FILE = GLib.build_filenamev([GLib.get_home_dir(), ".config", "ags", "alarms.json"])
const SNOOZE_MINUTES = 5
const AUTO_SNOOZE_MINUTES = 1
const MISSED_THRESHOLD_MINUTES = 30

let alarms = []
let currentRingingAlarm = null
let autoSnoozeTimeout = null
let playerProc = null

export let AlarmOSD = null
export let AlarmMenu = null

function calculateNextRingTs(timeStr, days, fromTs = null) {
    const fromDate = fromTs ? new Date(fromTs * 1000) : new Date()
    const [h, m] = timeStr.split(":").map(Number)
    
    for (let i = 0; i <= 7; i++) {
        const candidate = new Date(fromDate.getTime())
        candidate.setDate(candidate.getDate() + i)
        candidate.setHours(h, m, 0, 0)
        
        if (candidate.getTime() <= fromDate.getTime()) continue
        
        const isWeekday = candidate.getDay() > 0 && candidate.getDay() < 6
        if (days === "Weekdays" && !isWeekday) continue
        
        return Math.floor(candidate.getTime() / 1000)
    }
    return null
}

function loadAlarms() {
    try {
        const [ok, contents] = GLib.file_get_contents(ALARMS_FILE)
        if (ok) {
            alarms = JSON.parse(new TextDecoder("utf-8").decode(contents))
        }
    } catch (e) {
        alarms = []
    }
}

function syncWakealarm() {
    let nextRingTs = null
    const nowTs = Math.floor(Date.now() / 1000)
    alarms.forEach(a => {
        if (!a.enabled) return
        let ts = a.nextRingTs
        if (!ts || ts < nowTs) {
            ts = calculateNextRingTs(a.time, a.days, nowTs)
        }
        if (ts && (!nextRingTs || ts < nextRingTs)) {
            nextRingTs = ts
        }
    })
    
    execAsync(["bash", "-c", "echo 0 | sudo tee /sys/class/rtc/rtc0/wakealarm >/dev/null"]).then(() => {
        if (nextRingTs) {
            const wakeTs = nextRingTs - 5
            execAsync(["bash", "-c", `echo ${wakeTs} | sudo tee /sys/class/rtc/rtc0/wakealarm >/dev/null`]).catch(e => console.error(e))
        }
    }).catch(e => console.error(e))
}

function saveAlarms() {
    try {
        const nowTs = Math.floor(Date.now() / 1000)
        alarms.forEach(a => {
            if (a.enabled && (!a.nextRingTs || a.nextRingTs < nowTs)) {
                a.nextRingTs = calculateNextRingTs(a.time, a.days, nowTs)
            }
        })
        
        GLib.file_set_contents(ALARMS_FILE, JSON.stringify(alarms, null, 2))
        syncWakealarm()
    } catch (e) {
        console.error(e)
    }
}

const osdTimeLabel = <label class="alarm-osd-time" />
const osdNoteLabel = <label class="alarm-osd-note" />
const alarmsListBox = <box vertical spacing={10} class="alarm-list-box" />

function ringAlarm(alarm) {
    if (currentRingingAlarm) return
    currentRingingAlarm = alarm
    
    try {
        playerProc = subprocess(['sh', '-c', 'while true; do pw-play /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga || mpv --loop /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga || sleep 1; done'])
    } catch (e) {
        console.error(e)
    }
    
    osdTimeLabel.label = alarm.time
    osdNoteLabel.label = alarm.note || "Alarm"
    if (AlarmOSD) AlarmOSD.show_all()
    
    autoSnoozeTimeout = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, AUTO_SNOOZE_MINUTES * 60, () => {
        snoozeAlarm()
        return GLib.SOURCE_REMOVE
    })
}

export function stopAlarm() {
    if (playerProc) {
        playerProc.kill()
        playerProc = null
    }
    if (autoSnoozeTimeout) {
        GLib.source_remove(autoSnoozeTimeout)
        autoSnoozeTimeout = null
    }
    if (AlarmOSD) AlarmOSD.hide()
    currentRingingAlarm = null
    saveAlarms()
}

export function snoozeAlarm() {
    if (!currentRingingAlarm) return
    const snoozed = currentRingingAlarm
    stopAlarm()
    
    snoozed.nextRingTs = Math.floor(Date.now() / 1000) + (SNOOZE_MINUTES * 60)
    saveAlarms()
}

export function checkAlarms() {
    if (currentRingingAlarm) return true
    
    loadAlarms()
    const nowTs = Math.floor(Date.now() / 1000)
    let updated = false
    
    alarms.forEach(alarm => {
        if (!alarm.enabled) return
        
        if (alarm.nextRingTs && nowTs >= alarm.nextRingTs) {
            const diff = nowTs - alarm.nextRingTs
            
            if (diff < MISSED_THRESHOLD_MINUTES * 60) {
                ringAlarm(alarm)
            } else {
                execAsync(["notify-send", "-u", "critical", "Alarm Missed", `Alarm ${alarm.time} was missed`]).catch(e => console.error(e))
            }
            
            alarm.nextRingTs = calculateNextRingTs(alarm.time, alarm.days, nowTs)
            updated = true
        } else if (!alarm.nextRingTs) {
            alarm.nextRingTs = calculateNextRingTs(alarm.time, alarm.days)
            updated = true
        }
    })
    
    if (updated) saveAlarms()
    
    return true
}

export function setupAlarmWindows() {
    AlarmOSD = (
        <window
            class="alarm-osd-window"
            anchor={Astal.WindowAnchor.TOP}
            layer={Astal.Layer.OVERLAY}
            margin_top={84}
            visible={false}
            application={app}
        >
            <box vertical class="alarm-osd">
                {osdTimeLabel}
                {osdNoteLabel}
                <box halign={Gtk.Align.CENTER} spacing={10} margin_top={15}>
                    <button class="alarm-button" label={`Snooze (${SNOOZE_MINUTES}m)`} onClicked={snoozeAlarm} />
                    <button class="alarm-button delete" label="Dismiss" onClicked={stopAlarm} />
                </box>
            </box>
        </window>
    )

    AlarmMenu = (
        <window
            class="alarm-menu-window"
            anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.BOTTOM | Astal.WindowAnchor.LEFT | Astal.WindowAnchor.RIGHT}
            layer={Astal.Layer.OVERLAY}
            visible={false}
            application={app}
            keymode={Astal.Keymode.ON_DEMAND}
            onKeyPressEvent={(self, event) => {
                const [, keyval] = event.get_keyval();
                if (keyval === Gdk.KEY_Escape) {
                    self.hide();
                    return true;
                }
                return false;
            }}
        >
            <eventbox onButtonPressEvent={() => { AlarmMenu.hide(); return true; }} expand={true}>
                <box valign={Gtk.Align.START} halign={Gtk.Align.CENTER} margin_top={24} margin_bottom={40}>
                    <eventbox onButtonPressEvent={() => true}>
                        <box vertical class="alarm-menu" width_request={360}>
                            <box margin_bottom={10}>
                                <label class="alarm-title" label="Alarms" hexpand={true} halign={Gtk.Align.START} />
                            </box>
                            <scrollable class="alarm-scrollable" vexpand={true} hscroll={Gtk.PolicyType.NEVER} vscroll={Gtk.PolicyType.AUTOMATIC} shadow_type={Gtk.ShadowType.NONE} propagate_natural_height={true} max_content_height={600}>
                                {alarmsListBox}
                            </scrollable>
                            <button class="alarm-button" label="+ Add Alarm" margin_top={10} onClicked={() => {
                    alarms.push({ id: Date.now().toString(), time: "08:00", days: "All", enabled: false, note: "" })
                    saveAlarms()
                    renderAlarmsList()
                            }} />
                        </box>
                    </eventbox>
                </box>
            </eventbox>
        </window>
    )

    loadAlarms()
    GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 60, checkAlarms)
}

function AlarmItem(alarm) {
    const timeEntry = new Gtk.Entry({ text: alarm.time, width_chars: 5 })
    timeEntry.get_style_context().add_class("alarm-time-input")

    const noteEntry = new Gtk.Entry({ text: alarm.note || "", placeholder_text: "Note", hexpand: true })
    noteEntry.get_style_context().add_class("alarm-time-input")

    const enabledSwitch = new Gtk.Switch({ active: alarm.enabled, valign: Gtk.Align.CENTER })
    
    const daysBtn = new Gtk.Button({ label: alarm.days })
    daysBtn.get_style_context().add_class("alarm-button")

    const deleteBtn = new Gtk.Button({ label: "🗑" })
    deleteBtn.get_style_context().add_class("alarm-button")
    deleteBtn.get_style_context().add_class("delete")
    
    const box = new Gtk.Box({ spacing: 8 })
    box.get_style_context().add_class("alarm-item")
    
    timeEntry.connect("changed", () => {
        alarm.time = timeEntry.get_text()
        alarm.nextRingTs = calculateNextRingTs(alarm.time, alarm.days)
        saveAlarms()
    })
    noteEntry.connect("changed", () => { 
        alarm.note = noteEntry.get_text()
        saveAlarms()
    })
    enabledSwitch.connect("notify::active", () => { 
        alarm.enabled = enabledSwitch.active
        if (alarm.enabled) alarm.nextRingTs = calculateNextRingTs(alarm.time, alarm.days)
        saveAlarms()
    })
    daysBtn.connect("clicked", (self) => {
        self.label = self.label === "All" ? "Weekdays" : "All"
        alarm.days = self.label
        alarm.nextRingTs = calculateNextRingTs(alarm.time, alarm.days)
        saveAlarms()
    })
    deleteBtn.connect("clicked", () => {
        alarms = alarms.filter(a => a.id !== alarm.id)
        saveAlarms()
        renderAlarmsList()
    })
    
    box.add(timeEntry)
    box.add(daysBtn)
    box.add(noteEntry)
    box.add(enabledSwitch)
    box.add(deleteBtn)
    
    return box
}

function renderAlarmsList() {
    alarmsListBox.get_children().forEach(ch => ch.destroy())
    alarms.forEach(alarm => {
        alarmsListBox.add(AlarmItem(alarm))
    })
    alarmsListBox.show_all()
}

export function toggleAlarmMenu() {
    if (AlarmMenu && AlarmMenu.get_visible()) {
        AlarmMenu.hide()
    } else if (AlarmMenu) {
        loadAlarms()
        renderAlarmsList()
        AlarmMenu.show_all()
    }
}
