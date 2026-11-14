import QtQuick

// Custom 4-point Gemini-inspired sparkle rendered via Canvas (no external SVG plugin needed)
Canvas {
    id: root
    width: 24
    height: 24
    property color solidColor: "transparent"

    onSolidColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        var w = width
        var h = height
        var cx = w / 2
        var cy = h / 2
        var r = Math.min(w, h) * 0.44
        var k = r * 0.14

        ctx.beginPath()
        ctx.moveTo(cx, cy - r)
        ctx.bezierCurveTo(cx + k, cy - k, cx + k, cy - k, cx + r, cy)
        ctx.bezierCurveTo(cx + k, cy + k, cx + k, cy + k, cx, cy + r)
        ctx.bezierCurveTo(cx - k, cy + k, cx - k, cy + k, cx - r, cy)
        ctx.bezierCurveTo(cx - k, cy - k, cx - k, cy - k, cx, cy - r)
        ctx.closePath()

        if (solidColor.a > 0) {
            ctx.fillStyle = solidColor
        } else {
            var grad = ctx.createLinearGradient(0, 0, w, h)
            grad.addColorStop(0.0, "#4285F4")
            grad.addColorStop(0.5, "#9B72CB")
            grad.addColorStop(1.0, "#D96570")
            ctx.fillStyle = grad
        }
        ctx.fill()
    }
}
