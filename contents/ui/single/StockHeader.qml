pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore

// The name, exchange badge, market status and the Chart/News switch at the top of the
// single-stock view. The parent supplies the width the name may use.
RowLayout {
    id: header
    property var applet
    property var host
    property real contentWidth: 0
    Layout.fillWidth: true
    spacing: 0

    // Widths for the header cap, available before the layout has widths.
    TextMetrics {
        id: singleArrowMetrics
        font.pixelSize: 12
        text: "▲"
    }
    TextMetrics {
        id: singleExchangeMetrics
        font.pixelSize: 9
        font.bold: true
        text: applet ? applet.exchangeBadge(applet.singleTicker, applet.singleExchange) : ""
    }

    ColumnLayout {
        id: headerNameColumn
        spacing: 2
        // Never let a stale or too-wide name paint over the status and the
        // Chart/News icons; the elision keeps it inside in normal use.
        clip: true
        Layout.alignment: Qt.AlignLeft | Qt.AlignTop
        // Take the space left of the status, so a long "Name (TICK)"
        // is elided instead of pushing the status out of the card.
        Layout.fillWidth: true
        Layout.minimumWidth: 0

        RowLayout {
            id: singleHeaderNameRow
            Layout.fillWidth: true
            spacing: 5

            readonly property real badgeWidth: singleExchangeBadge.visible
                ? Math.ceil(singleExchangeMetrics.advanceWidth)
                  + Kirigami.Units.smallSpacing * 2 : 0
            // Derive the room from the card, not from this row's own width. A
            // width read back from the layout feeds the elided text into the
            // row's implicit width; when the status line appears the row can
            // then no longer shrink, so the full name is painted over the
            // status and the Chart/News icons. Reserving the status row here
            // keeps the calculation one-way.
            readonly property real nameMaxWidth: Math.max(0, header.contentWidth
                - (headerStatusRow.visible ? headerStatusRow.implicitWidth
                   + headerStatusRow.Layout.leftMargin : 0)
                - Math.max(10, Math.ceil(singleArrowMetrics.advanceWidth))
                - (singleExchangeBadge.visible ? badgeWidth + 4 : 0)
                - spacing * 2)

            Text {
                text: applet.isPositive ? "▲" : "▼"
                color: applet.isPositive ? applet.positiveColor : applet.negativeColor
                font.pixelSize: 12
                Layout.alignment: Qt.AlignVCenter
            }

            Row {
                id: singleNameGroup
                // The name already carries its own elided width; let the
                // layout shrink the group to it instead of treating the full
                // company name as an unbreakable minimum.
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignVCenter
                spacing: 4

                Text {
                    id: singleNameText
                    FontMetrics { id: singleNameMetrics; font: singleNameText.font }
                    // Use the header width available to the name, not this Text.width:
                    // width depends on implicitWidth, which depends on the text.
                    text: applet.showNameAndTicker
                          ? applet.fitNameAndTicker(applet.singleCompanyName, applet.displayTicker(applet.singleTicker), singleHeaderNameRow.nameMaxWidth, singleNameMetrics)
                          : (applet.swapNameAndTicker ? applet.singleCompanyName : applet.displayTicker(applet.singleTicker))
                    // The name keeps its natural width so the badge follows
                    // it, but never takes room from the status on the right.
                    width: Math.min(implicitWidth, singleHeaderNameRow.nameMaxWidth)
                    color: applet.tickerColor
                    opacity: applet.tickerOpacity / 100.0
                    font.bold: true
                    font.pixelSize: 15
                    font.family: "Arial"
                    elide: Text.ElideRight
                }
                // Short exchange label, e.g. BVB for BRD.RO, in the same mode as
                // the watchlist. The full exchange name is in the tooltip.
                Rectangle {
                    id: singleExchangeBadge
                    readonly property string label: applet.exchangeBadge(applet.singleTicker, applet.singleExchange)
                    visible: label !== ""
                    width: singleHeaderNameRow.badgeWidth
                    height: singleExchangeText.implicitHeight + Kirigami.Units.smallSpacing / 2
                    y: (singleNameGroup.height - height) / 2
                    radius: 3
                    color: Qt.rgba(applet.secondaryTextColor.r, applet.secondaryTextColor.g,
                                   applet.secondaryTextColor.b, 0.12)
                    border.width: 1
                    border.color: Qt.rgba(applet.secondaryTextColor.r, applet.secondaryTextColor.g,
                                          applet.secondaryTextColor.b, 0.35)

                    Text {
                        id: singleExchangeText
                        anchors.centerIn: parent
                        text: singleExchangeBadge.label
                        color: applet.secondaryTextColor
                        font.pixelSize: 9
                        font.bold: true
                        opacity: 0.85
                    }
                    HoverHandler { id: singleExchangeHover }
                    ToolTip.visible: singleExchangeHover.hovered
                    ToolTip.text: applet.singleExchangeFull || applet.singleExchange
                }
            }
            Item { Layout.fillWidth: true }
        }

        Text {
            // The first line already carries the company name when name and ticker are shown together.
            visible: !applet.showNameAndTicker
            text: applet.swapNameAndTicker
                  ? applet.displayTicker(applet.singleTicker) : applet.singleCompanyName
            color: applet.secondaryTextColor
            font.pixelSize: 10
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Text {
            text: applet.currentStatusText
            color: applet.currentShowingCached ? applet.warningTextColor
                                                  : applet.secondaryTextColor
            font.pixelSize: 9
            // Cached values keep their age visible even when the user hid
            // the normal refresh timestamps. The date makes the line longer
            // than the usual time, so it must elide inside the card.
            Layout.fillWidth: true
            elide: Text.ElideRight
            visible: applet.lastUpdated !== ""
                     && (!applet.isMultiMode || applet.currentShowingCached)
                     && (!applet.hideTimestamps || applet.currentShowingCached)
        }
    }

    // The market status and the Chart/News icons share one row, so both are
    // centered on the icons' 20 px height. With the news off the row holds only
    // the status, at the same place as before.
    RowLayout {
        id: headerStatusRow
        Layout.alignment: Qt.AlignRight | Qt.AlignTop
        Layout.leftMargin: 8
        // The 20 px icon buttons are taller than a name line alone. They may overhang
        // the row by a pixel or two, but never make the header taller than before.
        Layout.maximumHeight: headerNameColumn.implicitHeight
        spacing: 10
        // Not bound to marketStatusTip.visible: a child reads as hidden while its
        // parent is, so the row could never show again. Without this, an empty row
        // would still keep its margin from the name while the status is hidden.
        visible: host.marketSessionText !== "" || applet.newsAvailable

        // The status (open/closed) doubles as the data-freshness affordance: its
        // tooltip says how often the widget polls and when Yahoo last quoted this
        // instrument, so delayed exchange data is visible without extra chrome.
        PlasmaCore.ToolTipArea {
            id: marketStatusTip
            Layout.alignment: applet.newsAvailable ? Qt.AlignVCenter : Qt.AlignTop
            implicitWidth: marketStatusRow.implicitWidth
            implicitHeight: marketStatusRow.implicitHeight
            visible: host.marketSessionText !== ""
            active: host.marketDataAvailable
            mainText: i18n("Market data")
            mainItem: ColumnLayout {
                implicitWidth: 340
                spacing: 5

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        width: 6
                        height: 6
                        radius: 3
                        color: host.marketSessionColor
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Text {
                        text: i18n("Market data")
                        color: Kirigami.Theme.textColor
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: marketTipRefreshLabel.implicitWidth + 12
                        implicitHeight: marketTipRefreshLabel.implicitHeight + 4
                        radius: height / 2
                        color: Qt.rgba(Kirigami.Theme.textColor.r,
                                       Kirigami.Theme.textColor.g,
                                       Kirigami.Theme.textColor.b, 0.06)
                        border.width: 1
                        border.color: Qt.rgba(Kirigami.Theme.textColor.r,
                                              Kirigami.Theme.textColor.g,
                                              Kirigami.Theme.textColor.b, 0.12)

                        Text {
                            id: marketTipRefreshLabel
                            anchors.centerIn: parent
                            text: host.marketDataRefreshLabel
                            color: Kirigami.Theme.disabledTextColor
                            font.pixelSize: 9
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: host.marketDataUpdatedLine
                    color: Kirigami.Theme.textColor
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: host.marketDataQuoteTime !== ""

                    Text {
                        text: i18n("Yahoo quote %1", host.marketDataQuoteTime)
                        color: Kirigami.Theme.disabledTextColor
                        font.pixelSize: 10
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: marketTipDelayLabel.implicitWidth + 12
                        implicitHeight: marketTipDelayLabel.implicitHeight + 4
                        radius: height / 2
                        color: host.marketDataWarnBackground
                        border.width: 1
                        border.color: Qt.rgba(host.marketDataWarnColor.r,
                                              host.marketDataWarnColor.g,
                                              host.marketDataWarnColor.b, 0.28)

                        Text {
                            id: marketTipDelayLabel
                            anchors.centerIn: parent
                            text: i18n("may be delayed")
                            color: host.marketDataWarnColor
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: host.waitingForFirstQuote
                    text: i18n("The market is open; waiting for its first regular quote.")
                    color: Kirigami.Theme.disabledTextColor
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                }
            }

            RowLayout {
                id: marketStatusRow
                anchors.fill: parent
                spacing: 4

                Rectangle {
                    width: 5
                    height: 5
                    radius: 2.5
                    color: host.marketSessionColor
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: host.marketSessionText
                    color: applet.secondaryTextColor
                    font.pixelSize: 9
                    Layout.alignment: Qt.AlignVCenter
                    // Centering the line box puts the x-height center 1 px below
                    // the dot and the icons; this lifts the text by 1 px (the dot
                    // stays centered on the taller cell).
                    Layout.bottomMargin: applet.newsAvailable ? 2 : 0
                }
            }
        }

        // Chart / News view selector, at the right edge of the header so it does
        // not move with the length of the name. Hidden (not laid out) when the
        // news is off.
        Row {
            id: viewPaneButtons
            Layout.alignment: Qt.AlignVCenter
            visible: applet.newsAvailable
            spacing: 2

            Repeater {
                model: [
                    { pane: "chart", icon: "office-chart-line", tip: i18nc("@info:tooltip", "Chart") },
                    { pane: "news", icon: "news-subscribe", tip: i18nc("@info:tooltip", "News") }
                ]
                delegate: PlasmaCore.ToolTipArea {
                    id: paneButton
                    required property var modelData
                    readonly property bool selected: applet.singleViewPane === modelData.pane
                    width: 22
                    height: 20
                    mainText: modelData.tip

                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: paneButton.selected ? host.selectedTint
                               : (paneMouse.containsMouse
                                  ? Qt.rgba(applet.tickerColor.r,
                                            applet.tickerColor.g,
                                            applet.tickerColor.b, 0.07)
                                  : "transparent")
                    }

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 16
                        height: 16
                        source: paneButton.modelData.icon
                        isMask: true
                        color: paneButton.selected ? applet.tickerColor
                                                   : applet.secondaryTextColor
                    }

                    MouseArea {
                        id: paneMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: applet.singleViewPane = paneButton.modelData.pane
                    }
                }
            }
        }
    }
}

// Two quote columns: the regular session and the extended session that is
// relevant now (pre-market or after-hours). When there is no extended quote,
// the single row below takes over instead of leaving an empty column.
