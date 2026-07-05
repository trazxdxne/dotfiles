pragma Singleton

import Quickshell

Singleton {
    property bool dark: Config.darkTheme

    readonly property string transparent: "#00000000"
    readonly property string bg: dark ? "#f21e1e2e" : "#eceff4"
    readonly property string surface: dark ? "#313244" : "#e5e9f0"
    readonly property string surfaceHover: dark ? "#45475a" : "#d8dee9"
    readonly property string border: dark ? "#45475a" : "#b8c0cc"
    readonly property string text: dark ? "#cdd6f4" : "#2e3440"
    readonly property string textStrong: dark ? "#f5e0dc" : "#1f2630"
    readonly property string textMuted: dark ? "#a6adc8" : "#5d6778"
    readonly property string placeholder: dark ? "#6c7086" : "#687386"
    readonly property string accent: dark ? "#cba6f7" : "#5e81ac"
    readonly property string accentText: dark ? "#11111b" : "#eceff4"
    readonly property string danger: "#f38ba8"
    readonly property string dangerSurface: dark ? "#33f38ba8" : "#f0d5da"

    property string fontFamily: Config.barFont

    property int panelHeight: Config.barHeight
    readonly property int popupMargin: 18
    readonly property int popupSpacing: 12
    readonly property int rowSpacing: 10
    readonly property int listSpacing: 4
    readonly property int compactSpacing: 2
    readonly property int tightSpacing: 3
    readonly property int sectionSpacing: 14
    readonly property int radius: 0
    readonly property int smallRadius: 0
    readonly property int pillHeight: 24
    readonly property int buttonHeight: 30
    readonly property int chipHeight: 28
    readonly property int workspaceButtonSize: 22
    readonly property int compactButtonHeight: 40
    readonly property int confirmButtonHeight: 48
    readonly property int notificationAccentWidth: 4
    readonly property int notificationAccentRadius: 0
    readonly property int titleFontSize: 18
    readonly property int bodyFontSize: 14
    readonly property int panelFontSize: 13
    readonly property int smallFontSize: 12
    readonly property int tinyFontSize: 10
    readonly property int inputFontSize: 16
    readonly property int iconSize: 24
    readonly property int trayItemSize: 22
    readonly property int trayIconSize: 16
    readonly property int closeButtonSize: 30
}
