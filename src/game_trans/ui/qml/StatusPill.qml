import QtQuick
import QtQuick.Window
import QtQuick.Layouts

Window {
    id: win
    visible: backend.overlayVisible
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool | Qt.WindowDoesNotAcceptFocus
    width: pill.implicitWidth + 16
    height: pill.implicitHeight + 16
    x: Screen.desktopAvailableWidth - width - 20
    y: 16

    Component.onCompleted: backend.registerStatusWindow(win)

    Rectangle {
        id: pill
        anchors.centerIn: parent
        implicitWidth: row.implicitWidth + 24
        implicitHeight: 38
        radius: Theme.radiusFull
        color: Theme.scrim
        border.width: backend.editMode ? 1.5 : 1
        border.color: backend.editMode ? Theme.primary : Qt.rgba(1, 1, 1, 0.10)

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 10

            // Status breathing dot
            Rectangle {
                id: dot
                width: 8
                height: 8
                radius: 4
                color: {
                    if (backend.statusLevel === "live") return Theme.success
                    if (backend.statusLevel === "warn") return Theme.warning
                    if (backend.statusLevel === "error") return Theme.error
                    if (backend.statusLevel === "local") return Theme.primary
                    return Theme.outline
                }

                SequentialAnimation on opacity {
                    running: backend.statusLevel === "live" && !backend.reduceMotion
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.35; duration: 950; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 950; easing.type: Easing.InOutSine }
                }
            }

            Text {
                text: backend.statusText
                color: Theme.onSurface
                font.family: Theme.fontFamily
                font.pixelSize: Theme.labelSize
                font.weight: Font.Medium
            }

            Rectangle {
                width: 1
                height: 14
                color: Theme.outline
            }

            Text {
                text: backend.rpm + "/" + backend.rpmLimit + " RPM · 오늘 $" + backend.costToday.toFixed(2)
                color: Theme.onSurfaceVariant
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }

            // Pause / Resume button
            Rectangle {
                width: 26
                height: 26
                radius: 13
                color: pauseMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: backend.listening ? "⏸" : "▶"
                    color: backend.listening ? Theme.onSurfaceVariant : Theme.success
                    font.pixelSize: 12
                }
                MouseArea {
                    id: pauseMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: backend.toggleListening()
                }
            }

            // History button
            Rectangle {
                width: 26
                height: 26
                radius: 13
                color: histMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "≡"
                    color: Theme.onSurfaceVariant
                    font.pixelSize: 15
                    font.bold: true
                }
                MouseArea {
                    id: histMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: backend.toggleHistory()
                }
            }

            // Settings button
            Rectangle {
                width: 26
                height: 26
                radius: 13
                color: setMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "⚙"
                    color: Theme.onSurfaceVariant
                    font.pixelSize: 14
                }
                MouseArea {
                    id: setMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: backend.openSettings()
                }
            }
        }
    }
}
