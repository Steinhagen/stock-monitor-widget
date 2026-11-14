import QtQuick

// The large current-price label: themed colour, configured opacity, and the brief dim
// while a refresh is in flight.
Text {
    id: price

    property var applet
    property bool dimmed: false

    color: applet ? applet.priceColor : "#ffffff"
    opacity: dimmed ? 0.3 : (applet ? applet.priceOpacity / 100.0 : 1.0)
    Behavior on opacity { NumberAnimation { duration: 150 } }
}
