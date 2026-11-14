import QtQuick

// A compact text button in the widget's chart style: a rounded pill that uses the
// ticker colour for the selected state (and, optionally, a lighter tint on hover).
// The range, chart-style and news-source rows all use this shape.
Rectangle {
    id: button

    property var applet
    property string text: ""
    property bool selected: false
    property bool hoverHighlight: false

    signal clicked()

    width: label.implicitWidth + 8
    height: 18
    radius: 4
    color: selected
           ? Qt.rgba(applet.tickerColor.r, applet.tickerColor.g, applet.tickerColor.b, 0.14)
           : (hoverHighlight && hover.containsMouse
              ? Qt.rgba(applet.tickerColor.r, applet.tickerColor.g, applet.tickerColor.b, 0.07)
              : "transparent")

    Text {
        id: label
        anchors.centerIn: parent
        text: button.text
        textFormat: Text.PlainText
        color: button.selected ? button.applet.tickerColor : button.applet.secondaryTextColor
        font.pixelSize: 9
        font.bold: true
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
