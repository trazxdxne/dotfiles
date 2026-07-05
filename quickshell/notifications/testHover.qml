import QtQuick
import Quickshell

ShellWindow {
    width: 200
    height: 200
    color: "red"
    HoverHandler {
        id: hh
        onHoveredChanged: console.log("Hovered:", hovered)
    }
}
