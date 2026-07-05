import QtQuick
import QtQuick.Layouts
import qs.core

Item {
    id: root
    Layout.fillWidth: true
    implicitHeight: layout.height + 20

    property string labelText: "Active Theme"
    property string value: "Custom"
    property var themes: ["Custom"]



    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        Text {
            text: root.labelText
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.bodyFontSize
            font.bold: true
        }

        Flow {
            Layout.fillWidth: true
            spacing: 10

            Repeater {
                model: root.themes
                delegate: Rectangle {
                    width: 120
                    height: 80
                    color: root.value === modelData ? Theme.surfaceHover : Theme.surface
                    border.color: root.value === modelData ? Theme.accent : Theme.border
                    border.width: 2
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 5
                        
                        // Fake preview
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: Theme.bg
                            border.color: Theme.border
                            border.width: 1
                            
                            Rectangle {
                                width: parent.width
                                height: 10
                                color: Theme.surfaceHover
                                anchors.top: parent.top
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData
                            color: root.value === modelData ? Theme.accent : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.value = modelData
                    }
                }
            }
        }
    }
}
