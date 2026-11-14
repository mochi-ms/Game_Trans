import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic
import QtQuick.Layouts

Window {
    id: win
    visible: backend.composerOpen
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool
    width: 720
    height: col.implicitHeight + 24
    x: Math.round((Screen.desktopAvailableWidth - width) / 2)
    y: Math.round(Screen.desktopAvailableHeight * 0.42 - height / 2)

    property string currentSource: ""
    property string currentTranslation: ""
    property string currentPronunciation: ""
    property string currentCasual: ""
    property string currentPolite: ""
    property string currentTargetLang: "en"
    property bool hasResult: false
    property bool loading: false
    property var inputHistory: []
    property int historyIdx: -1

    Component.onCompleted: backend.registerInputWindow(win)

    onVisibleChanged: {
        if (visible) {
            focusTimer.restart()
        }
    }

    Timer {
        id: focusTimer
        interval: 30
        onTriggered: {
            win.requestActivate()
            inputField.forceActiveFocus()
        }
    }

    Connections {
        target: backend
        function onFocusInputRequested() {
            win.requestActivate()
            inputField.forceActiveFocus()
        }
        function onOutgoingStarted() {
            win.loading = true
            win.hasResult = true
        }
        function onOutgoingReady(translation, pronunciation, casual, polite, sourceText, targetLang) {
            win.loading = false
            win.hasResult = true
            win.currentTranslation = translation
            win.currentPronunciation = pronunciation
            win.currentCasual = casual
            win.currentPolite = polite
            win.currentSource = sourceText
            win.currentTargetLang = targetLang
        }
        function onOutgoingFailed(message) {
            win.loading = false
            win.hasResult = true
            win.currentTranslation = message
            win.currentPronunciation = ""
            win.currentCasual = ""
            win.currentPolite = ""
        }
    }

    function submit(speakAfter) {
        var txt = inputField.text.trim()
        if (!txt) return
        if (inputHistory.length === 0 || inputHistory[inputHistory.length - 1] !== txt) {
            inputHistory.push(txt)
        }
        historyIdx = inputHistory.length
        backend.translateOutgoing(txt, speakAfter, "")
        inputField.text = ""
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 10

        // Quick phrases strip
        Flickable {
            Layout.fillWidth: true
            height: 36
            contentWidth: phraseRow.implicitWidth
            clip: true
            flickableDirection: Flickable.HorizontalFlick

            Row {
                id: phraseRow
                spacing: 8
                Repeater {
                    model: backend.quickPhrases
                    delegate: Rectangle {
                        height: 32
                        width: chipRow.implicitWidth + 20
                        radius: Theme.radiusFull
                        color: chipMa.containsMouse ? Theme.surfaceContainerHigh : Qt.rgba(30/255, 31/255, 32/255, 0.90)
                        border.width: 1
                        border.color: Theme.outline

                        Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: modelData.emoji + " " + modelData.text
                                color: Theme.onSurface
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }
                            Rectangle {
                                visible: index < 9
                                width: 16
                                height: 16
                                radius: 4
                                color: Theme.surfaceContainerHighest
                                Text {
                                    anchors.centerIn: parent
                                    text: (index + 1).toString()
                                    color: Theme.onSurfaceVariant
                                    font.pixelSize: 10
                                }
                            }
                        }

                        MouseArea {
                            id: chipMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: backend.triggerQuickPhrase(index)
                        }
                    }
                }
            }
        }

        // Translation result card
        Rectangle {
            id: resultCard
            visible: win.hasResult
            Layout.fillWidth: true
            implicitHeight: resCol.implicitHeight + 28
            radius: Theme.radiusCard
            color: Qt.rgba(30/255, 31/255, 32/255, 0.96)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.08)

            ColumnLayout {
                id: resCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Sparkle {
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: 2
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Column {
                            visible: win.loading
                            Layout.fillWidth: true
                            spacing: 8
                            ShimmerBar { width: 420; active: win.loading }
                            ShimmerBar { width: 260; active: win.loading }
                        }

                        Text {
                            visible: !win.loading
                            Layout.fillWidth: true
                            text: win.currentTranslation
                            wrapMode: Text.WordWrap
                            color: Theme.onSurface
                            font.family: Theme.fontFamily
                            font.pixelSize: 21
                            font.weight: Font.DemiBold
                        }

                        Text {
                            visible: !win.loading && win.currentPronunciation.length > 0
                            Layout.fillWidth: true
                            text: win.currentPronunciation
                            wrapMode: Text.WordWrap
                            color: Theme.onSurfaceVariant
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                        }

                        Text {
                            visible: !win.loading && win.currentSource.length > 0
                            Layout.fillWidth: true
                            text: "원문 · " + win.currentSource
                            elide: Text.ElideRight
                            color: "#8E918F"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignTop
                        width: 28
                        height: 28
                        radius: 14
                        color: closeResMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: Theme.onSurfaceVariant
                            font.pixelSize: 13
                        }
                        MouseArea {
                            id: closeResMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.hasResult = false
                        }
                    }
                }

                // Action row
                RowLayout {
                    visible: !win.loading
                    Layout.fillWidth: true
                    Layout.leftMargin: 36
                    spacing: 6

                    // Primary Speak button (Filled Pill)
                    Rectangle {
                        height: 38
                        width: speakRow.implicitWidth + 28
                        radius: Theme.radiusFull
                        color: backend.ttsPlaying ? Theme.primaryContainer : Theme.primary
                        opacity: speakMa.containsMouse ? 0.92 : 1.0

                        Row {
                            id: speakRow
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: backend.ttsPlaying ? "⏹" : "🔊"
                                font.pixelSize: 14
                                color: backend.ttsPlaying ? Theme.onPrimaryContainer : Theme.onPrimary
                            }
                            Text {
                                text: backend.ttsPlaying ? "송출 중 (중지)" : "말하기"
                                color: backend.ttsPlaying ? Theme.onPrimaryContainer : Theme.onPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.Medium
                            }
                        }
                        MouseArea {
                            id: speakMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (backend.ttsPlaying) backend.stopSpeak()
                                else backend.speakText(win.currentTranslation, win.currentTargetLang)
                            }
                        }
                    }

                    // Copy icon button
                    Rectangle {
                        width: 38
                        height: 38
                        radius: 19
                        color: copyMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "📋"
                            font.pixelSize: 14
                        }
                        MouseArea {
                            id: copyMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: backend.copyText(win.currentTranslation)
                        }
                    }

                    // Retry icon button
                    Rectangle {
                        width: 38
                        height: 38
                        radius: 19
                        color: retryMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "↻"
                            color: Theme.onSurfaceVariant
                            font.pixelSize: 18
                        }
                        MouseArea {
                            id: retryMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (win.currentSource.length > 0)
                                    backend.translateOutgoing(win.currentSource, false, "")
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Tone suggestion chips
                    Rectangle {
                        visible: win.currentCasual.length > 0
                        height: 32
                        width: casTxt.implicitWidth + 24
                        radius: Theme.radiusFull
                        color: casMa.containsMouse ? Theme.surfaceContainerHigh : "transparent"
                        border.width: 1
                        border.color: Theme.outline
                        Text {
                            id: casTxt
                            anchors.centerIn: parent
                            text: "더 캐주얼"
                            color: Theme.onSurface
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }
                        MouseArea {
                            id: casMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (win.currentCasual.length > 0)
                                    win.currentTranslation = win.currentCasual
                            }
                        }
                    }

                    Rectangle {
                        visible: win.currentPolite.length > 0
                        height: 32
                        width: polTxt.implicitWidth + 24
                        radius: Theme.radiusFull
                        color: polMa.containsMouse ? Theme.surfaceContainerHigh : "transparent"
                        border.width: 1
                        border.color: Theme.outline
                        Text {
                            id: polTxt
                            anchors.centerIn: parent
                            text: "더 공손"
                            color: Theme.onSurface
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }
                        MouseArea {
                            id: polMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (win.currentPolite.length > 0)
                                    win.currentTranslation = win.currentPolite
                            }
                        }
                    }
                }
            }
        }

        // Main Gemini-style Pill Input Bar with AI Gradient focus border
        Rectangle {
            id: gradientBorder
            Layout.fillWidth: true
            height: 60
            radius: 30
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: inputField.activeFocus ? "#4285F4" : Theme.outline }
                GradientStop { position: 0.5; color: inputField.activeFocus ? "#9B72CB" : Theme.outline }
                GradientStop { position: 1.0; color: inputField.activeFocus ? "#D96570" : Theme.outline }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1.5
                radius: 28.5
                color: Qt.rgba(30/255, 31/255, 32/255, 0.98)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 8
                    spacing: 8

                    Sparkle {
                        width: 22
                        height: 22
                    }

                    TextField {
                        id: inputField
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        placeholderText: "하고 싶은 말을 입력하세요…"
                        placeholderTextColor: "#8E918F"
                        color: Theme.onSurface
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        verticalAlignment: TextInput.AlignVCenter
                        background: Item {}
                        selectByMouse: true

                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                win.submit((event.modifiers & Qt.ControlModifier) !== 0)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Escape) {
                                backend.closeComposer()
                                event.accepted = true
                            } else if (event.key === Qt.Key_Up && win.inputHistory.length > 0) {
                                if (win.historyIdx > 0) win.historyIdx--
                                inputField.text = win.inputHistory[win.historyIdx]
                                event.accepted = true
                            } else if (event.key === Qt.Key_Down && win.inputHistory.length > 0) {
                                if (win.historyIdx < win.inputHistory.length - 1) {
                                    win.historyIdx++
                                    inputField.text = win.inputHistory[win.historyIdx]
                                } else {
                                    win.historyIdx = win.inputHistory.length
                                    inputField.text = ""
                                }
                                event.accepted = true
                            }
                        }
                    }

                    // Tone chip
                    Rectangle {
                        height: 36
                        width: toneTxt.implicitWidth + 22
                        radius: Theme.radiusFull
                        color: toneMa.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                        Text {
                            id: toneTxt
                            anchors.centerIn: parent
                            text: backend.tone === "casual" ? "🎮 캐주얼" : (backend.tone === "polite" ? "🤝 공손" : "💬 기본")
                            color: Theme.onSurface
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }
                        MouseArea {
                            id: toneMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: backend.cycleTone()
                        }
                    }

                    // Target language chip
                    Rectangle {
                        height: 36
                        width: langChipTxt.implicitWidth + 22
                        radius: Theme.radiusFull
                        color: langMa.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                        Text {
                            id: langChipTxt
                            anchors.centerIn: parent
                            text: "🌐 " + backend.effectivePartnerLang.toUpperCase() + (backend.partnerLanguage === "auto" ? " (자동)" : "")
                            color: Theme.primary
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }
                        MouseArea {
                            id: langMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: backend.cyclePartnerLang()
                        }
                    }

                    // Send circle button (Gemini ↑ style)
                    Rectangle {
                        width: 44
                        height: 44
                        radius: 22
                        property bool ready: inputField.text.trim().length > 0
                        color: ready ? Theme.primary : Theme.surfaceContainerHigh

                        Text {
                            anchors.centerIn: parent
                            text: "↑"
                            color: parent.ready ? Theme.onPrimary : "#8E918F"
                            font.pixelSize: 18
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: parent.ready ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: win.submit(false)
                        }
                    }
                }
            }
        }

        // Shortcut hints pill
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            height: 28
            width: hintRow.implicitWidth + 24
            radius: Theme.radiusFull
            color: Theme.scrim

            Row {
                id: hintRow
                anchors.centerIn: parent
                spacing: 14
                Text { text: "Enter 번역"; color: Theme.onSurfaceVariant; font.family: Theme.fontFamily; font.pixelSize: 11 }
                Text { text: "Ctrl+Enter 번역 + 바로 말하기"; color: Theme.onSurfaceVariant; font.family: Theme.fontFamily; font.pixelSize: 11 }
                Text { text: "Esc 게임으로 복귀"; color: Theme.onSurfaceVariant; font.family: Theme.fontFamily; font.pixelSize: 11 }
            }
        }
    }
}
