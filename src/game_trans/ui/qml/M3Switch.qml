import QtQuick

Rectangle {
    id: root
    property bool checked: false
    signal toggled(bool newValue)

    width: 50
    height: 30
    radius: 15
    color: checked ? Theme.primary : Theme.surfaceContainerHighest
    border.width: checked ? 0 : 2
    border.color: "#8E918F"

    Behavior on color { ColorAnimation { duration: 150 } }

    Rectangle {
        width: root.checked ? 22 : 16
        height: width
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? parent.width - width - 4 : 6
        color: root.checked ? Theme.textOnPrimary : "#8E918F"

        Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 140 } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.checked = !root.checked
            root.toggled(root.checked)
        }
    }
}
