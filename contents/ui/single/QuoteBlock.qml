pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// The current quote: the regular session and the extended session that is relevant now,
// or the compact single-row price when there is no extended quote.
ColumnLayout {
    id: quote
    property var applet
    property var host
    Layout.fillWidth: true
    spacing: 0

            // Two quote columns: the regular session and the extended session that is
            // relevant now (pre-market or after-hours). When there is no extended quote,
            // the single row below takes over instead of leaving an empty column.
            RowLayout {
                id: extendedQuoteRow
                readonly property color accent: host.hasExtendedQuote && host.extendedQuote.isPos
                                                ? applet.positiveColor : applet.negativeColor
                // Width shared by the two columns: the row minus the divider and its margins.
                readonly property real avail: width - extendedDivider.Layout.preferredWidth
                                              - extendedDivider.Layout.leftMargin - extendedDivider.Layout.rightMargin
                visible: host.hasExtendedQuote
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                Layout.topMargin: 4
                spacing: 0

                ColumnLayout {
                    // Half of the row, not a share proportional to the text widths: with two
                    // fillWidth columns the divider moved with every price (and jumped while
                    // the price showed "—"). The column grows past half only when its own
                    // content needs it, and gives up room when the extended column needs it.
                    Layout.fillWidth: false
                    Layout.minimumWidth: 0
                    Layout.preferredWidth: Math.max(Math.ceil(implicitWidth),
                                                    Math.min(extendedQuoteRow.avail / 2,
                                                             extendedQuoteRow.avail - Math.ceil(extendedColumn.implicitWidth)))
                    spacing: 1

                    Text {
                        text: i18nc("@item:compact quote", "Regular").toUpperCase()
                        color: applet.secondaryTextColor
                        font.pixelSize: 8
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.5
                    }

                    Text {
                        id: priceText
                        text: host.waitingForFirstQuote ? "—" : applet.currentPrice
                        color: applet.priceColor
                        opacity: applet.priceOpacity / 100.0
                        font.pixelSize: 25
                        Layout.fillWidth: true
                        elide: Text.ElideRight

                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }

                    Text {
                        text: host.waitingForFirstQuote ? ""
                              : (applet.priceChange !== ""
                                 ? applet.priceChange + " (" + applet.percentChange + ")" : "")
                        color: applet.isPositive ? applet.positiveColor : applet.negativeColor
                        font.pixelSize: 10
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    id: extendedDivider
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 46
                    Layout.leftMargin: 12
                    Layout.rightMargin: 12
                    Layout.alignment: Qt.AlignVCenter
                    color: applet.isLightTheme ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.075)
                }

                ColumnLayout {
                    id: extendedColumn
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 1

                    Text {
                        text: host.extendedQuoteLabel
                        color: host.hasExtendedQuote && host.extendedQuote.kind === "pre"
                               ? host.marketSessionColor : applet.secondaryTextColor
                        font.pixelSize: 8
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.5
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: host.hasExtendedQuote ? host.extendedQuote.price : ""
                        color: applet.priceColor
                        opacity: applet.priceOpacity / 100.0
                        font.pixelSize: 18
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        readonly property color accent: extendedQuoteRow.accent
                        Layout.preferredWidth: extendedChange.implicitWidth + 8
                        Layout.preferredHeight: extendedChange.implicitHeight + 4
                        radius: 4
                        color: Qt.rgba(accent.r, accent.g, accent.b, 0.13)
                        border.color: Qt.rgba(accent.r, accent.g, accent.b, 0.4)
                        border.width: 1

                        Text {
                            id: extendedChange
                            anchors.centerIn: parent
                            text: host.hasExtendedQuote
                                  ? host.extendedQuote.change + " (" + host.extendedQuote.pct + ")" : ""
                            color: parent.accent
                            font.pixelSize: 9
                            font.weight: Font.Bold
                        }
                    }
                }
            }

            RowLayout {
                visible: !host.hasExtendedQuote
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                Layout.topMargin: 4
                spacing: 10

                Text {
                    text: i18nc("@item:compact quote", "Regular").toUpperCase()
                    color: applet.secondaryTextColor
                    font.pixelSize: 8
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.5
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    id: priceTextCompact
                    text: host.waitingForFirstQuote ? "—" : applet.currentPrice
                    color: applet.priceColor
                    opacity: applet.priceOpacity / 100.0
                    font.pixelSize: 25
                    Layout.alignment: Qt.AlignVCenter
                    Layout.minimumWidth: implicitWidth

                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                Text {
                    text: host.waitingForFirstQuote ? ""
                          : (applet.priceChange !== ""
                             ? applet.priceChange + " (" + applet.percentChange + ")" : "")
                    color: applet.isPositive ? applet.positiveColor : applet.negativeColor
                    font.pixelSize: 10
                    font.bold: true
                    Layout.alignment: Qt.AlignVCenter
                    Layout.minimumWidth: implicitWidth
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: host.noExtendedNote
                    visible: text !== ""
                    color: applet.secondaryTextColor
                    opacity: 0.72
                    font.pixelSize: 8
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                }
            }
    }

    // Briefly dim the price when a middle-click refresh starts.
    function flicker() {
        if (priceText) priceText.opacity = 0.3;
        if (priceTextCompact) priceTextCompact.opacity = 0.3;
    }
    function restorePriceOpacity() {
        if (priceText)
            priceText.opacity = Qt.binding(function() { return applet.priceOpacity / 100.0; });
        if (priceTextCompact)
            priceTextCompact.opacity = Qt.binding(function() { return applet.priceOpacity / 100.0; });
    }
}
