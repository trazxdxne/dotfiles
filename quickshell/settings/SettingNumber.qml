import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import qs.core

Item {
    id: root
    height: 40
    Layout.fillWidth: true

    property string labelText: "Label"
    property int minValue: 0
    property int maxValue: 100
    property int stepValue: 1
    property int value: 0

    RowLayout {
        anchors.fill: parent
        anchors.margins: 5
        spacing: 10

        Text {
            Layout.preferredWidth: 150
            text: root.labelText
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.bodyFontSize
        }

        Slider {
            id: slider
            Layout.fillWidth: true
            from: root.minValue
            to: root.maxValue
            stepSize: root.stepValue
            value: root.value
            onValueChanged: {
                if (root.value !== value) {
                    root.value = value
                }
            }

            background: Rectangle {
                x: slider.leftPadding
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                implicitWidth: 200
                implicitHeight: 4
                width: slider.availableWidth
                height: implicitHeight
                color: Theme.surfaceHover
                
                Rectangle {
                    width: slider.visualPosition * parent.width
                    height: parent.height
                    color: Theme.accent
                }
            }

            handle: Rectangle {
                x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                implicitWidth: 16
                implicitHeight: 16
                color: Theme.accent
                border.color: Theme.bg
                border.width: 2
            }
        }

        TextField {
            Layout.preferredWidth: 60
            text: slider.value.toString()
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.bodyFontSize
            horizontalAlignment: Text.AlignRight
            
            background: Rectangle {
                color: Theme.surface
                border.color: Theme.border
                border.width: 1
            }

            onEditingFinished: {
                var val = parseInt(text)
                if (!isNaN(val)) {
                    if (val < root.minValue) val = root.minValue
                    if (val > root.maxValue) val = root.maxValue
                    slider.value = val
                } else {
                    text = slider.value.toString()
                }
            }
        }
    }
}
