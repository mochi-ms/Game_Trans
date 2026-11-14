import QtQuick
import QtQuick.Controls.Basic

// Sleek Material 3 dark slider.
Slider {
    id: root
    implicitWidth: 220
    implicitHeight: 28

    background: Rectangle {
        x: root.leftPadding
        y: root.topPadding + root.availableHeight / 2 - height / 2
        implicitWidth: 200
        implicitHeight: 4
        width: root.availableWidth
        height: implicitHeight
        radius: 2
        color: Theme.surfaceContainerHighest

        Rectangle {
            width: root.visualPosition * parent.width
            height: parent.height
            radius: 2
            color: Theme.primary
        }
    }

    handle: Rectangle {
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: 16
        height: 16
        radius: 8
        color: Theme.primary
        border.width: root.pressed ? 3 : 0
        border.color: Qt.rgba(168/255, 199/255, 250/255, 0.35)
    }
}
