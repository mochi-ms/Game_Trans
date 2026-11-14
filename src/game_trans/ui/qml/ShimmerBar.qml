import QtQuick

// AI gradient shimmer loading bar
Rectangle {
    id: root
    height: 12
    radius: 6
    clip: true
    color: Qt.rgba(66/255, 133/255, 244/255, 0.20)

    property bool active: visible

    Rectangle {
        id: sweep
        width: root.width * 1.4
        height: root.height
        radius: 6
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(66/255, 133/255, 244/255, 0.0) }
            GradientStop { position: 0.35; color: Qt.rgba(155/255, 114/255, 203/255, 0.85) }
            GradientStop { position: 0.65; color: Qt.rgba(217/255, 101/255, 112/255, 0.65) }
            GradientStop { position: 1.0; color: Qt.rgba(66/255, 133/255, 244/255, 0.0) }
        }

        NumberAnimation on x {
            running: root.active && !backend.reduceMotion
            loops: Animation.Infinite
            from: -sweep.width
            to: root.width + 20
            duration: 1500
        }
    }
}
