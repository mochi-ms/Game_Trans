import QtQuick
import QtQuick.Window
import QtQuick.Layouts

Window {
    id: win
    visible: backend.overlayVisible && (captionModel.count > 0 || backend.editMode || backend.toastText.length > 0)
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool | Qt.WindowDoesNotAcceptFocus
    width: Math.min(860, Screen.width * 0.78)
    height: 360

    function updatePosition() {
        var baseX = (Screen.desktopAvailableWidth - width) / 2
        var baseY = Screen.desktopAvailableHeight - height - 32
        if (backend.overlayPosition === "bottom-left") {
            baseX = 28
        } else if (backend.overlayPosition === "top-center") {
            baseY = 64
        }
        x = Math.max(0, Math.min(Screen.desktopAvailableWidth - width, baseX + backend.overlayOffsetX))
        y = Math.max(0, Math.min(Screen.desktopAvailableHeight - height, baseY + backend.overlayOffsetY))
    }

    Component.onCompleted: {
        updatePosition()
        backend.registerCaptionWindow(win)
    }

    Connections {
        target: backend
        function onOverlayLayoutChanged() { win.updatePosition() }
        function onCaptionStarted(segId) {
            captionModel.append({
                segId: segId,
                state: "listening",
                lang: "",
                original: "",
                translation: "",
                confidence: 1.0,
                ageFactor: 1.0,
                createdAt: Date.now()
            })
            trimCaptions()
        }
        function onCaptionTranslating(segId) {
            for (var i = 0; i < captionModel.count; i++) {
                if (captionModel.get(i).segId === segId) {
                    captionModel.setProperty(i, "state", "translating")
                    break
                }
            }
        }
        function onCaptionReady(segId, lang, orig, trans, conf) {
            for (var i = 0; i < captionModel.count; i++) {
                if (captionModel.get(i).segId === segId) {
                    captionModel.set(i, {
                        segId: segId,
                        state: "ready",
                        lang: lang,
                        original: orig,
                        translation: trans,
                        confidence: conf,
                        ageFactor: 1.0,
                        createdAt: Date.now()
                    })
                    return
                }
            }
            captionModel.append({
                segId: segId,
                state: "ready",
                lang: lang,
                original: orig,
                translation: trans,
                confidence: conf,
                ageFactor: 1.0,
                createdAt: Date.now()
            })
            trimCaptions()
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

    function trimCaptions() {
        var maxCount = Math.max(1, backend.maxCaptions)
        while (captionModel.count > maxCount) {
            captionModel.remove(0)
        }
    }

    ListModel { id: captionModel }

    // Periodically expire finished captions after captionDurationS
    Timer {
        interval: 400
        running: captionModel.count > 0
        repeat: true
        onTriggered: {
            var now = Date.now()
            var ttl = Math.max(2, backend.captionDurationS) * 1000
            for (var i = captionModel.count - 1; i >= 0; i--) {
                var item = captionModel.get(i)
                if (item.state === "ready" && (now - item.createdAt) >= ttl) {
                    captionModel.remove(i)
                }
            }
        }
    }

    // Edit-mode drag area
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusCard
        color: backend.editMode ? Qt.rgba(168/255, 199/255, 250/255, 0.10) : "transparent"
        border.width: backend.editMode ? 2 : 0
        border.color: Theme.primary

        MouseArea {
            anchors.fill: parent
            enabled: backend.editMode
            cursorShape: Qt.SizeAllCursor
            property point pressPos: Qt.point(0, 0)
            onPressed: function(mouse) { pressPos = Qt.point(mouse.x, mouse.y) }
            onPositionChanged: function(mouse) {
                if (!pressed) return
                var dx = mouse.x - pressPos.x
                var dy = mouse.y - pressPos.y
                win.x += dx
                win.y += dy
            }
            onReleased: backend.saveOverlayWindowPos(win.x, win.y, Screen.desktopAvailableWidth, Screen.desktopAvailableHeight, win.width, win.height)
        }

        // Edit mode banner
        Rectangle {
            visible: backend.editMode
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 10
            height: 32
            width: editLabel.implicitWidth + 24
            radius: Theme.radiusFull
            color: Theme.primaryContainer
            Text {
                id: editLabel
                anchors.centerIn: parent
                text: "✦ 편집 모드 · 자막 영역을 드래그해서 옮기세요 (Ctrl+Shift+E 로 고정)"
                color: Theme.onPrimaryContainer
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
            }
        }
    }

    // Toast banner
    Rectangle {
        visible: backend.toastText.length > 0
        anchors.bottom: stackCol.top
        anchors.bottomMargin: 10
        anchors.horizontalCenter: parent.horizontalCenter
        height: 38
        width: toastLbl.implicitWidth + 28
        radius: 12
        color: "#E3E3E3"
        Text {
            id: toastLbl
            anchors.centerIn: parent
            text: backend.toastText
            color: "#1F1F1F"
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.weight: Font.Medium
        }
    }

    // Caption card stack (anchored bottom)
    Column {
        id: stackCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 8
        spacing: 8

        Repeater {
            model: captionModel

            delegate: Rectangle {
                id: card
                width: stackCol.width
                implicitHeight: cardCol.implicitHeight + 24
                radius: Theme.radiusCard
                color: Qt.rgba(19/255, 19/255, 20/255, backend.overlayOpacity)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.08)
                opacity: {
                    var base = (index < captionModel.count - 1) ? 0.62 : 1.0
                    if (state === "ready" && confidence < 0.5) base *= 0.72
                    return base
                }

                Behavior on opacity {
                    enabled: !backend.reduceMotion
                    NumberAnimation { duration: 220 }
                }

                ColumnLayout {
                    id: cardCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 14
                    spacing: 6

                    // State 1: Listening (3 animated dots)
                    Row {
                        visible: state === "listening"
                        spacing: 6
                        Repeater {
                            model: 4
                            Rectangle {
                                width: 4
                                height: 14
                                radius: 2
                                color: Theme.onSurfaceVariant
                                SequentialAnimation on scale {
                                    running: state === "listening" && !backend.reduceMotion
                                    loops: Animation.Infinite
                                    PauseAnimation { duration: index * 120 }
                                    NumberAnimation { to: 1.5; duration: 320 }
                                    NumberAnimation { to: 0.6; duration: 320 }
                                }
                            }
                        }
                        Text {
                            text: "  듣는 중…"
                            color: Theme.onSurfaceVariant
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                        }
                    }

                    // State 2: Translating (Gemini shimmer)
                    Column {
                        visible: state === "translating"
                        Layout.fillWidth: true
                        spacing: 8
                        ShimmerBar { width: cardCol.width * 0.85; active: state === "translating" }
                        ShimmerBar { width: cardCol.width * 0.55; active: state === "translating" }
                    }

                    // State 3: Ready
                    RowLayout {
                        visible: state === "ready" && (backend.showOriginal || lang.length > 0)
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            visible: lang.length > 0
                            implicitWidth: langTxt.implicitWidth + 14
                            height: 20
                            radius: Theme.radiusFull
                            color: Theme.primaryContainer
                            Text {
                                id: langTxt
                                anchors.centerIn: parent
                                text: lang.toUpperCase() + " → " + backend.myLanguage.toUpperCase()
                                color: Theme.onPrimaryContainer
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }
                        }

                        Text {
                            visible: backend.showOriginal
                            Layout.fillWidth: true
                            text: original
                            elide: Text.ElideRight
                            color: Theme.onSurfaceVariant
                            font.family: Theme.fontFamily
                            font.pixelSize: Math.max(12, backend.captionFontSize - 7)
                        }
                    }

                    Text {
                        visible: state === "ready"
                        Layout.fillWidth: true
                        text: translation + (confidence < 0.5 ? " ?" : "")
                        wrapMode: Text.WordWrap
                        color: Theme.onSurface
                        font.family: Theme.fontFamily
                        font.pixelSize: backend.captionFontSize
                        font.weight: Font.DemiBold
                        style: Text.Outline
                        styleColor: Qt.rgba(0, 0, 0, 0.55)
                    }
                }
            }
        }
    }
}
