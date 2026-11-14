import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic
import QtQuick.Layouts

Window {
    id: win
    visible: backend.overlayVisible && (captionModel.count > 0 || backend.listening || backend.editMode || backend.toastText.length > 0)
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool | Qt.WindowDoesNotAcceptFocus
    width: Math.min(410, Math.max(320, Screen.desktopAvailableWidth - 40))
    height: Math.min(Screen.desktopAvailableHeight - 88, Math.max(88, rootCol.implicitHeight + 8))

    property bool feedCollapsed: false
    property int unseenNewCount: 0
    readonly property int maxStoredCaptions: 60
    readonly property int estCardH: backend.showOriginal
        ? Math.round(backend.captionFontSize * 2.15 + 52)
        : Math.round(backend.captionFontSize * 1.45 + 46)
    readonly property int maxFeedH: Math.round(
        Math.min(Screen.desktopAvailableHeight * 0.56, Math.max(110, backend.maxCaptions * estCardH))
    )
    readonly property bool hasOverflow: !feedCollapsed && captionModel.count > 0 && feedList.contentHeight > maxFeedH + 6
    readonly property bool scrolledDown: feedList.contentY > 14

    function formatNow() {
        var d = new Date()
        var hh = ("0" + d.getHours()).slice(-2)
        var mm = ("0" + d.getMinutes()).slice(-2)
        return hh + ":" + mm
    }

    function updatePosition() {
        var sw = Screen.desktopAvailableWidth
        var sh = Screen.desktopAvailableHeight
        var baseX = sw - width - 28
        var baseY = 66
        if (backend.overlayPosition === "top-left") {
            baseX = 24
            baseY = 24
        } else if (backend.overlayPosition === "bottom-right") {
            baseX = sw - width - 28
            baseY = sh - height - 28
        } else if (backend.overlayPosition === "bottom-left") {
            baseX = 24
            baseY = sh - height - 28
        } else if (backend.overlayPosition === "bottom-center") {
            baseX = (sw - width) / 2
            baseY = sh - height - 28
        }
        x = Math.round(Math.max(0, Math.min(sw - width, baseX + backend.overlayOffsetX)))
        y = Math.round(Math.max(0, Math.min(sh - height, baseY + backend.overlayOffsetY)))
    }

    function enforceFeedCap() {
        while (captionModel.count > maxStoredCaptions) {
            captionModel.remove(captionModel.count - 1)
        }
    }

    onWidthChanged: updatePosition()
    onHeightChanged: updatePosition()

    Component.onCompleted: {
        updatePosition()
        backend.registerCaptionWindow(win)
    }

    ListModel { id: captionModel }

    Connections {
        target: backend
        function onOverlayLayoutChanged() { win.updatePosition() }
        function onHistoryCleared() {
            captionModel.clear()
            win.unseenNewCount = 0
        }
        function onCaptionStarted(segId) {
            var keepView = win.scrolledDown
            captionModel.insert(0, {
                segId: segId,
                status: "listening",
                isMine: false,
                lang: "",
                original: "",
                translation: "",
                confidence: 1.0,
                timeText: win.formatNow()
            })
            win.enforceFeedCap()
            if (!keepView) {
                feedList.positionViewAtBeginning()
                win.unseenNewCount = 0
            }
        }
        function onCaptionTranslating(segId) {
            for (var i = 0; i < captionModel.count; i++) {
                if (captionModel.get(i).segId === segId) {
                    captionModel.setProperty(i, "status", "translating")
                    break
                }
            }
        }
        function onCaptionReady(segId, lang, orig, trans, conf) {
            var timeNow = win.formatNow()
            for (var i = 0; i < captionModel.count; i++) {
                if (captionModel.get(i).segId === segId) {
                    captionModel.set(i, {
                        segId: segId,
                        status: "ready",
                        isMine: false,
                        lang: lang,
                        original: orig,
                        translation: trans,
                        confidence: conf,
                        timeText: timeNow
                    })
                    if (win.scrolledDown) {
                        win.unseenNewCount += 1
                    } else {
                        feedList.positionViewAtBeginning()
                    }
                    return
                }
            }
            var keepView = win.scrolledDown
            captionModel.insert(0, {
                segId: segId,
                status: "ready",
                isMine: false,
                lang: lang,
                original: orig,
                translation: trans,
                confidence: conf,
                timeText: timeNow
            })
            win.enforceFeedCap()
            if (keepView) {
                win.unseenNewCount += 1
            } else {
                feedList.positionViewAtBeginning()
                win.unseenNewCount = 0
            }
        }
        function onOutgoingReady(translation, pronunciation, casual, polite, sourceText, targetLang) {
            if (!backend.showOutgoingInFeed || translation.length === 0) return
            var keepView = win.scrolledDown
            captionModel.insert(0, {
                segId: 0,
                status: "ready",
                isMine: true,
                lang: targetLang || backend.effectivePartnerLang,
                original: sourceText,
                translation: translation,
                confidence: 1.0,
                timeText: win.formatNow()
            })
            win.enforceFeedCap()
            if (keepView) {
                win.unseenNewCount += 1
            } else {
                feedList.positionViewAtBeginning()
                win.unseenNewCount = 0
            }
        }
        function onCaptionDismissed(segId) {
            for (var i = 0; i < captionModel.count; i++) {
                if (captionModel.get(i).segId === segId) {
                    captionModel.remove(i)
                    break
                }
            }
        }
    }

    ColumnLayout {
        id: rootCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 4
        spacing: 8

        // Optional edit-mode banner pill
        Rectangle {
            visible: backend.editMode
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            radius: Theme.radiusFull
            color: Theme.primaryContainer
            border.width: 1
            border.color: Theme.primary

            Row {
                anchors.centerIn: parent
                spacing: 6
                MonoIcon {
                    width: 14
                    height: 14
                    name: "drag"
                    iconColor: Theme.textOnPrimaryContainer
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "편집 모드 · 드래그 이동 (" + backend.hotkeyEditOverlay + " 고정)"
                    color: Theme.textOnPrimaryContainer
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }
            }
        }

        // Main Top-Right Live Feed Container
        Rectangle {
            id: dockCard
            visible: captionModel.count > 0 || backend.listening || backend.editMode
            Layout.fillWidth: true
            Layout.preferredHeight: dockCol.implicitHeight
            radius: 16
            color: Qt.rgba(16 / 255, 17 / 255, 20 / 255, Math.min(0.95, Math.max(0.58, backend.overlayOpacity)))
            border.width: backend.editMode ? 1.5 : 1
            border.color: backend.editMode ? Theme.primary : Theme.borderSubtle
            clip: true

            ColumnLayout {
                id: dockCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: 0

                // Slim Feed Header
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    color: Qt.rgba(255, 255, 255, 0.025)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        spacing: 6

                        Sparkle {
                            width: 14
                            height: 14
                        }

                        Text {
                            text: "실시간 자막"
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }

                        Rectangle {
                            visible: captionModel.count > 0
                            Layout.preferredHeight: 18
                            Layout.preferredWidth: cntTxt.implicitWidth + 10
                            radius: 9
                            color: Theme.navActiveBg
                            Text {
                                id: cntTxt
                                anchors.centerIn: parent
                                text: captionModel.count + "건"
                                color: Theme.primary
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                            }
                        }

                        Rectangle {
                            visible: backend.overlayClickThrough
                            Layout.preferredHeight: 18
                            Layout.preferredWidth: lockLbl.implicitWidth + 10
                            radius: 9
                            color: Theme.surfaceContainerHigh
                            Text {
                                id: lockLbl
                                anchors.centerIn: parent
                                text: "클릭통과"
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Drag / Edit position button
                        Rectangle {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            radius: 12
                            color: dragBtnMa.containsMouse || backend.editMode ? Theme.navActiveBg : "transparent"
                            MonoIcon {
                                anchors.centerIn: parent
                                width: 13
                                height: 13
                                name: "drag"
                                iconColor: backend.editMode ? Theme.primary : Theme.textSecondary
                            }
                            MouseArea {
                                id: dragBtnMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: backend.toggleEditMode()
                            }
                        }

                        // Clear feed button
                        Rectangle {
                            visible: captionModel.count > 0
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            radius: 12
                            color: clearBtnMa.containsMouse ? Theme.navHoverBg : "transparent"
                            MonoIcon {
                                anchors.centerIn: parent
                                width: 13
                                height: 13
                                name: "trash"
                                iconColor: Theme.textSecondary
                            }
                            MouseArea {
                                id: clearBtnMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: backend.clearHistory()
                            }
                        }

                        // Collapse / Expand feed button
                        Rectangle {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            radius: 12
                            color: foldBtnMa.containsMouse ? Theme.navHoverBg : "transparent"
                            MonoIcon {
                                anchors.centerIn: parent
                                width: 13
                                height: 13
                                name: win.feedCollapsed ? "chevron_down" : "chevron_up"
                                iconColor: Theme.textSecondary
                            }
                            MouseArea {
                                id: foldBtnMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.feedCollapsed = !win.feedCollapsed
                            }
                        }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 1
                        color: Theme.borderSubtle
                        visible: !win.feedCollapsed
                    }
                }

                // Feed body
                Item {
                    visible: !win.feedCollapsed
                    Layout.fillWidth: true
                    Layout.preferredHeight: captionModel.count === 0
                        ? 54
                        : Math.min(win.maxFeedH, Math.max(60, feedList.contentHeight + 16))
                    clip: true

                    // Waiting placeholder when listening cleanly starts
                    RowLayout {
                        visible: captionModel.count === 0
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 10

                        Row {
                            spacing: 4
                            Repeater {
                                model: 3
                                Rectangle {
                                    width: 3
                                    height: 12
                                    radius: 1.5
                                    color: backend.listening ? Theme.success : Theme.textMuted
                                    anchors.verticalCenter: parent.verticalCenter
                                    SequentialAnimation on scale {
                                        running: backend.listening && !backend.reduceMotion
                                        loops: Animation.Infinite
                                        PauseAnimation { duration: index * 140 }
                                        NumberAnimation { to: 1.35; duration: 360 }
                                        NumberAnimation { to: 0.65; duration: 360 }
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: backend.listening
                                ? "대화 소리를 기다리는 중… 최신 번역이 위쪽에 쌓입니다"
                                : "듣기 일시정지됨 · 상단 재생 버튼으로 시작하세요"
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                    }

                    // Live Feed List (index 0 = newest at TOP; scroll down for earlier captions)
                    ListView {
                        id: feedList
                        visible: captionModel.count > 0
                        anchors.fill: parent
                        anchors.margins: 8
                        clip: true
                        spacing: 7
                        boundsBehavior: Flickable.StopAtBounds
                        model: captionModel

                        onContentYChanged: {
                            if (contentY <= 8 && win.unseenNewCount > 0) {
                                win.unseenNewCount = 0
                            }
                        }

                        ScrollBar.vertical: ScrollBar {
                            policy: win.hasOverflow ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                            contentItem: Rectangle {
                                implicitWidth: 5
                                radius: 2.5
                                color: Theme.outline
                            }
                            background: Item {}
                        }

                        delegate: Rectangle {
                            id: card
                            width: feedList.width - (win.hasOverflow ? 8 : 0)
                            height: cardCol.implicitHeight + 18
                            property bool isNewest: index === 0
                            radius: 12
                            color: isNewest
                                ? Qt.rgba(26 / 255, 29 / 255, 36 / 255, 0.94)
                                : (cardMa.containsMouse
                                    ? Qt.rgba(30 / 255, 33 / 255, 40 / 255, 0.88)
                                    : Qt.rgba(20 / 255, 22 / 255, 26 / 255, 0.78))
                            border.width: 1
                            border.color: isNewest
                                ? Qt.rgba(168 / 255, 199 / 255, 250 / 255, 0.34)
                                : Theme.borderSubtle

                            // Left Gemini accent bar on newest item at top
                            Rectangle {
                                visible: card.isNewest
                                width: 3
                                height: Math.max(18, parent.height - 18)
                                radius: 1.5
                                anchors.left: parent.left
                                anchors.leftMargin: 5
                                anchors.verticalCenter: parent.verticalCenter
                                color: isMine
                                    ? Theme.success
                                    : (status === "ready" ? Theme.primary : Theme.success)
                            }

                            ColumnLayout {
                                id: cardCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.topMargin: 9
                                anchors.leftMargin: card.isNewest ? 14 : 11
                                anchors.rightMargin: 11
                                spacing: 4

                                // State 1: Listening
                                Row {
                                    visible: status === "listening"
                                    spacing: 5
                                    Repeater {
                                        model: 4
                                        Rectangle {
                                            width: 3
                                            height: 12
                                            radius: 1.5
                                            color: Theme.success
                                            anchors.verticalCenter: parent.verticalCenter
                                            SequentialAnimation on scale {
                                                running: status === "listening" && !backend.reduceMotion
                                                loops: Animation.Infinite
                                                PauseAnimation { duration: index * 110 }
                                                NumberAnimation { to: 1.4; duration: 300 }
                                                NumberAnimation { to: 0.6; duration: 300 }
                                            }
                                        }
                                    }
                                    Text {
                                        text: "  음성 인식 중…"
                                        color: Theme.textSecondary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                // State 2: Translating shimmer
                                Column {
                                    visible: status === "translating"
                                    Layout.fillWidth: true
                                    spacing: 6
                                    ShimmerBar { width: Math.max(120, cardCol.width * 0.84); active: status === "translating" }
                                    ShimmerBar { width: Math.max(80, cardCol.width * 0.52); active: status === "translating" }
                                }

                                // State 3: Metadata row ([EN -> KO] + time + copy)
                                RowLayout {
                                    visible: status === "ready"
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Rectangle {
                                        visible: lang.length > 0
                                        Layout.preferredWidth: langTxt.implicitWidth + 10
                                        Layout.preferredHeight: 17
                                        radius: 8.5
                                        color: isMine
                                            ? Qt.rgba(129 / 255, 201 / 255, 149 / 255, 0.22)
                                            : (card.isNewest ? Theme.primaryContainer : Theme.surfaceContainerHigh)
                                        Text {
                                            id: langTxt
                                            anchors.centerIn: parent
                                            text: isMine
                                                ? ("나 → " + lang.toUpperCase())
                                                : (lang.toUpperCase() + " → " + backend.myLanguage.toUpperCase())
                                            color: isMine
                                                ? Theme.success
                                                : (card.isNewest ? Theme.textOnPrimaryContainer : Theme.textSecondary)
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            font.weight: Font.DemiBold
                                        }
                                    }

                                    Text {
                                        text: timeText
                                        color: Theme.textMuted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                    }

                                    Item { Layout.fillWidth: true }

                                    MonoIcon {
                                        visible: cardMa.containsMouse
                                        width: 12
                                        height: 12
                                        name: "copy"
                                        iconColor: Theme.primary
                                    }
                                }

                                // Original transcript
                                Text {
                                    visible: status === "ready" && backend.showOriginal && original.length > 0
                                    Layout.fillWidth: true
                                    text: original
                                    wrapMode: Text.WordWrap
                                    color: card.isNewest ? Theme.textSecondary : Theme.textMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Math.max(11, backend.captionFontSize - 6)
                                }

                                // Translated text (crisp, zero dark outline)
                                Text {
                                    visible: status === "ready"
                                    Layout.fillWidth: true
                                    text: translation + (confidence < 0.5 ? " ?" : "")
                                    wrapMode: Text.WordWrap
                                    color: card.isNewest ? "#F4F6FA" : Theme.textPrimary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: backend.captionFontSize
                                    font.weight: card.isNewest ? Font.DemiBold : Font.Medium
                                }
                            }

                            MouseArea {
                                id: cardMa
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: status === "ready" && !backend.editMode
                                cursorShape: Qt.PointingHandCursor
                                onClicked: backend.copyText(translation + (original.length > 0 ? " (" + original + ")" : ""))
                            }
                        }
                    }

                    // Jump-to-latest pill when scrolled down and new captions arrive
                    Rectangle {
                        visible: win.scrolledDown && win.unseenNewCount > 0
                        anchors.top: parent.top
                        anchors.topMargin: 8
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 26
                        width: jumpRow.implicitWidth + 20
                        radius: 13
                        color: Theme.primary
                        Row {
                            id: jumpRow
                            anchors.centerIn: parent
                            spacing: 4
                            MonoIcon {
                                width: 12
                                height: 12
                                name: "arrow_up"
                                iconColor: Theme.textOnPrimary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "새 자막 " + win.unseenNewCount + "건"
                                color: Theme.textOnPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                feedList.positionViewAtBeginning()
                                win.unseenNewCount = 0
                            }
                        }
                    }
                }

                // Subtle scroll footer when more items exist below viewport
                Rectangle {
                    visible: win.hasOverflow && !win.scrolledDown
                    Layout.fillWidth: true
                    Layout.preferredHeight: 22
                    color: Qt.rgba(255, 255, 255, 0.02)
                    Text {
                        anchors.centerIn: parent
                        text: "↓ 아래로 스크롤해 이전 대화 보기"
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }
                }
            }

            // Full-dock drag overlay active only in Edit Mode
            MouseArea {
                anchors.fill: parent
                enabled: backend.editMode
                cursorShape: Qt.SizeAllCursor
                property point pressPos: Qt.point(0, 0)
                onPressed: function(mouse) { pressPos = Qt.point(mouse.x, mouse.y) }
                onPositionChanged: function(mouse) {
                    if (!pressed) return
                    win.x += mouse.x - pressPos.x
                    win.y += mouse.y - pressPos.y
                }
                onReleased: backend.saveOverlayWindowPos(
                    win.x,
                    win.y,
                    Screen.desktopAvailableWidth,
                    Screen.desktopAvailableHeight,
                    win.width,
                    win.height
                )
            }
        }

        // Toast banner pill
        Rectangle {
            visible: backend.toastText.length > 0
            Layout.alignment: Qt.AlignRight
            Layout.preferredHeight: 34
            Layout.preferredWidth: toastLbl.implicitWidth + 26
            radius: Theme.radiusFull
            color: Theme.surfaceContainerHigh
            border.width: 1
            border.color: Theme.outline
            Text {
                id: toastLbl
                anchors.centerIn: parent
                text: backend.toastText
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
            }
        }
    }
}
