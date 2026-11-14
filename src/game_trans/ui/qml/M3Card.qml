import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    property string title: ""
    default property alias content: body.data

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + 16
    radius: Theme.radiusSettingsCard
    color: Theme.surfaceContainer
    border.width: 1
    border.color: Theme.surfaceContainerHighest

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 8
        spacing: 0

        Text {
            visible: root.title.length > 0
            text: root.title
            color: Theme.primary
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.weight: Font.Medium
            Layout.leftMargin: 20
            Layout.topMargin: 8
            Layout.bottomMargin: 6
        }

        ColumnLayout {
            id: body
            Layout.fillWidth: true
            spacing: 0
        }
    }
}
