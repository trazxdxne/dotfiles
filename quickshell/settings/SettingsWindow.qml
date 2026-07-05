import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io
import qs.core

Window {
    id: root
    visible: false
    width: 700
    height: 500
    color: Theme.bg
    title: "Quickshell Settings"
    
    property var configSchema: []
    property int currentCategoryIndex: 0

    Process {
        id: schemaLoader
        command: ["sh", "-c", "cat ~/dotfiles/quickshell/config_schema.json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var obj = JSON.parse(this.text);
                    root.configSchema = obj.categories || [];
                } catch(e) {
                    console.warn("Failed to parse config schema:", e);
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        border.color: Theme.border
        border.width: 1
        
        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10
            
            // Sidebar for categories
            Rectangle {
                Layout.preferredWidth: 150
                Layout.fillHeight: true
                color: Theme.surface
                border.color: Theme.border
                border.width: 1
                
                ListView {
                    anchors.fill: parent
                    anchors.margins: 5
                    model: root.configSchema
                    delegate: Rectangle {
                        width: ListView.view.width
                        height: 40
                        color: root.currentCategoryIndex === index ? Theme.accent : Theme.surfaceHover
                        
                        Text {
                            anchors.centerIn: parent
                            text: modelData.name
                            color: root.currentCategoryIndex === index ? Theme.accentText : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.bodyFontSize
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.currentCategoryIndex = index
                        }
                    }
                }
            }
            
            // Content area
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                
                ScrollView {
                    anchors.fill: parent
                    contentWidth: availableWidth
                    clip: true
                    
                    ColumnLayout {
                        width: parent.width - 20
                        spacing: 15
                        
                        Text {
                            text: root.configSchema[root.currentCategoryIndex] ? root.configSchema[root.currentCategoryIndex].name : ""
                            color: Theme.text
                            font.pixelSize: Theme.titleFontSize
                            font.family: Theme.fontFamily
                            font.bold: true
                            Layout.bottomMargin: 10
                        }
                        
                        Repeater {
                            model: root.configSchema[root.currentCategoryIndex] ? root.configSchema[root.currentCategoryIndex].properties : []
                            
                            delegate: Loader {
                                Layout.fillWidth: true
                                
                                sourceComponent: {
                                    switch (modelData.type) {
                                        case "number": return numberComponent;
                                        case "boolean": return booleanComponent;
                                        case "string": return stringComponent;
                                        case "theme": return themeComponent;
                                        default: return stringComponent;
                                    }
                                }
                                
                                Component {
                                    id: numberComponent
                                    SettingNumber {
                                        labelText: modelData.title
                                        minValue: modelData.min !== undefined ? modelData.min : 0
                                        maxValue: modelData.max !== undefined ? modelData.max : 100
                                        stepValue: modelData.step !== undefined ? modelData.step : 1
                                        property bool _ready: false
                                        Component.onCompleted: {
                                            value = Config[modelData.id] !== undefined ? Config[modelData.id] : 0
                                            _ready = true
                                        }
                                        onValueChanged: { if (_ready) Config[modelData.id] = value; }
                                    }
                                }
                                
                                Component {
                                    id: booleanComponent
                                    RowLayout {
                                        spacing: 10
                                        Text {
                                            Layout.preferredWidth: 150
                                            text: modelData.title
                                            color: Theme.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.bodyFontSize
                                        }
                                        CheckBox {
                                            property bool _ready: false
                                            Component.onCompleted: {
                                                checked = Config[modelData.id] !== undefined ? Config[modelData.id] : false
                                                _ready = true
                                            }
                                            onCheckedChanged: { if (_ready) Config[modelData.id] = checked; }
                                            
                                            indicator: Rectangle {
                                                implicitWidth: 20
                                                implicitHeight: 20
                                                color: Theme.surface
                                                border.color: Theme.border
                                                Rectangle {
                                                    anchors.centerIn: parent
                                                    width: 10
                                                    height: 10
                                                    color: Theme.accent
                                                    visible: parent.parent.checked
                                                }
                                            }
                                        }
                                        Item { Layout.fillWidth: true }
                                    }
                                }
                                
                                Component {
                                    id: stringComponent
                                    RowLayout {
                                        spacing: 10
                                        Text {
                                            Layout.preferredWidth: 150
                                            text: modelData.title
                                            color: Theme.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.bodyFontSize
                                        }
                                        TextField {
                                            Layout.fillWidth: true
                                            property bool _ready: false
                                            Component.onCompleted: {
                                                text = Config[modelData.id] !== undefined ? Config[modelData.id] : ""
                                                _ready = true
                                            }
                                            color: Theme.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.bodyFontSize
                                            background: Rectangle {
                                                color: Theme.surface
                                                border.color: Theme.border
                                                border.width: 1
                                            }
                                            onTextChanged: { if (_ready) Config[modelData.id] = text; }
                                        }
                                    }
                                }
                                
                                Component {
                                    id: themeComponent
                                    SettingTheme {
                                        labelText: modelData.title
                                        property bool _ready: false
                                        Component.onCompleted: {
                                            value = Config[modelData.id] !== undefined ? Config[modelData.id] : "Mocha"
                                            _ready = true
                                        }
                                        onValueChanged: { if (_ready) Config[modelData.id] = value; }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
