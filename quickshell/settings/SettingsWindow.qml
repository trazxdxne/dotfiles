import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell
import qs.core

Window {
    id: root
    visible: false
    width: 600
    height: 400
    color: Theme.bg
    title: "Quickshell Settings"
    
    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        border.color: Theme.border
        border.width: 1
        
        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10
            
            // Sidebar for tabs
            Rectangle {
                Layout.preferredWidth: 150
                Layout.fillHeight: true
                color: Theme.surface
                border.color: Theme.border
                border.width: 1
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 5
                    spacing: 5
                    
                    Repeater {
                        model: ["Themes", "Bar", "Clipboard", "Notifications"]
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30
                            color: stackLayout.currentIndex === index ? Theme.accent : Theme.surfaceHover
                            
                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: stackLayout.currentIndex === index ? Theme.accentText : Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.bodyFontSize
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                onClicked: stackLayout.currentIndex = index
                            }
                        }
                    }
                    Item { Layout.fillHeight: true } // Spacer
                }
            }
            
            // Content area
            StackLayout {
                id: stackLayout
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: 0
                
                // Themes Tab
                Item {
                    ColumnLayout {
                        anchors.fill: parent
                        Text { text: "Theme Settings"; color: Theme.text; font.pixelSize: Theme.titleFontSize; font.family: Theme.fontFamily }
                        
                        RowLayout {
                            Text { text: "Dark Mode:"; color: Theme.text; font.family: Theme.fontFamily }
                            CheckBox {
                                checked: Config.darkTheme
                                onCheckedChanged: Config.darkTheme = checked
                            }
                        }
                        
                        RowLayout {
                            Text { text: "Active Theme:"; color: Theme.text; font.family: Theme.fontFamily }
                            TextField {
                                text: Config.activeTheme
                                color: Theme.text
                                onTextChanged: Config.activeTheme = text
                                background: Rectangle { color: Theme.surface; border.color: Theme.border }
                            }
                        }
                        Item { Layout.fillHeight: true }
                    }
                }
                
                // Bar Tab
                Item {
                    ColumnLayout {
                        anchors.fill: parent
                        Text { text: "Bar Settings"; color: Theme.text; font.pixelSize: Theme.titleFontSize; font.family: Theme.fontFamily }
                        
                        RowLayout {
                            Text { text: "Bar Height:"; color: Theme.text; font.family: Theme.fontFamily }
                            SpinBox {
                                value: Config.barHeight
                                to: 100
                                onValueChanged: Config.barHeight = value
                            }
                        }
                        
                        RowLayout {
                            Text { text: "Show Clock:"; color: Theme.text; font.family: Theme.fontFamily }
                            CheckBox { checked: Config.showClock; onCheckedChanged: Config.showClock = checked }
                        }
                        RowLayout {
                            Text { text: "Show Volume:"; color: Theme.text; font.family: Theme.fontFamily }
                            CheckBox { checked: Config.showVolume; onCheckedChanged: Config.showVolume = checked }
                        }
                        RowLayout {
                            Text { text: "Show Battery:"; color: Theme.text; font.family: Theme.fontFamily }
                            CheckBox { checked: Config.showBattery; onCheckedChanged: Config.showBattery = checked }
                        }
                        Item { Layout.fillHeight: true }
                    }
                }
                
                // Clipboard Tab
                Item {
                    ColumnLayout {
                        anchors.fill: parent
                        Text { text: "Clipboard Settings"; color: Theme.text; font.pixelSize: Theme.titleFontSize; font.family: Theme.fontFamily }
                        
                        RowLayout {
                            Text { text: "Max Items:"; color: Theme.text; font.family: Theme.fontFamily }
                            SpinBox {
                                value: Config.clipboardMaxItems
                                to: 1000
                                onValueChanged: Config.clipboardMaxItems = value
                            }
                        }
                        Item { Layout.fillHeight: true }
                    }
                }
                
                // Notifications Tab
                Item {
                    ColumnLayout {
                        anchors.fill: parent
                        Text { text: "Notifications Settings"; color: Theme.text; font.pixelSize: Theme.titleFontSize; font.family: Theme.fontFamily }
                        
                        RowLayout {
                            Text { text: "Timeout (ms):"; color: Theme.text; font.family: Theme.fontFamily }
                            SpinBox {
                                value: Config.notifTimeout
                                to: 60000
                                stepSize: 1000
                                onValueChanged: Config.notifTimeout = value
                            }
                        }
                        
                        RowLayout {
                            Text { text: "Width:"; color: Theme.text; font.family: Theme.fontFamily }
                            SpinBox {
                                value: Config.notifWidth
                                to: 1000
                                onValueChanged: Config.notifWidth = value
                            }
                        }
                        Item { Layout.fillHeight: true }
                    }
                }
            }
        }
    }
}
