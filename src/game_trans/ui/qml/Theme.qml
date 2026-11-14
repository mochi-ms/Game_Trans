pragma Singleton
import QtQuick

// Design tokens – Gemini / Antigravity dark aesthetic.
// Note: Avoid naming properties `on<ExistingProp>` (e.g. `onSurface`) because Qt 6 QML
// treats `onX` as a signal collision when `x` is also a property on the same object.
QtObject {
    // Surfaces & glass
    readonly property color surface: "#0F1012"
    readonly property color sidebarSurface: "#141518"
    readonly property color surfaceContainer: "#1A1B1F"
    readonly property color surfaceContainerHigh: "#23252A"
    readonly property color surfaceContainerHighest: "#2E3138"
    readonly property color scrim: Qt.rgba(16/255, 17/255, 20/255, 0.88)
    readonly property color cardGlass: Qt.rgba(22/255, 23/255, 27/255, 0.96)
    readonly property color borderSubtle: Qt.rgba(1, 1, 1, 0.08)
    readonly property color outline: "#383B43"

    // Foreground / text roles (high-contrast on dark surfaces)
    readonly property color textPrimary: "#ECEEF2"
    readonly property color textSecondary: "#A7ACB5"
    readonly property color textMuted: "#7A7F89"

    // Brand / accent roles
    readonly property color primary: "#A8C7FA"
    readonly property color textOnPrimary: "#062E6F"
    readonly property color primaryContainer: "#183153"
    readonly property color textOnPrimaryContainer: "#D3E3FD"
    readonly property color navActiveBg: Qt.rgba(168/255, 199/255, 250/255, 0.14)
    readonly property color navHoverBg: Qt.rgba(1, 1, 1, 0.05)

    // Semantic states
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
    readonly property var easeEmphasized: [0.2, 0.0, 0.0, 1.0, 1.0, 1.0]
}
