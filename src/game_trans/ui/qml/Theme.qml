pragma Singleton
import QtQuick

// Design tokens – mirrors docs/UI_UX.md §2 (Gemini-style dark, Material 3 roles)
QtObject {
    // Color roles
    readonly property color surface: "#131314"
    readonly property color surfaceContainer: "#1E1F20"
    readonly property color surfaceContainerHigh: "#282A2C"
    readonly property color surfaceContainerHighest: "#333537"
    readonly property color scrim: Qt.rgba(19/255, 19/255, 20/255, 0.72)
    readonly property color outline: "#444746"
    readonly property color onSurface: Qt.color("#E3E3E3")
    readonly property color onSurfaceVariant: Qt.color("#C4C7C5")
    readonly property color primary: "#A8C7FA"
    readonly property color onPrimary: Qt.color("#062E6F")
    readonly property color primaryContainer: "#0842A0"
    readonly property color onPrimaryContainer: Qt.color("#D3E3FD")
    readonly property color success: "#6DD58C"
    readonly property color warning: "#FFB870"
    readonly property color error: "#F2B8B5"

    // AI gradient stops
    readonly property var aiGradient: ["#4285F4", "#9B72CB", "#D96570"]

    // Typography
    readonly property string fontFamily: "Pretendard"
    readonly property int captionSize: 22
    readonly property int captionOriginalSize: 14
    readonly property int bodySize: 15
    readonly property int labelSize: 13

    // Shape
    readonly property int radiusFull: 999
    readonly property int radiusCard: 20
    readonly property int radiusSettingsCard: 16

    // Motion
    readonly property int durEmphasized: 400
    readonly property int durStandard: 200
    readonly property int durExit: 150
    // cubic-bezier(0.2, 0, 0, 1)
    readonly property var easeEmphasized: [0.2, 0.0, 0.0, 1.0, 1.0, 1.0]
}
