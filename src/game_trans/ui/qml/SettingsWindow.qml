import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic
import QtQuick.Layouts

Window {
    id: win
    visible: backend.settingsOpen
    title: "Game Trans – 설정"
    color: Theme.surface
    width: 1060
    height: 790
    minimumWidth: 900
    minimumHeight: 620
    flags: Qt.Window

    property int section: backend.hasApiKey ? 1 : 0
    property string apiKeyInput: ""
    property bool keyTesting: false
    property string keyTestMsg: ""
    property bool keyTestOk: false

    Component.onCompleted: backend.registerDarkWindow(win)

    onClosing: function(close) {
        close.accepted = false
        backend.settingsOpen = false
    }

    function findDeviceIndex(list, target, offset) {
        if (!target || !list) return 0
        var lower = target.toLowerCase()
        for (var i = 0; i < list.length; i++) {
            var item = (list[i] || "").toLowerCase()
            if (item === lower || item.indexOf(lower) !== -1) {
                return i + (offset || 0)
            }
        }
        return 0
    }

    Connections {
        target: backend
        function onApiKeyTestResult(ok, msg) {
            win.keyTesting = false
            win.keyTestOk = ok
            win.keyTestMsg = msg
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // Antigravity / Gemini style Left Sidebar
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 228
            color: Theme.sidebarSurface
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 4

                // Brand header
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    Layout.rightMargin: 6
                    Layout.topMargin: 6
                    Layout.bottomMargin: 12
                    spacing: 9

                    Sparkle { width: 20; height: 20 }

                    Text {
                        Layout.fillWidth: true
                        text: "Game Trans"
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        height: 20
                        width: verTxt.implicitWidth + 12
                        radius: 6
                        color: Theme.navActiveBg
                        Text {
                            id: verTxt
                            anchors.centerIn: parent
                            text: "Gemini"
                            color: Theme.primary
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Medium
                        }
                    }
                }

                // Navigation items
                Repeater {
                    model: [
                        { icon: "key", label: "연결 · API" },
                        { icon: "translate", label: "번역 · AI" },
                        { icon: "headphones", label: "오디오 캡처" },
                        { icon: "captions", label: "자막 오버레이" },
                        { icon: "volume", label: "음성 송출" },
                        { icon: "bolt", label: "빠른 문구 · 용어" },
                        { icon: "chart", label: "사용량 · 단축키" }
                    ]
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        height: 40
                        radius: 10
                        property bool active: win.section === index
                        color: active ? Theme.navActiveBg : (navMa.containsMouse ? Theme.navHoverBg : "transparent")
                        border.width: active ? 1 : 0
                        border.color: active ? Qt.rgba(168/255, 199/255, 250/255, 0.24) : "transparent"

                        // Left accent indicator pill
                        Rectangle {
                            visible: parent.active
                            width: 3
                            height: 18
                            radius: 1.5
                            color: Theme.primary
                            anchors.left: parent.left
                            anchors.leftMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 12
                            spacing: 11

                            MonoIcon {
                                width: 17
                                height: 17
                                name: modelData.icon
                                iconColor: active ? Theme.primary : Theme.textSecondary
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.label
                                color: active ? Theme.textPrimary : Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.weight: active ? Font.Medium : Font.Normal
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: navMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.section = index
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                // Live status summary pill
                Rectangle {
                    Layout.fillWidth: true
                    height: 36
                    radius: 10
                    color: Theme.surfaceContainer
                    border.width: 1
                    border.color: Theme.borderSubtle

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 10
                        spacing: 8
                        Rectangle {
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
                        }
                        Text {
                            Layout.fillWidth: true
                            text: backend.statusText
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }
                }

                Item { height: 4 }

                // Hide to tray button
                Rectangle {
                    Layout.fillWidth: true
                    height: 36
                    radius: 10
                    color: hideMa.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer
                    border.width: 1
                    border.color: Theme.outline

                    Row {
                        anchors.centerIn: parent
                        spacing: 7
                        MonoIcon {
                            width: 15
                            height: 15
                            name: "sidebar_hide"
                            iconColor: Theme.textSecondary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "트레이로 숨기기"
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: hideMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: backend.settingsOpen = false
                    }
                }
            }
        }

        // Hairline divider
        Rectangle { Layout.fillHeight: true; width: 1; color: Theme.borderSubtle }

        // Main scrollable content
        ScrollView {
            id: mainScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle {
                    implicitWidth: 6
                    radius: 3
                    color: Theme.surfaceContainerHighest
                }
                background: Item {}
            }

            ColumnLayout {
                width: Math.min(mainScroll.availableWidth - 64, 760)
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 28
                spacing: 16

                // ===================== SECTION 0: API & ONBOARDING =====================
                ColumnLayout {
                    visible: win.section === 0
                    Layout.fillWidth: true
                    spacing: 14

                    Column {
                        Layout.fillWidth: true
                        spacing: 4
                        Text {
                            text: "Google AI Studio 연결"
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: 22
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: "AI Studio API 키를 연결하세요. 키는 파일에 남지 않고 Windows 자격 증명 관리자에만 저장됩니다."
                            wrapMode: Text.WordWrap
                            width: parent.width
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                        }
                    }

                    M3Card {
                        title: "API 키"
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.margins: 18
                            spacing: 14

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                MonoIcon {
                                    width: 15
                                    height: 15
                                    name: backend.hasApiKey ? "check" : "warning"
                                    iconColor: backend.hasApiKey ? Theme.success : Theme.warning
                                }
                                Text {
                                    text: backend.hasApiKey ? ("저장된 키: " + backend.maskedApiKey) : "저장된 API 키가 없습니다"
                                    color: backend.hasApiKey ? Theme.success : Theme.warning
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                }
                                Item { Layout.fillWidth: true }
                                Rectangle {
                                    height: 34
                                    width: aiBtnRow.implicitWidth + 24
                                    radius: Theme.radiusFull
                                    color: aiLinkMa.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                                    border.width: 1
                                    border.color: Theme.outline
                                    Row {
                                        id: aiBtnRow
                                        anchors.centerIn: parent
                                        spacing: 6
                                        MonoIcon {
                                            width: 14
                                            height: 14
                                            name: "key"
                                            iconColor: Theme.primary
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: "AI Studio 키 발급"
                                            color: Theme.primary
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            font.weight: Font.Medium
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        MonoIcon {
                                            width: 13
                                            height: 13
                                            name: "external"
                                            iconColor: Theme.primary
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                    MouseArea {
                                        id: aiLinkMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Qt.openUrlExternally("https://aistudio.google.com/apikey")
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 42
                                    radius: 10
                                    color: Theme.surface
                                    border.width: 1
                                    border.color: keyField.activeFocus ? Theme.primary : Theme.outline
                                    TextField {
                                        id: keyField
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        echoMode: TextInput.Password
                                        placeholderText: "AIza... API 키를 붙여넣으세요"
                                        placeholderTextColor: Theme.textMuted
                                        color: Theme.textPrimary
                                        selectionColor: Theme.primaryContainer
                                        selectedTextColor: Theme.textPrimary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 13
                                        verticalAlignment: TextInput.AlignVCenter
                                        background: Item {}
                                        onTextChanged: win.apiKeyInput = text
                                    }
                                }
                                Rectangle {
                                    height: 42
                                    width: saveKeyTxt.implicitWidth + 32
                                    radius: Theme.radiusFull
                                    color: Theme.primary
                                    opacity: win.keyTesting ? 0.6 : (saveKeyMa.containsMouse ? 0.92 : 1.0)
                                    Text {
                                        id: saveKeyTxt
                                        anchors.centerIn: parent
                                        text: win.keyTesting ? "테스트 중…" : "연결 테스트 & 저장"
                                        color: Theme.textOnPrimary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                    }
                                    MouseArea {
                                        id: saveKeyMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        enabled: !win.keyTesting
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            win.keyTesting = true
                                            win.keyTestMsg = ""
                                            backend.saveAndTestApiKey(win.apiKeyInput)
                                        }
                                    }
                                }
                            }

                            Row {
                                visible: win.keyTestMsg.length > 0
                                spacing: 6
                                MonoIcon {
                                    width: 15
                                    height: 15
                                    name: win.keyTestOk ? "check" : "warning"
                                    iconColor: win.keyTestOk ? Theme.success : Theme.error
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: win.keyTestMsg
                                    color: win.keyTestOk ? Theme.success : Theme.error
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                }
                            }
                        }
                    }

                    M3Card {
                        title: "요금제 한도 프리셋 (Google AI Pro 월 $10 크레딧)"
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.margins: 18
                            spacing: 12
                            Text {
                                text: "Gemini 웹/앱 구독과 API 한도는 별개입니다. Google AI Pro 혜택(월 $10 API 크레딧)을 연결하면 Tier 1 한도로 끊김 없이 사용할 수 있습니다."
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                                color: Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                            }
                            RowLayout {
                                spacing: 10
                                Rectangle {
                                    height: 36
                                    width: p1Txt.implicitWidth + 24
                                    radius: Theme.radiusFull
                                    color: backend.rpmLimit <= 15 ? Theme.primaryContainer : Theme.surfaceContainerHigh
                                    border.width: 1
                                    border.color: backend.rpmLimit <= 15 ? Theme.primary : Theme.outline
                                    Text {
                                        id: p1Txt
                                        anchors.centerIn: parent
                                        text: "무료 티어 안전 모드 (10 RPM)"
                                        color: backend.rpmLimit <= 15 ? Theme.textOnPrimaryContainer : Theme.textPrimary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: backend.setRpmLimit(10)
                                    }
                                }
                                Rectangle {
                                    height: 36
                                    width: p2Txt.implicitWidth + 24
                                    radius: Theme.radiusFull
                                    color: backend.rpmLimit >= 100 ? Theme.primaryContainer : Theme.surfaceContainerHigh
                                    border.width: 1
                                    border.color: backend.rpmLimit >= 100 ? Theme.primary : Theme.outline
                                    Text {
                                        id: p2Txt
                                        anchors.centerIn: parent
                                        text: "Pro $10 크레딧 / Tier 1 (300 RPM)"
                                        color: backend.rpmLimit >= 100 ? Theme.textOnPrimaryContainer : Theme.textPrimary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: backend.setRpmLimit(300)
                                    }
                                }
                            }
                        }
                    }
                }

                // ===================== SECTION 1: TRANSLATION & AI =====================
                ColumnLayout {
                    visible: win.section === 1
                    Layout.fillWidth: true
                    spacing: 14

                    Column {
                        Layout.fillWidth: true
                        spacing: 4
                        Text { text: "번역 & AI 설정"; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: 22; font.weight: Font.DemiBold }
                        Text { text: "사용할 Gemini 모델과 언어 쌍, 발음 표시 및 한도 절약 모드를 설정합니다."; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: 13 }
                    }

                    M3Card {
                        title: "모델 & 언어"
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.margins: 18
                            spacing: 16

                            RowLayout {
                                Layout.fillWidth: true
                                Column {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text { text: "Gemini 모델"; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Medium }
                                    Text { text: "기본: gemini-3.5-flash-lite (빠르고 저렴함)"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: 12 }
                                }
                                M3ComboBox {
                                    id: modelCombo
                                    editable: true
                                    model: ["gemini-3.5-flash-lite", "gemini-3.5-flash", "gemini-2.5-flash-lite"]
                                    editText: backend.aiModel
                                    currentIndex: Math.max(0, model.indexOf(backend.aiModel))
                                    implicitWidth: 230
                                    onActivated: backend.setAiModel(currentText)
                                    onAccepted: backend.setAiModel(editText)
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Column {
                                    Layout.fillWidth: true
                                    Text { text: "내 언어 (자막 표시 언어)"; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Medium }
                                }
                                M3ComboBox {
                                    model: ["ko", "en", "ja", "zh", "es"]
                                    currentIndex: Math.max(0, model.indexOf(backend.myLanguage))
                                    implicitWidth: 140
                                    onActivated: backend.setMyLanguage(currentText)
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Column {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text { text: "상대 언어 (내가 말할 때 번역 대상)"; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Medium }
                                    Text { text: "auto는 최근 들린 상대 언어를 자동 추적합니다"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: 12 }
                                }
                                M3ComboBox {
                                    model: ["auto", "en", "ja", "zh", "es", "pt", "fr", "de", "ru", "id", "th", "vi"]
                                    currentIndex: Math.max(0, model.indexOf(backend.partnerLanguage))
                                    implicitWidth: 140
                                    onActivated: backend.setPartnerLanguage(currentText)
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 14
                                Column {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text { width: parent.width; wrapMode: Text.WordWrap; text: "한글 발음 표기"; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Medium }
                                    Text { width: parent.width; wrapMode: Text.WordWrap; text: "번역문 아래에 읽는 법(발음)을 함께 표시"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: 12 }
                                }
                                M3Switch {
                                    checked: backend.showPronunciation
                                    onToggled: function(v) { backend.setShowPronunciation(v) }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 14
                                Column {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text { width: parent.width; wrapMode: Text.WordWrap; text: "로컬 STT 모드 (faster-whisper)"; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Medium }
                                    Text { width: parent.width; wrapMode: Text.WordWrap; text: "켜면 오디오 대신 텍스트만 Gemini로 번역 (한도 극소화 · [local] 옵션 패키지 필요)"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: 12 }
                                }
                                M3Switch {
                                    checked: backend.aiMode === "local"
                                    onToggled: function(v) { backend.setAiMode(v ? "local" : "cloud") }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 14
                                Column {
                                    Layout.fillWidth: true
                                    Text { width: parent.width; wrapMode: Text.WordWrap; text: "429 한도 초과 시 자동으로 로컬 모드 전환"; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Medium }
                                }
                                M3Switch {
                                    checked: backend.fallbackToLocal
                                    onToggled: function(v) { backend.setFallbackToLocal(v) }
                                }
                            }
                        }
                    }
                }

                // ===================== SECTION 2: AUDIO CAPTURE =====================
                ColumnLayout {
                    visible: win.section === 2
                    Layout.fillWidth: true
                    spacing: 14

                    Column {
                        Layout.fillWidth: true
                        spacing: 4
                        Text { text: "오디오 캡처 (듣기)"; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: 22; font.weight: Font.DemiBold }
                        Text { text: "게임 프로세스 소리만 분리해 캡처하고 말소리 구간(VAD)을 검출합니다."; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: 13 }
                    }

                    M3Card {
                        title: "캡처 대상 & 필터"
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.margins: 18
                            spacing: 16

                            RowLayout {
                                Layout.fillWidth: true
                                Column {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text { text: "캡처 방식"; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Medium }
                                    Text { text: "process: 로블록스 소리만 분리 · device: PC 전체 소리"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: 12 }
                                }
                                M3ComboBox {
                                    model: ["process", "device"]
                                    currentIndex: Math.max(0, model.indexOf(backend.captureMode))
                                    implicitWidth: 160
                                    onActivated: backend.setCaptureMode(currentText)
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 14
                                Column {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text { width: parent.width; wrapMode: Text.WordWrap; text: "대상 프로세스 이름"; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Medium }
                                    Text { width: parent.width; wrapMode: Text.WordWrap; text: "쉼표로 여러 개 지정 가능 (기본: RobloxPlayerBeta.exe)"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: 12 }
                                }
                                Rectangle {
                                    implicitWidth: 250
                                    height: 38
                                    radius: 10
                                    color: Theme.surface
                                    border.width: 1
                                    border.color: procField.activeFocus ? Theme.primary : Theme.outline
                                    TextField {
                                        id: procField
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        text: backend.targetProcessesText
                                        placeholderText: "예: RobloxPlayerBeta.exe"
                                        color: Theme.textPrimary
                                        placeholderTextColor: Theme.textMuted
                                        selectionColor: Theme.primaryContainer
                                        selectedTextColor: Theme.textPrimary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 13
                                        verticalAlignment: TextInput.AlignVCenter
                                        background: Item {}
                                        onEditingFinished: backend.setTargetProcessesText(text)
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 14
                                Column {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text { width: parent.width; wrapMode: Text.WordWrap; text: "실행 중인 앱에서 선택"; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Medium }
                                    Text { width: parent.width; wrapMode: Text.WordWrap; text: "직접 입력 없이 현재 실행 중인 게임·디스코드 프로세스를 추가합니다"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: 12 }
                                }
                                M3ComboBox {
                                    id: runningProcCombo
                                    model: backend.runningProcesses.length > 0 ? backend.runningProcesses : ["(실행 중인 앱 없음)"]
                                    implicitWidth: 210
                                }
                                Rectangle {
                                    height: 36
                                    width: addProcTxt.implicitWidth + 22
                                    radius: Theme.radiusFull
                                    color: addProcMa.containsMouse ? Theme.primaryContainer : Theme.surfaceContainerHigh
                                    border.width: 1
                                    border.color: Theme.outline
                                    Text {
                                        id: addProcTxt
                                        anchors.centerIn: parent
                                        text: "+ 추가"
                                        color: Theme.textPrimary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                    }
                                    MouseArea {
                                        id: addProcMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (backend.runningProcesses.length > 0 && runningProcCombo.currentText.indexOf(".exe") !== -1) {
                                                backend.addTargetProcess(runningProcCombo.currentText)
                                            }
                                        }
                                    }
                                }
                                Rectangle {
                                    height: 36
                                    width: 36
                                    radius: 18
                                    color: refProcMa.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                                    border.width: 1
                                    border.color: Theme.outline
                                    MonoIcon { anchors.centerIn: parent; width: 14; height: 14; name: "refresh"; iconColor: Theme.textSecondary }
                                    MouseArea {
                                        id: refProcMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: backend.refreshRunningProcesses()
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 14
                                Column {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text { width: parent.width; wrapMode: Text.WordWrap; text: "게임 BGM/효과음 억제 (300–3400Hz 음성 대역 강조)"; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Medium }
                                }
                                M3Switch {
                                    checked: backend.bgmSuppression
                                    onToggled: function(v) { backend.setBgmSuppression(v) }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 14
                                Column {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text { width: parent.width; wrapMode: Text.WordWrap; text: "문장 끊기 (VAD 응답 속도)"; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Medium }
                                    Text { width: parent.width; wrapMode: Text.WordWrap; text: "짧은 콜아웃 위주라면 '빠름', 긴 대화가 잘린다면 '문장 단위'를 선택하세요"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: 12 }
                                }
                                Row {
                                    spacing: 8
                                    Repeater {
                                        model: [
                                            { id: "fast", label: "빠름 (280ms)" },
                                            { id: "balanced", label: "균형 (450ms)" },
                                            { id: "sentence", label: "문장 (750ms)" }
                                        ]
                                        delegate: Rectangle {
                                            height: 34
                                            width: vadPillTxt.implicitWidth + 20
                                            radius: Theme.radiusFull
                                            color: backend.vadPreset === modelData.id ? Theme.primaryContainer : Theme.surfaceContainerHigh
                                            border.width: 1
                                            border.color: backend.vadPreset === modelData.id ? Theme.primary : Theme.outline
                                            Text {
                                                id: vadPillTxt
                                                anchors.centerIn: parent
                                                text: modelData.label
                                                color: backend.vadPreset === modelData.id ? Theme.textOnPrimaryContainer : Theme.textPrimary
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 12
                                                font.weight: Font.Medium
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: backend.setVadPreset(modelData.id)
                                            }
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 14
                                Column {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Text { text: "실시간 입력 레벨 (" + backend.vadBackend + " VAD)"; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Medium }
                                    Rectangle {
                                        width: 300
                                        height: 8
                                        radius: 4
                                        color: Theme.surfaceContainerHighest
                                        Rectangle {
                                            width: parent.width * Math.min(1.0, backend.audioLevel)
                                            height: parent.height
                                            radius: 4
                                            color: backend.audioLevel > 0.25 ? Theme.success : Theme.primary
                                            Behavior on width { NumberAnimation { duration: 80 } }
                                        }
                                    }
                                }
                                Rectangle {
                                    height: 36
                                    width: listenRow.implicitWidth + 26
                                    radius: Theme.radiusFull
                                    color: backend.listening ? Theme.primaryContainer : Theme.primary
                                    border.width: backend.listening ? 1 : 0
                                    border.color: Theme.primary
                                    Row {
                                        id: listenRow
                                        anchors.centerIn: parent
                                        spacing: 7
                                        MonoIcon {
                                            width: 14
                                            height: 14
                                            name: backend.listening ? "pause" : "play"
                                            iconColor: backend.listening ? Theme.textOnPrimaryContainer : Theme.textOnPrimary
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: backend.listening ? "듣기 일시정지" : "지금 듣기 시작"
                                            color: backend.listening ? Theme.textOnPrimaryContainer : Theme.textOnPrimary
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            font.weight: Font.Medium
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: backend.toggleListening()
                                    }
                                }
                            }
                        }
                    }
                }

                // ===================== SECTION 3: OVERLAY =====================
                ColumnLayout {
                    visible: win.section === 3
                    Layout.fillWidth: true
                    spacing: 14

                    Column {
                        Layout.fillWidth: true
                        spacing: 4
                        Text { text: "자막 오버레이"; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: 22; font.weight: Font.DemiBold }
                        Text { text: "우측 상단 상태 바 아래에 최신순으로 쌓이는 스크롤형 실시간 자막을 설정합니다."; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: 13 }
                    }

                    M3Card {
                        title: "미리보기 & 실시간 피드 스타일"
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.margins: 16
                            spacing: 12

                            // Top-right feed miniature preview
                            Rectangle {
                                Layout.fillWidth: true
                                height: 150
                                radius: 12
                                clip: true
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "#233952" }
                                    GradientStop { position: 0.62; color: "#3A5D80" }
                                    GradientStop { position: 0.63; color: "#274B2D" }
                                    GradientStop { position: 1.0; color: "#1B3420" }
                                }

                                // Mini StatusPill top-right
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.topMargin: 10
                                    anchors.rightMargin: 14
                                    width: 148
                                    height: 20
                                    radius: 10
                                    color: Theme.scrim
                                    border.width: 1
                                    border.color: Theme.borderSubtle
                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Rectangle { width: 5; height: 5; radius: 2.5; color: Theme.success; anchors.verticalCenter: parent.verticalCenter }
                                        Text { text: "Live · EN→KO"; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: 10 }
                                    }
                                }

                                // Mini docked top-right feed card
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.topMargin: 34
                                    anchors.rightMargin: 14
                                    width: 280
                                    height: 106
                                    radius: 12
                                    color: Qt.rgba(16/255, 17/255, 20/255, Math.min(0.95, Math.max(0.58, backend.overlayOpacity)))
                                    border.width: 1
                                    border.color: Theme.borderSubtle

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 6

                                        // Newest item at top (highlighted)
                                        Rectangle {
                                            width: parent.width
                                            height: prevNewestCol.implicitHeight + 14
                                            radius: 9
                                            color: Qt.rgba(26/255, 29/255, 36/255, 0.94)
                                            border.width: 1
                                            border.color: Qt.rgba(168/255, 199/255, 250/255, 0.34)
                                            Rectangle {
                                                width: 3
                                                height: Math.max(14, parent.height - 12)
                                                radius: 1.5
                                                anchors.left: parent.left
                                                anchors.leftMargin: 4
                                                anchors.verticalCenter: parent.verticalCenter
                                                color: Theme.primary
                                            }
                                            Column {
                                                id: prevNewestCol
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: 12
                                                anchors.rightMargin: 8
                                                spacing: 2
                                                Text {
                                                    visible: backend.showOriginal
                                                    width: parent.width
                                                    text: "nice jump! wait at the checkpoint"
                                                    color: Theme.textSecondary
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Math.max(10, Math.min(13, backend.captionFontSize - 6))
                                                    elide: Text.ElideRight
                                                }
                                                Text {
                                                    width: parent.width
                                                    text: "점프 잘했다! 체크포인트에서 기다려줘"
                                                    color: "#F4F6FA"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Math.min(18, backend.captionFontSize)
                                                    font.weight: Font.DemiBold
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }

                                        // Older item stacked below
                                        Rectangle {
                                            width: parent.width
                                            height: prevOldCol.implicitHeight + 12
                                            radius: 9
                                            color: Qt.rgba(20/255, 22/255, 26/255, 0.78)
                                            border.width: 1
                                            border.color: Theme.borderSubtle
                                            Column {
                                                id: prevOldCol
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: 9
                                                anchors.rightMargin: 8
                                                spacing: 2
                                                Text {
                                                    visible: backend.showOriginal
                                                    width: parent.width
                                                    text: "follow me over here!"
                                                    color: Theme.textMuted
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Math.max(9, Math.min(12, backend.captionFontSize - 7))
                                                    elide: Text.ElideRight
                                                }
                                                Text {
                                                    width: parent.width
                                                    text: "이쪽으로 따라와!"
                                                    color: Theme.textSecondary
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Math.max(12, Math.min(15, backend.captionFontSize - 2))
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Column {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text { text: "표시 위치"; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Medium }
                                    Text { text: "기본: 우측 상단 상태 바 아래"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: 12 }
                                }
                                M3ComboBox {
                                    model: ["top-right", "top-left", "bottom-right", "bottom-center", "bottom-left"]
                                    currentIndex: Math.max(0, model.indexOf(backend.overlayPosition))
                                    implicitWidth: 195
                                    onActivated: backend.setOverlayPosition(currentText)
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "글자 크기 (" + backend.captionFontSize + "px)"; Layout.fillWidth: true; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Medium }
                                M3Slider {
                                    from: 14; to: 32; stepSize: 1
                                    value: backend.captionFontSize
                                    onMoved: backend.setCaptionFontSize(Math.round(value))
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Column {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text { text: "화면에 기본 표시 개수 (" + backend.maxCaptions + "개)"; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Medium }
                                    Text { text: "초기 높이를 이 개수에 맞추고, 이전 대화는 아래로 스크롤해 확인합니다"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: 12 }
                                }
                                M3Slider {
                                    from: 2; to: 8; stepSize: 1
                                    value: backend.maxCaptions
                                    onMoved: backend.setMaxCaptions(Math.round(value))
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "배경 불투명도 (" + Math.round(backend.overlayOpacity * 100) + "%)"; Layout.fillWidth: true; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Medium }
                                M3Slider {
                                    from: 0.45; to: 0.95; stepSize: 0.05
                                    value: backend.overlayOpacity
                                    onMoved: backend.setOverlayOpacity(value)
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "원문 함께 표시"; Layout.fillWidth: true; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Medium }
                                M3Switch { checked: backend.showOriginal; onToggled: function(v) { backend.setShowOriginal(v) } }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 14
                                Column {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text { width: parent.width; wrapMode: Text.WordWrap; text: "내 보낸 번역도 피드에 표시"; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Medium }
                                    Text { width: parent.width; wrapMode: Text.WordWrap; text: "입력 바로 번역한 내 문장도 우측 자막 피드에 시간순으로 함께 기록합니다"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: 12 }
                                }
                                M3Switch { checked: backend.showOutgoingInFeed; onToggled: function(v) { backend.setShowOutgoingInFeed(v) } }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 14
                                Column {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text { width: parent.width; wrapMode: Text.WordWrap; text: "번역 결과 클립보드 자동 복사"; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Medium }
                                    Text { width: parent.width; wrapMode: Text.WordWrap; text: "입력 바에서 Enter 시 번역문을 바로 복사해 게임 채팅(Ctrl+V)에 붙여넣기 좋게 합니다"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: 12 }
                                }
                                M3Switch { checked: backend.autoCopyOutgoing; onToggled: function(v) { backend.setAutoCopyOutgoing(v) } }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 14
                                Column {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text { width: parent.width; wrapMode: Text.WordWrap; text: "클릭 통과 잠금 (스크롤 대신 게임 클릭 우선)"; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Medium }
                                    Text { width: parent.width; wrapMode: Text.WordWrap; text: "끄면 우측 상단 자막 피드를 휠 스크롤/클릭 복사할 수 있습니다 (게임 포커스는 뺏지 않음)"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: 12 }
                                }
                                M3Switch { checked: backend.overlayClickThrough; onToggled: function(v) { backend.setOverlayClickThrough(v) } }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "모션 줄이기 (애니메이션 끄기)"; Layout.fillWidth: true; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Medium }
                                M3Switch { checked: backend.reduceMotion; onToggled: function(v) { backend.setReduceMotion(v) } }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                Rectangle {
                                    Layout.preferredHeight: 36
                                    Layout.preferredWidth: testCapRow.implicitWidth + 24
                                    radius: Theme.radiusFull
                                    color: testCapMa.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                                    border.width: 1
                                    border.color: Theme.outline
                                    Row {
                                        id: testCapRow
                                        anchors.centerIn: parent
                                        spacing: 6
                                        MonoIcon { width: 14; height: 14; name: "sparkles"; iconColor: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                                        Text { text: "테스트 자막 띄우기"; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                                    }
                                    MouseArea {
                                        id: testCapMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: backend.emitTestCaption()
                                    }
                                }
                                Rectangle {
                                    Layout.preferredHeight: 36
                                    Layout.preferredWidth: editBtnRow.implicitWidth + 26
                                    radius: Theme.radiusFull
                                    color: backend.editMode ? Theme.primary : Theme.primaryContainer
                                    border.width: 1
                                    border.color: Theme.primary
                                    Row {
                                        id: editBtnRow
                                        anchors.centerIn: parent
                                        spacing: 7
                                        MonoIcon {
                                            width: 14
                                            height: 14
                                            name: backend.editMode ? "check" : "drag"
                                            iconColor: backend.editMode ? Theme.textOnPrimary : Theme.textOnPrimaryContainer
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: backend.editMode ? "편집 완료 (고정하기)" : "자막 위치 드래그 편집"
                                            color: backend.editMode ? Theme.textOnPrimary : Theme.textOnPrimaryContainer
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            font.weight: Font.Medium
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: backend.toggleEditMode()
                                    }
                                }
                                Rectangle {
                                    Layout.preferredHeight: 36
                                    Layout.preferredWidth: resetPosRow.implicitWidth + 22
                                    radius: Theme.radiusFull
                                    color: resetPosMa.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                                    border.width: 1
                                    border.color: Theme.outline
                                    Row {
                                        id: resetPosRow
                                        anchors.centerIn: parent
                                        spacing: 6
                                        MonoIcon { width: 13; height: 13; name: "reset"; iconColor: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                                        Text { text: "위치 초기화"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                                    }
                                    MouseArea {
                                        id: resetPosMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: backend.resetOverlayPosition()
                                    }
                                }
                            }
                        }
                    }
                }

                // ===================== SECTION 4: VOICE OUT =====================
                ColumnLayout {
                    visible: win.section === 4
                    Layout.fillWidth: true
                    spacing: 14

                    Column {
                        Layout.fillWidth: true
                        spacing: 4
                        Text { text: "가상 마이크 음성 송출 (보내기)"; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: 22; font.weight: Font.DemiBold }
                        Text { text: "번역한 문장을 TTS로 합성해 VB-Cable 가상 마이크로 송출합니다."; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: 13 }
                    }

                    M3Card {
                        title: "VB-Cable & TTS 엔진"
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.margins: 18
                            spacing: 16

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                MonoIcon {
                                    width: 15
                                    height: 15
                                    name: backend.vbCableAvailable ? "check" : "warning"
                                    iconColor: backend.vbCableAvailable ? Theme.success : Theme.warning
                                }
                                Text {
                                    text: backend.vbCableAvailable ? "가상 마이크(CABLE Input) 감지됨" : "VB-Audio Virtual Cable 미설치 · Downloads\\VBCABLE_Driver_Pack\\VBCABLE_Setup_x64.exe 관리자 실행 후 재부팅하세요"
                                    color: backend.vbCableAvailable ? Theme.success : Theme.warning
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    wrapMode: Text.WordWrap
                                }
                                Rectangle {
                                    Layout.preferredHeight: 32
                                    Layout.preferredWidth: refRow.implicitWidth + 20
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: Theme.radiusFull
                                    color: refMa.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                                    border.width: 1
                                    border.color: Theme.outline
                                    Row {
                                        id: refRow
                                        anchors.centerIn: parent
                                        spacing: 6
                                        MonoIcon { width: 13; height: 13; name: "refresh"; iconColor: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                                        Text { text: "장치 새로고침"; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: 12 }
                                    }
                                    MouseArea {
                                        id: refMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: backend.refreshDevices()
                                    }
                                }
                                Rectangle {
                                    visible: !backend.vbCableAvailable
                                    Layout.preferredHeight: 32
                                    Layout.preferredWidth: vbRow.implicitWidth + 20
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: Theme.radiusFull
                                    color: vbMa.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                                    border.width: 1
                                    border.color: Theme.outline
                                    Row {
                                        id: vbRow
                                        anchors.centerIn: parent
                                        spacing: 5
                                        Text { text: "VB-Cable 페이지"; color: Theme.primary; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Medium }
                                        MonoIcon { width: 12; height: 12; name: "external"; iconColor: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                                    }
                                    MouseArea {
                                        id: vbMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Qt.openUrlExternally("https://vb-audio.com/Cable/")
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "TTS 엔진 (edge=무료, gemini=고품질 유료/크레딧)"; Layout.fillWidth: true; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Medium }
                                M3ComboBox {
                                    model: ["edge", "gemini", "sapi"]
                                    currentIndex: Math.max(0, model.indexOf(backend.ttsEngine))
                                    implicitWidth: 150
                                    onActivated: backend.setTtsEngine(currentText)
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "가상 케이블 출력 장치"; Layout.fillWidth: true; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Medium }
                                M3ComboBox {
                                    model: backend.outputDevices
                                    currentIndex: win.findDeviceIndex(backend.outputDevices, backend.voiceOutDevice, 0)
                                    implicitWidth: 280
                                    onActivated: backend.setVoiceOutDevice(currentText)
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "내 헤드셋 모니터링 (내 귀로도 듣기)"; Layout.fillWidth: true; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Medium }
                                M3ComboBox {
                                    model: ["(사용 안 함)"].concat(backend.outputDevices)
                                    currentIndex: backend.monitorDevice.length > 0 ? win.findDeviceIndex(backend.outputDevices, backend.monitorDevice, 1) : 0
                                    implicitWidth: 280
                                    onActivated: backend.setMonitorDevice(currentIndex === 0 ? "" : currentText)
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Column {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text { text: "내 실제 마이크 + TTS 믹싱 (덕킹)"; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Medium }
                                    Text { text: "Roblox 입력을 CABLE Output으로 둔 채 평소 내 육성도 함께 보냅니다"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: 12 }
                                }
                                M3Switch {
                                    checked: backend.mixMicrophone
                                    onToggled: function(v) { backend.setMixMicrophone(v) }
                                }
                            }

                            RowLayout {
                                spacing: 12
                                Rectangle {
                                    height: 36
                                    width: testSpeakRow.implicitWidth + 26
                                    radius: Theme.radiusFull
                                    color: backend.vbCableAvailable ? Theme.primary : Theme.surfaceContainerHigh
                                    border.width: backend.vbCableAvailable ? 0 : 1
                                    border.color: Theme.outline
                                    Row {
                                        id: testSpeakRow
                                        anchors.centerIn: parent
                                        spacing: 7
                                        MonoIcon {
                                            width: 15
                                            height: 15
                                            name: "volume"
                                            iconColor: backend.vbCableAvailable ? Theme.textOnPrimary : Theme.textSecondary
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: "테스트 음성 송출"
                                            color: backend.vbCableAvailable ? Theme.textOnPrimary : Theme.textSecondary
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            font.weight: Font.Medium
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: backend.speakText("Hello! Nice to meet you!", "en")
                                    }
                                }
                                Text {
                                    visible: !backend.vbCableAvailable
                                    text: "VB-Cable 설치 후 장치 새로고침을 누르면 활성화됩니다"
                                    color: Theme.textMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                }
                            }
                        }
                    }
                }

                // ===================== SECTION 5: QUICK PHRASES & GLOSSARY =====================
                ColumnLayout {
                    visible: win.section === 5
                    Layout.fillWidth: true
                    spacing: 14

                    Column {
                        Layout.fillWidth: true
                        spacing: 4
                        Text { text: "빠른 문구 & 용어집"; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: 22; font.weight: Font.DemiBold }
                        Text { text: "자주 쓰는 대사와 번역 시 유지할 고유명사(게임 용어·닉네임)를 관리합니다."; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: 13 }
                    }

                    M3Card {
                        title: "빠른 문구 (입력 바 / Ctrl+Shift+1~9)"
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.margins: 18
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 38
                                    radius: 10
                                    color: Theme.surface
                                    border.width: 1
                                    border.color: newPhrase.activeFocus ? Theme.primary : Theme.outline
                                    TextField {
                                        id: newPhrase
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        placeholderText: "자주 쓰는 말 추가 (예: 나 먼저 갈게!)"
                                        placeholderTextColor: Theme.textMuted
                                        color: Theme.textPrimary
                                        selectionColor: Theme.primaryContainer
                                        selectedTextColor: Theme.textPrimary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 13
                                        verticalAlignment: TextInput.AlignVCenter
                                        background: Item {}
                                    }
                                }
                                Rectangle {
                                    height: 38
                                    width: addRow.implicitWidth + 24
                                    radius: Theme.radiusFull
                                    color: Theme.primary
                                    Row {
                                        id: addRow
                                        anchors.centerIn: parent
                                        spacing: 5
                                        MonoIcon { width: 14; height: 14; name: "plus"; iconColor: Theme.textOnPrimary; anchors.verticalCenter: parent.verticalCenter }
                                        Text { text: "추가"; color: Theme.textOnPrimary; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (newPhrase.text.trim().length > 0) {
                                                backend.addQuickPhrase("•", newPhrase.text.trim())
                                                newPhrase.text = ""
                                            }
                                        }
                                    }
                                }
                            }

                            Repeater {
                                model: backend.quickPhrases
                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    height: 36
                                    radius: 8
                                    color: phraseItemMa.containsMouse ? Theme.surfaceContainerHigh : "transparent"
                                    MouseArea {
                                        id: phraseItemMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                    }
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 6
                                        spacing: 10
                                        Rectangle {
                                            width: 20
                                            height: 20
                                            radius: 5
                                            color: Theme.surfaceContainerHighest
                                            Text {
                                                anchors.centerIn: parent
                                                text: (index + 1).toString()
                                                color: Theme.textSecondary
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 11
                                                font.weight: Font.Medium
                                            }
                                        }
                                        Text {
                                            text: modelData.text
                                            Layout.fillWidth: true
                                            color: Theme.textPrimary
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 13
                                        }
                                        Rectangle {
                                            width: 28
                                            height: 28
                                            radius: 14
                                            color: delMa.containsMouse ? Theme.navHoverBg : "transparent"
                                            MonoIcon {
                                                anchors.centerIn: parent
                                                width: 13
                                                height: 13
                                                name: "close"
                                                iconColor: Theme.textSecondary
                                            }
                                            MouseArea {
                                                id: delMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: backend.removeQuickPhrase(index)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    M3Card {
                        title: "용어집 (번역하지 않고 그대로 유지할 닉네임·게임 용어)"
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.margins: 18
                            spacing: 10
                            Rectangle {
                                Layout.fillWidth: true
                                height: 40
                                radius: 10
                                color: Theme.surface
                                border.width: 1
                                border.color: glossField.activeFocus ? Theme.primary : Theme.outline
                                TextField {
                                    id: glossField
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    text: backend.glossaryText
                                    placeholderText: "쉼표로 구분해 입력 (예: Blox Fruits, Obby, Robux, 내닉네임)"
                                    placeholderTextColor: Theme.textMuted
                                    color: Theme.textPrimary
                                    selectionColor: Theme.primaryContainer
                                    selectedTextColor: Theme.textPrimary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    verticalAlignment: TextInput.AlignVCenter
                                    background: Item {}
                                    onEditingFinished: backend.setGlossaryText(text)
                                }
                            }
                        }
                    }
                }

                // ===================== SECTION 6: HOTKEYS & USAGE =====================
                ColumnLayout {
                    visible: win.section === 6
                    Layout.fillWidth: true
                    spacing: 14

                    Column {
                        Layout.fillWidth: true
                        spacing: 4
                        Text { text: "단축키 & 사용량"; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: 22; font.weight: Font.DemiBold }
                        Text { text: "이번 달 Gemini API 토큰 예상 비용과 전역 단축키를 확인합니다."; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: 13 }
                    }

                    M3Card {
                        title: "이번 달 예상 사용량"
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.margins: 18
                            spacing: 12

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "$" + backend.costMonth.toFixed(3) + " / 예산 $" + backend.monthlyBudgetUsd.toFixed(2)
                                    color: Theme.textPrimary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 24
                                    font.weight: Font.DemiBold
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: "오늘 요청 " + backend.requestsToday + "회 · $" + backend.costToday.toFixed(3)
                                    color: Theme.textSecondary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 8
                                radius: 4
                                color: Theme.surfaceContainerHighest
                                Rectangle {
                                    width: parent.width * Math.min(1.0, backend.monthlyBudgetUsd > 0 ? backend.costMonth / backend.monthlyBudgetUsd : 0)
                                    height: parent.height
                                    radius: 4
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: "#4285F4" }
                                        GradientStop { position: 0.5; color: "#9B72CB" }
                                        GradientStop { position: 1.0; color: "#D96570" }
                                    }
                                }
                            }

                            // 12-day bar chart
                            RowLayout {
                                Layout.fillWidth: true
                                height: 84
                                spacing: 6
                                Repeater {
                                    model: backend.usageBars
                                    delegate: Item {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            width: parent.width
                                            height: Math.max(4, parent.height * modelData.ratio)
                                            radius: 4
                                            color: index === backend.usageBars.length - 1 ? Theme.primary : Theme.surfaceContainerHighest
                                        }
                                    }
                                }
                            }
                        }
                    }

                    M3Card {
                        title: "전역 단축키"
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.margins: 18
                            spacing: 10
                            Repeater {
                                model: [
                                    { label: "입력 바 열기/닫기", key: backend.hotkeyToggleInput },
                                    { label: "듣기 켜기/끄기", key: backend.hotkeyToggleListen },
                                    { label: "마지막 번역문 다시 말하기", key: backend.hotkeyRepeatLast },
                                    { label: "자막 기록 열기", key: backend.hotkeyHistory },
                                    { label: "오버레이 위치 편집 모드", key: backend.hotkeyEditOverlay }
                                ]
                                delegate: RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: modelData.label; Layout.fillWidth: true; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: 13 }
                                    Rectangle {
                                        height: 26
                                        width: kTxt.implicitWidth + 16
                                        radius: 6
                                        color: Theme.surfaceContainerHighest
                                        border.width: 1
                                        border.color: Theme.outline
                                        Text { id: kTxt; anchors.centerIn: parent; text: modelData.key; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Medium }
                                    }
                                }
                            }
                        }
                    }
                }

                Item { height: 28 }
            }
        }
    }
}
