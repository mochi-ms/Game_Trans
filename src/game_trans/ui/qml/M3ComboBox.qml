import QtQuick
import QtQuick.Controls.Basic

// Custom Material 3 / Gemini dark ComboBox avoiding stock blue focus rings and light-mode popups.
ComboBox {
    id: root
    implicitHeight: 38
    implicitWidth: 200
    font.family: Theme.fontFamily
    font.pixelSize: 13

    delegate: ItemDelegate {
        id: del
        width: root.width
        height: 36
        text: root.textAt(index)
        highlighted: root.highlightedIndex === index

        contentItem: Row {
            spacing: 8
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12
            anchors.rightMargin: 12

            Text {
                width: parent.width - 22
                text: del.text
                color: root.currentIndex === index ? Theme.primary : Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: root.currentIndex === index ? Font.Medium : Font.Normal
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }

            MonoIcon {
                visible: root.currentIndex === index
                width: 14
                height: 14
                name: "check"
                iconColor: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        background: Rectangle {
            radius: 8
            color: del.hovered || del.highlighted ? Theme.navActiveBg : "transparent"
        }
    }

    indicator: MonoIcon {
        x: root.width - width - 12
        y: root.topPadding + (root.availableHeight - height) / 2
        width: 14
        height: 14
        name: "chevron_down"
        iconColor: Theme.textSecondary
    }

    contentItem: TextField {
        leftPadding: 12
        rightPadding: 34
        text: root.editable ? root.editText : root.displayText
        enabled: root.editable
        autoScroll: root.editable
        readOnly: !root.editable
        inputMethodHints: root.inputMethodHints
        validator: root.validator
        selectByMouse: true
        font: root.font
        color: Theme.textPrimary
        placeholderTextColor: Theme.textMuted
        selectionColor: Theme.primaryContainer
        selectedTextColor: Theme.textPrimary
        verticalAlignment: Text.AlignVCenter
        background: Item {}
        onAccepted: root.accepted()
    }

    background: Rectangle {
        implicitWidth: 200
        implicitHeight: 38
        radius: 10
        color: Theme.surface
        border.width: 1
        border.color: root.activeFocus || root.popup.visible ? Theme.primary : Theme.outline
    }

    popup: Popup {
        y: root.height + 4
        width: root.width
        implicitHeight: Math.min(contentItem.implicitHeight + 12, 260)
        padding: 6

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: root.popup.visible ? root.delegateModel : null
            currentIndex: root.highlightedIndex
            ScrollIndicator.vertical: ScrollIndicator {}
        }

        background: Rectangle {
            color: "#1B1C20"
            radius: 12
            border.width: 1
            border.color: Theme.outline
        }
    }
}
