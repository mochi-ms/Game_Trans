import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic
import QtQuick.Layouts

Window {
    id: win
    visible: backend.composerOpen
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool
    width: 740
    height: col.implicitHeight + 24
    x: Math.round((Screen.desktopAvailableWidth - width) / 2)
    y: Math.round(Screen.desktopAvailableHeight * 0.28)

    property string currentSource: ""
    property string currentTranslation: ""
    property string currentPronunciation: ""
    property string currentCasual: ""
    property string currentPolite: ""
    property string currentTargetLang: "en"
    property bool hasResult: false
    property bool loading: false
    property bool copyDone: false
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

    Timer {
        id: copyResetTimer
        interval: 1400
        onTriggered: win.copyDone = false
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

        // Quick phrases strip (fixed 32px height so input bar never shifts vertically)
        Flickable {
            Layout.fillWidth: true
            height: 32
            contentWidth: phraseRow.implicitWidth
            clip: true
            flickableDirection: Flickable.HorizontalFlick

            Row {
                id: phraseRow
                spacing: 8
                Repeater {
                    model: backend.quickPhrases
                    delegate: Rectangle {
                        height: 30
                        width: chipRow.implicitWidth + 18
                        radius: Theme.radiusFull
                        color: chipMa.containsMouse ? Theme.surfaceContainerHigh : Theme.scrim
                        border.width: 1
                        border.color: chipMa.containsMouse ? Theme.outline : Theme.borderSubtle

                        Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: 6
                            Rectangle {
                                visible: index < 9
                                width: 16
                                height: 16
                                radius: 4
                                color: Theme.surfaceContainerHighest
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    anchors.centerIn: parent
                                    text: (index + 1).toString()
                                    color: Theme.textSecondary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                }
                            }
                            Text {
                                text: modelData.text
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                anchors.verticalCenter: parent.verticalCenter
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

        // Main Gemini-style Pill Input Bar with AI Gradient focus border
        Rectangle {
            id: gradientBorder
            Layout.fillWidth: true
            height: 58
            radius: 29
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: inputField.activeFocus ? "#4285F4" : Theme.outline }
                GradientStop { position: 0.5; color: inputField.activeFocus ? "#9B72CB" : Theme.outline }
                GradientStop { position: 1.0; color: inputField.activeFocus ? "#D96570" : Theme.outline }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1.5
                radius: 27.5
                color: Qt.rgba(22/255, 23/255, 27/255, 0.98)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 8
                    spacing: 8

                    Sparkle {
                        width: 20
                        height: 20
                    }

                    TextField {
                        id: inputField
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        placeholderText: "하고 싶은 말을 입력하세요…"
                        placeholderTextColor: Theme.textMuted
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
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

                    // Tone chip (monochrome icon + label)
                    Rectangle {
                        height: 34
                        width: toneRow.implicitWidth + 20
                        radius: Theme.radiusFull
                        color: toneMa.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                        border.width: 1
                        border.color: Theme.borderSubtle
                        Row {
                            id: toneRow
                            anchors.centerIn: parent
                            spacing: 6
                            MonoIcon {
                                width: 14
                                height: 14
                                name: "tone"
                                iconColor: Theme.textSecondary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: backend.tone === "casual" ? "캐주얼" : (backend.tone === "polite" ? "공손" : "기본")
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea {
                            id: toneMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: backend.cycleTone()
                        }
                    }

                    // Target language chip (monochrome globe icon + lang)
                    Rectangle {
                        height: 34
                        width: langRow.implicitWidth + 20
                        radius: Theme.radiusFull
                        color: langMa.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                        border.width: 1
                        border.color: Theme.borderSubtle
                        Row {
                            id: langRow
                            anchors.centerIn: parent
                            spacing: 6
                            MonoIcon {
                                width: 14
                                height: 14
                                name: "globe"
                                iconColor: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: backend.effectivePartnerLang.toUpperCase() + (backend.partnerLanguage === "auto" ? " 자동" : "")
                                color: Theme.primary
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                anchors.verticalCenter: parent.verticalCenter
                            }
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
                        width: 42
                        height: 42
                        radius: 21
                        property bool ready: inputField.text.trim().length > 0
                        color: ready ? Theme.primary : Theme.surfaceContainerHigh
                        MonoIcon {
                            anchors.centerIn: parent
                            width: 17
                            height: 17
                            name: "arrow_up"
                            strokeWidth: 2.0
                            iconColor: parent.ready ? Theme.textOnPrimary : Theme.textMuted
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

        // Translation result card expands cleanly BELOW input bar
        Rectangle {
            id: resultCard
            visible: win.hasResult
            Layout.fillWidth: true
            implicitHeight: resCol.implicitHeight + 28
            radius: Theme.radiusCard
            color: Theme.cardGlass
            border.width: 1
            border.color: Theme.borderSubtle

            ColumnLayout {
                id: resCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Sparkle {
                        width: 20
                        height: 20
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: 3
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5

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
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: 20
                            font.weight: Font.DemiBold
                        }

                        Text {
                            visible: !win.loading && win.currentPronunciation.length > 0
                            Layout.fillWidth: true
                            text: win.currentPronunciation
                            wrapMode: Text.WordWrap
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                        }

                        Text {
                            visible: !win.loading && win.currentSource.length > 0
                            Layout.fillWidth: true
                            text: "원문 · " + win.currentSource
                            elide: Text.ElideRight
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignTop
                        width: 28
                        height: 28
                        radius: 14
                        color: closeResMa.containsMouse ? Theme.navHoverBg : "transparent"
                        MonoIcon {
                            anchors.centerIn: parent
                            width: 14
                            height: 14
                            name: "close"
                            iconColor: Theme.textSecondary
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
                    Layout.leftMargin: 32
                    spacing: 6

                    // Primary Speak button (Filled Pill)
                    Rectangle {
                        height: 36
                        width: speakRow.implicitWidth + 26
                        radius: Theme.radiusFull
                        color: backend.ttsPlaying ? Theme.primaryContainer : Theme.primary
                        opacity: speakMa.containsMouse ? 0.92 : 1.0

                        Row {
                            id: speakRow
                            anchors.centerIn: parent
                            spacing: 7
                            MonoIcon {
                                width: 15
                                height: 15
                                name: backend.ttsPlaying ? "stop" : "volume"
                                iconColor: backend.ttsPlaying ? Theme.textOnPrimaryContainer : Theme.textOnPrimary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: backend.ttsPlaying ? "송출 중지" : "음성으로 말하기"
                                color: backend.ttsPlaying ? Theme.textOnPrimaryContainer : Theme.textOnPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                anchors.verticalCenter: parent.verticalCenter
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
                        height: 36
                        width: win.copyDone ? copyRow.implicitWidth + 20 : 36
                        radius: 18
                        color: copyMa.containsMouse ? Theme.surfaceContainerHigh : "transparent"
                        Row {
                            id: copyRow
                            anchors.centerIn: parent
                            spacing: 5
                            MonoIcon {
                                width: 15
                                height: 15
                                name: win.copyDone ? "check" : "copy"
                                iconColor: win.copyDone ? Theme.success : Theme.textSecondary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                visible: win.copyDone
                                text: "복사됨"
                                color: Theme.success
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }
                        }
                        MouseArea {
                            id: copyMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                backend.copyText(win.currentTranslation)
                                win.copyDone = true
                                copyResetTimer.restart()
                            }
                        }
                    }

                    // Retry icon button
                    Rectangle {
                        width: 36
                        height: 36
                        radius: 18
                        color: retryMa.containsMouse ? Theme.surfaceContainerHigh : "transparent"
                        MonoIcon {
                            anchors.centerIn: parent
                            width: 15
                            height: 15
                            name: "refresh"
                            iconColor: Theme.textSecondary
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
                        width: casTxt.implicitWidth + 22
                        radius: Theme.radiusFull
                        color: casMa.containsMouse ? Theme.surfaceContainerHigh : "transparent"
                        border.width: 1
                        border.color: Theme.outline
                        Text {
                            id: casTxt
                            anchors.centerIn: parent
                            text: "더 캐주얼"
                            color: Theme.textPrimary
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
                        width: polTxt.implicitWidth + 22
                        radius: Theme.radiusFull
                        color: polMa.containsMouse ? Theme.surfaceContainerHigh : "transparent"
                        border.width: 1
                        border.color: Theme.outline
                        Text {
                            id: polTxt
                            anchors.centerIn: parent
                            text: "더 공손"
                            color: Theme.textPrimary
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

        // Shortcut hints pill
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            height: 26
            width: hintRow.implicitWidth + 24
            radius: Theme.radiusFull
            color: Theme.scrim
            border.width: 1
            border.color: Theme.borderSubtle

            Row {
                id: hintRow
                anchors.centerIn: parent
                spacing: 14
                Text { text: "Enter 번역"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: 11 }
                Text { text: "Ctrl+Enter 번역 + 바로 송출"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: 11 }
                Text { text: "Esc 게임으로 복귀"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: 11 }
            }
        }
    }
}
