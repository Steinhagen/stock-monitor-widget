import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore

// A small icon button with a tooltip, the pill-shaped hover/selection background and
// the ticker/text colours of the widget. Used by the Chart/News switch and the news
// refresh button.
PlasmaCore.ToolTipArea {
    id: action

    property var applet
    property string icon: ""
    property bool selected: false
    property real iconSize: 16
    property real iconOpacity: 1
    // The Chart/News buttons tint lightly on hover; the refresh button uses the
    // selection tint.
    property real hoverOpacity: 0.07

    signal clicked()

    Rectangle {
        anchors.fill: parent
        radius: 4
        color: action.selected
               ? Qt.rgba(action.applet.tickerColor.r, action.applet.tickerColor.g,
                         action.applet.tickerColor.b, 0.14)
               : (mouse.containsMouse
                  ? Qt.rgba(action.applet.tickerColor.r, action.applet.tickerColor.g,
                            action.applet.tickerColor.b, action.hoverOpacity)
                  : "transparent")
    }

    Kirigami.Icon {
        anchors.centerIn: parent
        width: action.iconSize
        height: action.iconSize
        source: action.icon
        isMask: true
        color: action.selected ? action.applet.tickerColor : action.applet.secondaryTextColor
        opacity: action.iconOpacity
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: action.clicked()
    }
}
