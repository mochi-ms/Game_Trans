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
        implicitHeight: 36
        radius: Theme.radiusFull
        color: Theme.scrim
        border.width: backend.editMode ? 1.5 : 1
        border.color: backend.editMode ? Theme.primary : Theme.borderSubtle

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 7

            // Status breathing dot
            Rectangle {
                id: dot
                width: 7
                height: 7
                radius: 3.5
                color: {
                    if (backend.statusLevel === "live") return Theme.success
                    if (backend.statusLevel === "warn") return Theme.warning
                    if (backend.statusLevel === "error") return Theme.error
                    if (backend.statusLevel === "local") return Theme.primary
                    return Theme.textMuted
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
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.labelSize
                font.weight: Font.Medium
            }

            Rectangle {
                width: 1
                height: 13
                color: Theme.outline
            }

            Text {
                text: backend.rpm + "/" + backend.rpmLimit + " · $" + backend.costToday.toFixed(2)
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }

            // Pause / Resume listening
            Rectangle {
                width: 26
                height: 26
                radius: 13
                color: pauseMa.containsMouse ? Theme.navHoverBg : "transparent"
                MonoIcon {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    name: backend.listening ? "pause" : "play"
                    iconColor: backend.listening ? Theme.textSecondary : Theme.success
                }
                MouseArea {
                    id: pauseMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: backend.toggleListening()
                }
            }

            // Open composer (say something)
            Rectangle {
                width: 26
                height: 26
                radius: 13
                color: chatMa.containsMouse ? Theme.navHoverBg : "transparent"
                MonoIcon {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    name: "chat"
                    iconColor: backend.composerOpen ? Theme.primary : Theme.textSecondary
                }
                MouseArea {
                    id: chatMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: backend.toggleComposer()
                }
            }

            // Click-through lock toggle
            Rectangle {
                width: 26
                height: 26
                radius: 13
                color: lockMa.containsMouse ? Theme.navHoverBg : (backend.overlayClickThrough ? Theme.navActiveBg : "transparent")
                MonoIcon {
                    anchors.centerIn: parent
                    width: 13
                    height: 13
                    name: backend.overlayClickThrough ? "lock" : "unlock"
                    iconColor: backend.overlayClickThrough ? Theme.primary : Theme.textSecondary
                }
                MouseArea {
                    id: lockMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: backend.toggleOverlayClickThrough()
                }
            }

            // Full History window
            Rectangle {
                width: 26
                height: 26
                radius: 13
                color: histMa.containsMouse ? Theme.navHoverBg : "transparent"
                MonoIcon {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    name: "history"
                    iconColor: backend.historyOpen ? Theme.primary : Theme.textSecondary
                }
                MouseArea {
                    id: histMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: backend.toggleHistory()
                }
            }

            // Settings
            Rectangle {
                width: 26
                height: 26
                radius: 13
                color: setMa.containsMouse ? Theme.navHoverBg : "transparent"
                MonoIcon {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    name: "settings"
                    iconColor: backend.settingsOpen ? Theme.primary : Theme.textSecondary
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
