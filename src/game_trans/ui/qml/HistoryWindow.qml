import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic
import QtQuick.Layouts

Window {
    id: win
    visible: backend.historyOpen
    title: "Game Trans – 자막 기록"
    color: Theme.surface
    width: 520
    height: 600
    flags: Qt.Window | Qt.WindowStaysOnTopHint

    onClosing: function(close) {
        close.accepted = false
        backend.historyOpen = false
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Sparkle { width: 20; height: 20 }
            Text {
                text: "최근 자막 기록"
                color: Theme.onSurface
                font.family: Theme.fontFamily
                font.pixelSize: 18
                font.weight: Font.Medium
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                height: 32
                width: 72
                radius: Theme.radiusFull
                color: clearMa.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer
                border.width: 1
                border.color: Theme.outline
                Text {
                    anchors.centerIn: parent
                    text: "비우기"
                    color: Theme.onSurfaceVariant
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
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

            delegate: Rectangle {
                width: list.width
                implicitHeight: itemCol.implicitHeight + 20
                radius: 14
                color: itemMa.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer
                border.width: 1
                border.color: Theme.outline

                ColumnLayout {
                    id: itemCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Rectangle {
                            height: 18
                            width: lTxt.implicitWidth + 12
                            radius: Theme.radiusFull
                            color: Theme.primaryContainer
                            Text {
                                id: lTxt
                                anchors.centerIn: parent
                                text: modelData.lang.toUpperCase()
                                color: Theme.onPrimaryContainer
                                font.pixelSize: 10
                                font.bold: true
                            }
                        }
                        Text {
                            text: modelData.time
                            color: "#8E918F"
                            font.pixelSize: 11
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "클릭하여 복사"
                            color: Theme.primary
                            font.pixelSize: 11
                            visible: itemMa.containsMouse
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: modelData.original
                        wrapMode: Text.WordWrap
                        color: Theme.onSurfaceVariant
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }

                    Text {
                        Layout.fillWidth: true
                        text: modelData.translation
                        wrapMode: Text.WordWrap
                        color: Theme.onSurface
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

            Text {
                anchors.centerIn: parent
                visible: list.count === 0
                text: "아직 수신된 자막이 없어요.\n듣기를 켜고 게임 소리가 나오면 여기에 기록됩니다."
                horizontalAlignment: Text.AlignHCenter
                color: Theme.onSurfaceVariant
                font.family: Theme.fontFamily
                font.pixelSize: 13
            }
        }
    }
}
