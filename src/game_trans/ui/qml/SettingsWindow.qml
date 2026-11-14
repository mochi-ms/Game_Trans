import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic
import QtQuick.Layouts

Window {
    id: win
    visible: backend.settingsOpen
    title: "Game Trans – 설정"
    color: Theme.surface
    width: 1020
    height: 680
    minimumWidth: 880
    minimumHeight: 560
    flags: Qt.Window

    property int section: backend.hasApiKey ? 1 : 0
    property string apiKeyInput: ""
    property bool keyTesting: false
    property string keyTestMsg: ""
    property bool keyTestOk: false

    onClosing: function(close) {
        close.accepted = false
        backend.settingsOpen = false
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

        // Material 3 Navigation Rail
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 104
            color: Theme.surface

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 14
                anchors.bottomMargin: 14
                spacing: 6

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6
                    Sparkle { width: 18; height: 18 }
                    Text {
                        text: "Game Trans"
                        color: Theme.onSurface
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                }

                Item { height: 8 }

                Repeater {
                    model: [
                        { icon: "🔑", label: "연결·API" },
                        { icon: "🌐", label: "번역·AI" },
                        { icon: "🎧", label: "오디오" },
                        { icon: "💬", label: "오버레이" },
                        { icon: "🔊", label: "음성 송출" },
                        { icon: "⚡", label: "문구·용어" },
                        { icon: "📊", label: "단축키·사용" }
                    ]
                    delegate: Column {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 4
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 58
                            height: 32
                            radius: 16
                            color: win.section === index ? Theme.primaryContainer : (railMa.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent")
                            Text {
                                anchors.centerIn: parent
                                text: modelData.icon
                                font.pixelSize: 15
                            }
                            MouseArea {
                                id: railMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.section = index
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.label
                            color: win.section === index ? Theme.onSurface : Theme.onSurfaceVariant
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: win.section === index ? Font.Medium : Font.Normal
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 82
                    height: 34
                    radius: Theme.radiusFull
                    color: hideMa.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer
                    border.width: 1
                    border.color: Theme.outline
                    Text {
                        anchors.centerIn: parent
                        text: "닫기 (트레이)"
                        color: Theme.onSurfaceVariant
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
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

        Rectangle { Layout.fillHeight: true; width: 1; color: Theme.surfaceContainerHighest }

        // Main scrollable content
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true

            ColumnLayout {
                width: win.width - 140
                anchors.left: parent.left
                anchors.leftMargin: 28
                anchors.top: parent.top
                anchors.topMargin: 24
                spacing: 16

                // ===================== SECTION 0: API & ONBOARDING =====================
                ColumnLayout {
                    visible: win.section === 0
                    Layout.fillWidth: true
                    spacing: 14

                    Text {
                        text: "Google AI Studio 연결"
                        color: Theme.onSurface
                        font.family: Theme.fontFamily
                        font.pixelSize: 24
                        font.weight: Font.Medium
                    }
                    Text {
                        text: "구글 계정으로 AI Studio에서 API 키를 발급받아 연결하세요. 키는 Windows 자격 증명 관리자에 안전하게 저장됩니다."
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        color: Theme.onSurfaceVariant
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                    }

                    M3Card {
                        title: "API 키"
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.margins: 18
                            spacing: 12

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: backend.hasApiKey ? ("현재 저장된 키: " + backend.maskedApiKey) : "저장된 API 키가 없습니다"
                                    color: backend.hasApiKey ? Theme.success : Theme.warning
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                }
                                Item { Layout.fillWidth: true }
                                Rectangle {
                                    height: 34
                                    width: aiBtnTxt.implicitWidth + 24
                                    radius: Theme.radiusFull
                                    color: Theme.surfaceContainerHigh
                                    border.width: 1
                                    border.color: Theme.outline
                                    Text {
                                        id: aiBtnTxt
                                        anchors.centerIn: parent
                                        text: "🔑 AI Studio 키 발급 페이지 열기 ↗"
                                        color: Theme.primary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                    }
                                    MouseArea {
                                        anchors.fill: parent
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
                                    height: 44
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
                                        placeholderTextColor: "#8E918F"
                                        color: Theme.onSurface
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 13
                                        background: Item {}
                                        onTextChanged: win.apiKeyInput = text
                                    }
                                }
                                Rectangle {
                                    height: 44
                                    width: saveKeyTxt.implicitWidth + 30
                                    radius: Theme.radiusFull
                                    color: Theme.primary
                                    opacity: win.keyTesting ? 0.6 : 1.0
                                    Text {
                                        id: saveKeyTxt
                                        anchors.centerIn: parent
                                        text: win.keyTesting ? "테스트 중…" : "연결 테스트 & 저장"
                                        color: Theme.onPrimary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                    }
                                    MouseArea {
                                        anchors.fill: parent
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

                            Text {
                                visible: win.keyTestMsg.length > 0
                                text: (win.keyTestOk ? "✓ " : "⚠ ") + win.keyTestMsg
                                color: win.keyTestOk ? Theme.success : Theme.error
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                            }
                        }
                    }

                    M3Card {
                        title: "요금제 한도 프리셋 (Google AI Pro 월 $10 크레딧 활용 팁)"
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.margins: 18
                            spacing: 10
                            Text {
                                text: "Gemini 웹/앱 구독과 API 한도는 별개입니다. Google AI Pro 구독자는 AI Studio에서 월 $10 크레딧을 연결하면 Tier 1(높은 한도)로 여유롭게 사용할 수 있습니다."
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                                color: Theme.onSurfaceVariant
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
                                    Text {
                                        id: p1Txt
                                        anchors.centerIn: parent
                                        text: "무료 티어 안전 모드 (10 RPM)"
                                        color: backend.rpmLimit <= 15 ? Theme.onPrimaryContainer : Theme.onSurface
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
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
                                    Text {
                                        id: p2Txt
                                        anchors.centerIn: parent
                                        text: "Pro $10 크레딧 / Tier 1 (300 RPM)"
                                        color: backend.rpmLimit >= 100 ? Theme.onPrimaryContainer : Theme.onSurface
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
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

                    Text { text: "번역 & AI 설정"; color: Theme.onSurface; font.family: Theme.fontFamily; font.pixelSize: 24; font.weight: Font.Medium }

                    M3Card {
                        title: "모델 & 언어"
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.margins: 18
                            spacing: 14

                            RowLayout {
                                Layout.fillWidth: true
                                Column {
                                    Layout.fillWidth: true
                                    Text { text: "Gemini 모델"; color: Theme.onSurface; font.family: Theme.fontFamily; font.pixelSize: 14 }
                                    Text { text: "기본: gemini-3.5-flash-lite (빠르고 저렴함)"; color: Theme.onSurfaceVariant; font.family: Theme.fontFamily; font.pixelSize: 12 }
                                }
                                ComboBox {
                                    id: modelCombo
                                    editable: true
                                    model: ["gemini-3.5-flash-lite", "gemini-3.5-flash", "gemini-2.5-flash-lite"]
                                    editText: backend.aiModel
                                    implicitWidth: 230
                                    onActivated: backend.setAiModel(currentText)
                                    onAccepted: backend.setAiModel(editText)
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Column {
                                    Layout.fillWidth: true
                                    Text { text: "내 언어 (자막 표시 언어)"; color: Theme.onSurface; font.family: Theme.fontFamily; font.pixelSize: 14 }
                                }
                                ComboBox {
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
                                    Text { text: "상대 언어 (내가 말할 때 번역 대상)"; color: Theme.onSurface; font.family: Theme.fontFamily; font.pixelSize: 14 }
                                    Text { text: "auto는 최근 들린 상대 언어를 자동 추적합니다"; color: Theme.onSurfaceVariant; font.family: Theme.fontFamily; font.pixelSize: 12 }
                                }
                                ComboBox {
                                    model: ["auto", "en", "ja", "zh", "es", "pt", "fr", "de", "ru", "id", "th", "vi"]
                                    currentIndex: Math.max(0, model.indexOf(backend.partnerLanguage))
                                    implicitWidth: 140
                                    onActivated: backend.setPartnerLanguage(currentText)
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Column {
                                    Layout.fillWidth: true
                                    Text { text: "한글 발음 표기"; color: Theme.onSurface; font.family: Theme.fontFamily; font.pixelSize: 14 }
                                    Text { text: "번역문 아래에 읽는 법(발음)을 함께 표시"; color: Theme.onSurfaceVariant; font.family: Theme.fontFamily; font.pixelSize: 12 }
                                }
                                M3Switch {
                                    checked: backend.showPronunciation
                                    onToggled: function(v) { backend.setShowPronunciation(v) }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Column {
                                    Layout.fillWidth: true
                                    Text { text: "로컬 STT 모드 (faster-whisper)"; color: Theme.onSurface; font.family: Theme.fontFamily; font.pixelSize: 14 }
                                    Text { text: "켜면 오디오 대신 텍스트만 Gemini로 번역 (한도 극소화, 별도 .[local] 설치 필요)"; color: Theme.onSurfaceVariant; font.family: Theme.fontFamily; font.pixelSize: 12 }
                                }
                                M3Switch {
                                    checked: backend.aiMode === "local"
                                    onToggled: function(v) { backend.setAiMode(v ? "local" : "cloud") }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Column {
                                    Layout.fillWidth: true
                                    Text { text: "429 한도 초과 시 자동으로 로컬 모드 전환"; color: Theme.onSurface; font.family: Theme.fontFamily; font.pixelSize: 14 }
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

                    Text { text: "오디오 캡처 (듣기)"; color: Theme.onSurface; font.family: Theme.fontFamily; font.pixelSize: 24; font.weight: Font.Medium }

                    M3Card {
                        title: "캡처 대상 & 필터"
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.margins: 18
                            spacing: 14

                            RowLayout {
                                Layout.fillWidth: true
                                Column {
                                    Layout.fillWidth: true
                                    Text { text: "캡처 방식"; color: Theme.onSurface; font.family: Theme.fontFamily; font.pixelSize: 14 }
                                    Text { text: "process: 로블록스 소리만 분리 · device: PC 전체 소리"; color: Theme.onSurfaceVariant; font.family: Theme.fontFamily; font.pixelSize: 12 }
                                }
                                ComboBox {
                                    model: ["process", "device"]
                                    currentIndex: Math.max(0, model.indexOf(backend.captureMode))
                                    implicitWidth: 160
                                    onActivated: backend.setCaptureMode(currentText)
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Column {
                                    Layout.fillWidth: true
                                    Text { text: "대상 프로세스 이름"; color: Theme.onSurface; font.family: Theme.fontFamily; font.pixelSize: 14 }
                                    Text { text: "쉼표로 여러 개 지정 가능 (기본: RobloxPlayerBeta.exe)"; color: Theme.onSurfaceVariant; font.family: Theme.fontFamily; font.pixelSize: 12 }
                                }
                                TextField {
                                    text: backend.targetProcessesText
                                    implicitWidth: 240
                                    color: Theme.onSurface
                                    background: Rectangle { color: Theme.surface; radius: 8; border.width: 1; border.color: Theme.outline }
                                    onEditingFinished: backend.setTargetProcessesText(text)
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Column {
                                    Layout.fillWidth: true
                                    Text { text: "게임 BGM/효과음 억제 (300–3400Hz 음성 대역 강조)"; color: Theme.onSurface; font.family: Theme.fontFamily; font.pixelSize: 14 }
                                }
                                M3Switch {
                                    checked: backend.bgmSuppression
                                    onToggled: function(v) { backend.setBgmSuppression(v) }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12
                                Column {
                                    Layout.fillWidth: true
                                    Text { text: "실시간 입력 레벨 (" + backend.vadBackend + " VAD)"; color: Theme.onSurface; font.family: Theme.fontFamily; font.pixelSize: 14 }
                                    Rectangle {
                                        width: 280
                                        height: 10
                                        radius: 5
                                        color: Theme.surfaceContainerHighest
                                        Rectangle {
                                            width: parent.width * Math.min(1.0, backend.audioLevel)
                                            height: parent.height
                                            radius: 5
                                            color: backend.audioLevel > 0.25 ? Theme.success : Theme.primary
                                            Behavior on width { NumberAnimation { duration: 80 } }
                                        }
                                    }
                                }
                                Rectangle {
                                    height: 36
                                    width: 140
                                    radius: Theme.radiusFull
                                    color: backend.listening ? Theme.primaryContainer : Theme.primary
                                    Text {
                                        anchors.centerIn: parent
                                        text: backend.listening ? "듣기 일시정지" : "지금 듣기 시작"
                                        color: backend.listening ? Theme.onPrimaryContainer : Theme.onPrimary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
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

                    Text { text: "자막 오버레이"; color: Theme.onSurface; font.family: Theme.fontFamily; font.pixelSize: 24; font.weight: Font.Medium }

                    M3Card {
                        title: "미리보기 & 모양"
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.margins: 18
                            spacing: 14

                            Rectangle {
                                Layout.fillWidth: true
                                height: 120
                                radius: 12
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "#5AA9FF" }
                                    GradientStop { position: 0.6; color: "#9FD3FF" }
                                    GradientStop { position: 0.61; color: "#5DAE52" }
                                    GradientStop { position: 1.0; color: "#43873B" }
                                }
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 12
                                    width: parent.width * 0.85
                                    height: prevCol.implicitHeight + 18
                                    radius: 16
                                    color: Qt.rgba(19/255, 19/255, 20/255, backend.overlayOpacity)
                                    Column {
                                        id: prevCol
                                        anchors.centerIn: parent
                                        width: parent.width - 24
                                        spacing: 2
                                        Text {
                                            visible: backend.showOriginal
                                            text: "nice jump! wait for me at the checkpoint"
                                            color: Theme.onSurfaceVariant
                                            font.pixelSize: Math.max(11, backend.captionFontSize - 7)
                                        }
                                        Text {
                                            text: "점프 잘했다! 체크포인트에서 기다려줘"
                                            color: Theme.onSurface
                                            font.pixelSize: backend.captionFontSize
                                            font.weight: Font.DemiBold
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "글자 크기 (" + backend.captionFontSize + "px)"; Layout.fillWidth: true; color: Theme.onSurface; font.pixelSize: 14 }
                                Slider {
                                    from: 16; to: 36; stepSize: 1
                                    value: backend.captionFontSize
                                    onMoved: backend.setCaptionFontSize(Math.round(value))
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "배경 불투명도 (" + Math.round(backend.overlayOpacity * 100) + "%)"; Layout.fillWidth: true; color: Theme.onSurface; font.pixelSize: 14 }
                                Slider {
                                    from: 0.35; to: 0.95; stepSize: 0.05
                                    value: backend.overlayOpacity
                                    onMoved: backend.setOverlayOpacity(value)
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "자막 유지 시간 (" + backend.captionDurationS + "초)"; Layout.fillWidth: true; color: Theme.onSurface; font.pixelSize: 14 }
                                Slider {
                                    from: 3; to: 15; stepSize: 1
                                    value: backend.captionDurationS
                                    onMoved: backend.setCaptionDurationS(Math.round(value))
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "원문 함께 표시"; Layout.fillWidth: true; color: Theme.onSurface; font.pixelSize: 14 }
                                M3Switch { checked: backend.showOriginal; onToggled: function(v) { backend.setShowOriginal(v) } }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "모션 줄이기 (애니메이션 끄기)"; Layout.fillWidth: true; color: Theme.onSurface; font.pixelSize: 14 }
                                M3Switch { checked: backend.reduceMotion; onToggled: function(v) { backend.setReduceMotion(v) } }
                            }

                            RowLayout {
                                spacing: 10
                                Rectangle {
                                    height: 36
                                    width: 170
                                    radius: Theme.radiusFull
                                    color: Theme.primaryContainer
                                    Text {
                                        anchors.centerIn: parent
                                        text: backend.editMode ? "편집 완료 (고정하기)" : "자막 위치 드래그 편집"
                                        color: Theme.onPrimaryContainer
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: backend.toggleEditMode()
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

                    Text { text: "가상 마이크 음성 송출 (보내기)"; color: Theme.onSurface; font.family: Theme.fontFamily; font.pixelSize: 24; font.weight: Font.Medium }

                    M3Card {
                        title: "VB-Cable & TTS 엔진"
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.margins: 18
                            spacing: 14

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: backend.vbCableAvailable ? "✓ 가상 마이크(CABLE Input) 감지됨" : "⚠ VB-Audio Virtual Cable이 감지되지 않았습니다"
                                    color: backend.vbCableAvailable ? Theme.success : Theme.warning
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                    Layout.fillWidth: true
                                }
                                Rectangle {
                                    visible: !backend.vbCableAvailable
                                    height: 32
                                    width: vbBtn.implicitWidth + 22
                                    radius: Theme.radiusFull
                                    color: Theme.surfaceContainerHigh
                                    border.width: 1
                                    border.color: Theme.outline
                                    Text {
                                        id: vbBtn
                                        anchors.centerIn: parent
                                        text: "VB-Cable 다운로드 ↗"
                                        color: Theme.primary
                                        font.pixelSize: 12
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Qt.openUrlExternally("https://vb-audio.com/Cable/")
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "TTS 엔진 (edge=무료, gemini=고품질 유료/크레딧)"; Layout.fillWidth: true; color: Theme.onSurface; font.pixelSize: 14 }
                                ComboBox {
                                    model: ["edge", "gemini", "sapi"]
                                    currentIndex: Math.max(0, model.indexOf(backend.ttsEngine))
                                    implicitWidth: 140
                                    onActivated: backend.setTtsEngine(currentText)
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "가상 케이블 출력 장치"; Layout.fillWidth: true; color: Theme.onSurface; font.pixelSize: 14 }
                                ComboBox {
                                    model: backend.outputDevices
                                    currentIndex: Math.max(0, model.indexOf(backend.voiceOutDevice))
                                    implicitWidth: 260
                                    onActivated: backend.setVoiceOutDevice(currentText)
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "내 헤드셋 모니터링 (내 귀로도 듣기)"; Layout.fillWidth: true; color: Theme.onSurface; font.pixelSize: 14 }
                                ComboBox {
                                    model: ["(사용 안 함)"].concat(backend.outputDevices)
                                    currentIndex: backend.monitorDevice.length > 0 ? Math.max(0, model.indexOf(backend.monitorDevice)) : 0
                                    implicitWidth: 260
                                    onActivated: backend.setMonitorDevice(currentIndex === 0 ? "" : currentText)
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Column {
                                    Layout.fillWidth: true
                                    Text { text: "내 실제 마이크 + TTS 믹싱 (덕킹)"; color: Theme.onSurface; font.pixelSize: 14 }
                                    Text { text: "Roblox 입력을 CABLE Output으로 둔 채 평소 내 육성도 함께 보냅니다"; color: Theme.onSurfaceVariant; font.pixelSize: 12 }
                                }
                                M3Switch {
                                    checked: backend.mixMicrophone
                                    onToggled: function(v) { backend.setMixMicrophone(v) }
                                }
                            }

                            RowLayout {
                                spacing: 10
                                Rectangle {
                                    height: 36
                                    width: 170
                                    radius: Theme.radiusFull
                                    color: Theme.primary
                                    Text {
                                        anchors.centerIn: parent
                                        text: "🔊 테스트 음성 송출"
                                        color: Theme.onPrimary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: backend.speakText("Hello! Nice to meet you!", "en")
                                    }
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

                    Text { text: "빠른 문구 & 용어집"; color: Theme.onSurface; font.family: Theme.fontFamily; font.pixelSize: 24; font.weight: Font.Medium }

                    M3Card {
                        title: "빠른 문구 (입력 바 / Ctrl+Shift+1~9)"
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.margins: 18
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                TextField {
                                    id: newEmoji
                                    text: "💬"
                                    implicitWidth: 48
                                    color: Theme.onSurface
                                    background: Rectangle { color: Theme.surface; radius: 8; border.width: 1; border.color: Theme.outline }
                                }
                                TextField {
                                    id: newPhrase
                                    Layout.fillWidth: true
                                    placeholderText: "자주 쓰는 말 추가 (예: 나 먼저 갈게!)"
                                    placeholderTextColor: "#8E918F"
                                    color: Theme.onSurface
                                    background: Rectangle { color: Theme.surface; radius: 8; border.width: 1; border.color: Theme.outline }
                                }
                                Rectangle {
                                    height: 36
                                    width: 72
                                    radius: Theme.radiusFull
                                    color: Theme.primary
                                    Text { anchors.centerIn: parent; text: "추가"; color: Theme.onPrimary; font.pixelSize: 12; font.weight: Font.Medium }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (newPhrase.text.trim().length > 0) {
                                                backend.addQuickPhrase(newEmoji.text.trim() || "💬", newPhrase.text.trim())
                                                newPhrase.text = ""
                                            }
                                        }
                                    }
                                }
                            }

                            Repeater {
                                model: backend.quickPhrases
                                delegate: RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: (index + 1) + ". " + modelData.emoji + " " + modelData.text; Layout.fillWidth: true; color: Theme.onSurface; font.pixelSize: 13 }
                                    Rectangle {
                                        width: 28; height: 28; radius: 14; color: "transparent"
                                        Text { anchors.centerIn: parent; text: "✕"; color: Theme.onSurfaceVariant; font.pixelSize: 12 }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: backend.removeQuickPhrase(index) }
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
                            TextField {
                                Layout.fillWidth: true
                                text: backend.glossaryText
                                placeholderText: "쉼표로 구분해 입력 (예: Blox Fruits, Obby, Robux, 내닉네임)"
                                placeholderTextColor: "#8E918F"
                                color: Theme.onSurface
                                background: Rectangle { color: Theme.surface; radius: 8; border.width: 1; border.color: Theme.outline }
                                onEditingFinished: backend.setGlossaryText(text)
                            }
                        }
                    }
                }

                // ===================== SECTION 6: HOTKEYS & USAGE =====================
                ColumnLayout {
                    visible: win.section === 6
                    Layout.fillWidth: true
                    spacing: 14

                    Text { text: "단축키 & 사용량"; color: Theme.onSurface; font.family: Theme.fontFamily; font.pixelSize: 24; font.weight: Font.Medium }

                    M3Card {
                        title: "이번 달 예상 사용량"
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.margins: 18
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "$" + backend.costMonth.toFixed(3) + " / 예산 $" + backend.monthlyBudgetUsd.toFixed(2)
                                    color: Theme.onSurface
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 26
                                    font.weight: Font.Medium
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: "오늘 요청 " + backend.requestsToday + "회 · $" + backend.costToday.toFixed(3)
                                    color: Theme.onSurfaceVariant
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
                            spacing: 8
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
                                    Text { text: modelData.label; Layout.fillWidth: true; color: Theme.onSurface; font.pixelSize: 13 }
                                    Rectangle {
                                        height: 26
                                        width: kTxt.implicitWidth + 16
                                        radius: 6
                                        color: Theme.surfaceContainerHighest
                                        border.width: 1
                                        border.color: Theme.outline
                                        Text { id: kTxt; anchors.centerIn: parent; text: modelData.key; color: Theme.onSurface; font.pixelSize: 12 }
                                    }
                                }
                            }
                        }
                    }
                }

                Item { height: 24 }
            }
        }
    }
}
