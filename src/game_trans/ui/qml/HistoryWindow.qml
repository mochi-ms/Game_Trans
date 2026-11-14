import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic
import QtQuick.Layouts

Window {
    id: win
    visible: backend.historyOpen
    title: "Game Trans – 자막 기록"
    color: Theme.surface
    width: 540
    height: 620
    minimumWidth: 420
    minimumHeight: 420
    flags: Qt.Window | Qt.WindowStaysOnTopHint

    Component.onCompleted: backend.registerDarkWindow(win)

    onClosing: function(close) {
        close.accepted = false
        backend.historyOpen = false
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Sparkle { width: 20; height: 20 }
            Text {
                text: "최근 자막 기록"
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                height: 32
                width: clearRow.implicitWidth + 22
                radius: Theme.radiusFull
                color: clearMa.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer
                border.width: 1
                border.color: Theme.outline
                Row {
                    id: clearRow
                    anchors.centerIn: parent
                    spacing: 6
                    MonoIcon {
                        width: 13
                        height: 13
                        name: "trash"
                        iconColor: Theme.textSecondary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "비우기"
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                }
                MouseArea {
                    id: clearMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: backend.clearHistory()
                }
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: backend.captionHistory

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle {
                    implicitWidth: 6
                    radius: 3
                    color: Theme.surfaceContainerHighest
                }
                background: Item {}
            }

            delegate: Rectangle {
                width: list.width
                implicitHeight: itemCol.implicitHeight + 22
                radius: 14
                color: itemMa.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer
                border.width: 1
                border.color: itemMa.containsMouse ? Theme.outline : Theme.borderSubtle

                ColumnLayout {
                    id: itemCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 14
                    spacing: 5

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Rectangle {
                            height: 20
                            width: lTxt.implicitWidth + 12
                            radius: Theme.radiusFull
                            color: Theme.primaryContainer
                            Text {
                                id: lTxt
                                anchors.centerIn: parent
                                text: modelData.lang.toUpperCase()
                                color: Theme.textOnPrimaryContainer
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                            }
                        }
                        Text {
                            text: modelData.time
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }
                        Item { Layout.fillWidth: true }
                        Row {
                            visible: itemMa.containsMouse
                            spacing: 4
                            MonoIcon {
                                width: 13
                                height: 13
                                name: "copy"
                                iconColor: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "복사"
                                color: Theme.primary
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Medium
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: modelData.original
                        wrapMode: Text.WordWrap
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }

                    Text {
                        Layout.fillWidth: true
                        text: modelData.translation
                        wrapMode: Text.WordWrap
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        font.weight: Font.Medium
                    }
                }

                MouseArea {
                    id: itemMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: backend.copyText(modelData.translation + " (" + modelData.original + ")")
                }
            }

            Column {
                anchors.centerIn: parent
                visible: list.count === 0
                spacing: 10
                MonoIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 28
                    height: 28
                    name: "history"
                    iconColor: Theme.textMuted
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "아직 수신된 자막이 없습니다.\n듣기를 켜고 게임 소리가 나오면 여기에 기록됩니다."
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }
            }
        }
    }
}
