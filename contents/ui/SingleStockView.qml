// Delegates (all with required properties) may use the ids of this file, such as
// singleStockRoot and newsPane.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import "analyst"
import "single"

Rectangle {
    id: singleStockRoot

    property var rootItem

    // Widths for the header cap. TextMetrics is available as soon as the view is
    // built, unlike the width of a Text created later in the layout.
    TextMetrics {
        id: singleArrowMetrics
        font.pixelSize: 12
        text: "▲"
    }
    TextMetrics {
        id: singleExchangeMetrics
        font.pixelSize: 9
        font.bold: true
        text: rootItem.exchangeBadge(rootItem.singleTicker, rootItem.singleExchange)
    }

    // Hover crosshair state for the chart. Coordinates are local to the chart canvas.
    property bool chartHoverActive: false
    property real chartHoverX: 0
    // The chart reserves a small gap above the volume line while the analyst overlay
    // shows markers. The overlay updates this imperatively; a forward id binding was
    // not reliable while the child component was still being created.
    property bool analystMarkersShown: false

    // Background of the selected Chart/News icon, the same tint as a selected chart button.
    readonly property color selectedTint: Qt.rgba(rootItem.tickerColor.r, rootItem.tickerColor.g, rootItem.tickerColor.b, 0.14)
    // News pane: the headlines replace the chart; the cache and the fetch live in main.qml.
    readonly property bool newsMode: rootItem.newsAvailable && rootItem.singleViewPane === "news"
    readonly property var newsEntry: rootItem.newsEntry
    // Distinct sources among the shown headlines, in the order their newest item appears.
    // Other providers (BVB, for example) will add their label to the items they return.
    readonly property var newsSources: {
        var seen = {};
        var sources = [];
        var items = rootItem.newsItems;
        for (var i = 0; i < items.length; i++) {
            var source = String(items[i].source || "").trim();
            if (source === "" || seen[source]) continue;
            seen[source] = true;
            sources.push(source);
        }
        // Yahoo is the primary feed, BVB follows, then Google; unknown providers
        // are alphabetical.
        var order = ["Yahoo", "BVB", "Google"];
        sources.sort(function(a, b) {
            var ia = order.indexOf(a);
            var ib = order.indexOf(b);
            if (ia < 0) ia = order.length;
            if (ib < 0) ib = order.length;
            return ia !== ib ? ia - ib : a.localeCompare(b);
        });
        return sources;
    }
    // "" is All. A selection that is no longer among the sources falls back to All, so a
    // refresh that drops a source never leaves an empty list.
    property string newsSource: ""
    readonly property bool newsFilterRelevant: newsSources.length > 1
    readonly property string newsSourceFilter: newsSources.indexOf(newsSource) >= 0 ? newsSource : ""
    // What the "More on ..." link opens: the filtered provider, or for the combined list
    // the provider of the newest headline, so a BVB-only result does not send the user to
    // Yahoo. Falls back to the first provider, then Yahoo.
    readonly property string newsMoreSource: {
        if (newsSourceFilter !== "") return newsSourceFilter;
        var items = rootItem.newsItems;
        if (items.length > 0) {
            var source = String(items[0].source || "").trim();
            if (source !== "") return source;
        }
        return newsSources.length > 0 ? newsSources[0] : "Yahoo";
    }
    readonly property var newsFilteredItems: {
        var items = rootItem.newsItems;
        if (newsSourceFilter === "") return items;
        var filtered = [];
        for (var i = 0; i < items.length; i++) {
            if (String(items[i].source || "") === newsSourceFilter) filtered.push(items[i]);
        }
        return filtered;
    }
    // One button per source; All is added only when there is something to choose between.
    readonly property var newsSourceButtons: {
        var sources = newsSources;
        var buttons = [];
        if (sources.length > 1) buttons.push({ source: "", label: i18nc("@item:news source", "All") });
        for (var i = 0; i < sources.length; i++) buttons.push({ source: sources[i], label: sources[i] });
        return buttons;
    }
    readonly property bool newsHasItems: newsFilteredItems.length > 0
    // Centered message instead of the list: loading, nothing found, or no reply at all.
    readonly property string newsStateText: {
        if (newsHasItems) return "";
        if (!newsEntry || newsEntry.pending || (!newsEntry.loaded && !newsEntry.error))
            return i18n("Loading headlines…");
        if (newsEntry.error) return i18n("Headlines unavailable");
        return i18n("No recent headlines for %1", rootItem.displayTicker(rootItem.singleTicker));
    }
    // A failed update keeps the headlines that are already shown and says so here.
    readonly property bool newsHeaderWarning: newsEntry !== null && newsEntry.error && newsHasItems
    readonly property string newsHeaderText: {
        if (newsHeaderWarning) return i18n("Could not update headlines");
        if (newsEntry && newsEntry.loaded && newsEntry.time > 0)
            return i18n("Updated %1", rootItem.newsAge(newsEntry.time / 1000));
        return "";
    }

    // Extended quote and market session for the compact quote block. `extendedQuote`
    // is undefined while the regular session is running or when extended data is off.
    readonly property var extendedQuote: rootItem.extendedQuote(rootItem.singleTicker)
    readonly property bool hasExtendedQuote: extendedQuote !== undefined && extendedQuote !== null
    readonly property string marketSession: rootItem.marketStatusFor(rootItem.singleTicker)
    // Instruments without extended-hours trading (indices, for example) still report the
    // exchange's pre/post windows, but they are effectively closed during them. The list
    // already uses isMarketClosedFor() for that; the header must agree with it.
    readonly property bool marketClosed: rootItem.isMarketClosedFor(rootItem.singleTicker)
    readonly property string marketSessionText: {
        switch (marketSession) {
            case "pre":    return marketClosed
                                  ? i18nc("@item:market session status", "Closed")
                                  : i18nc("@item:market session status", "Pre-market");
            case "open":   return i18nc("@item:market session status", "Open");
            case "post":
            case "closed": return i18nc("@item:market session status", "Closed");
            default:       return "";
        }
    }
    readonly property color marketSessionColor: marketSession === "pre" && !marketClosed
        ? (rootItem.isLightTheme ? "#b47a12" : "#d9a441")
        : (marketSession === "open" ? rootItem.positiveColor : rootItem.secondaryTextColor)
    readonly property string extendedQuoteLabel: {
        if (!hasExtendedQuote) return "";
        return (extendedQuote.kind === "pre"
                ? i18nc("@item:compact quote", "Pre-market")
                : i18nc("@item:compact quote", "After-hours")).toUpperCase();
    }
    readonly property string noExtendedNote: {
        if (hasExtendedQuote || !rootItem.showExtendedHours || marketSession === "") return "";
        if (marketSession === "open") return "";
        // No extended quote can exist for these instruments, so the note would be noise.
        if (!rootItem.hasPrePostDataFor(rootItem.singleTicker)) return "";
        if (marketSession === "pre") return i18n("No pre-market quote");
        return i18n("No after-hours quote");
    }

    // Tooltip of the market status in the header. Yahoo Finance does not expose the feed
    // delay per exchange through the chart API, so the quote timestamp is shown next to
    // the widget's own refresh time instead of a hard-coded "15 minutes" that would be
    // wrong for exchanges with real-time data.
    readonly property bool marketDataAvailable: rootItem.lastUpdated !== ""
                                                 || rootItem.quoteTimestamp > 0
    readonly property bool waitingForFirstQuote: rootItem.awaitingFirstRegularQuote(rootItem.singleTicker)
    readonly property string marketDataQuoteTime: {
        // During the opening seconds the regular quote is still the previous close;
        // show the pre-market quote time that is actually on screen instead.
        var timestamp = singleStockRoot.extendedQuote && singleStockRoot.extendedQuote.time
                        ? singleStockRoot.extendedQuote.time : rootItem.quoteTimestamp;
        if (!(timestamp > 0)) return "";
        return new Date(timestamp * 1000)
            .toLocaleTimeString(Qt.locale(), "HH:mm");
    }
    readonly property string marketDataUpdatedLine: {
        // The cached startup values replace the usual line so their age stays visible.
        if (rootItem.currentShowingCached) return rootItem.currentStatusText;
        if (rootItem.lastUpdated === "") return "";
        return rootItem.nextUpdate !== ""
            ? i18n("Updated %1 · Next %2", rootItem.lastUpdated, rootItem.nextUpdate)
            : i18n("Updated %1", rootItem.lastUpdated);
    }
    readonly property string marketDataRefreshLabel: i18n("Refresh %1 min", rootItem.refreshIntervalMinutes)
    // Amber is too bright on a light tooltip and too dim on a dark one; pick a shade
    // that stays readable on the Plasma tooltip background.
    readonly property color marketDataWarnColor: Kirigami.Theme.backgroundColor.hslLightness > 0.5
                                                 ? "#8a5a00" : "#e0b25a"
    readonly property color marketDataWarnBackground: Qt.rgba(marketDataWarnColor.r,
                                                               marketDataWarnColor.g,
                                                               marketDataWarnColor.b, 0.10)

    // The 1D chart shows a previous trading session when there is nothing current yet
    // (weekend, holiday, or before the pre-market's first quote). Label it so the older
    // session is not read as today's; the previous close in the legend belongs to it too.
    readonly property string chartSessionNote: {
        if (rootItem.effectiveChartRange !== "1D") return "";
        if (rootItem.chartSessionCurrent || !(rootItem.chartSessionStart > 0)) return "";
        var session = new Date(rootItem.chartSessionStart * 1000);
        var now = new Date();
        var yesterday = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1);
        if (session.getFullYear() === yesterday.getFullYear()
                && session.getMonth() === yesterday.getMonth()
                && session.getDate() === yesterday.getDate())
            return i18n("Yesterday's session");
        return i18n("Session of %1", session.toLocaleDateString(Qt.locale(), "d MMM"));
    }

    // Minimum width of the card. It deliberately comes from the chart controls and a fixed
    // floor, not from contentColumn.implicitWidth: prices, percentages, company names and
    // positions change with the selected ticker and range, and using them made the minimum
    // (and therefore the split between the two desktop columns) move by a few pixels. Text
    // that grows with data no longer widens the card; it keeps its own elision/clipping.
    // Measure both control groups even when one is hidden: the range row alone stays under
    // the floor, while range + style crosses it, so deriving this from the visible row made
    // enabling the style buttons resize the whole applet. The reserved width never moves
    // when an option is toggled.
    readonly property real chartControlsWidth: chartRangeButtons.implicitWidth
                                                + chartStyleButtons.implicitWidth
                                                + 2 * chartHeaderRow.spacing
    readonly property real minimumContentWidth: Math.max(300, Math.ceil(chartControlsWidth) + 32)
    // Fixed floor, not content-derived: the extended-hours quote row appears and
    // disappears with the session. A moving minimum made Plasma resize the widget
    // when the row changed or when the widget was opened on an empty virtual desktop.
    readonly property real minimumContentHeight: 360

    // The Application preset paints its own rounded card; with Plasma the system
    // background shows through and this view stays transparent.
    color: rootItem.bgColor
    radius: rootItem.appDrawnSurface ? 22 : 0
    clip: true

    Text {
        anchors.centerIn: parent
        text: i18n("Loading...")
        color: rootItem.secondaryTextColor
        font.pixelSize: 14
        visible: rootItem.isMultiMode && singleStockRoot.visible && (!rootItem.chartDataPoints || rootItem.chartDataPoints.length === 0)
    }

    Item {
        id: singleView
        visible: rootItem.showTwoList || rootItem.singleTicker.trim() !== ""
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 16
        anchors.bottomMargin: 10

        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: 0

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
                        readonly property real nameMaxWidth: Math.max(0, contentColumn.width
                            - (headerStatusRow.visible ? headerStatusRow.implicitWidth
                               + headerStatusRow.Layout.leftMargin : 0)
                            - Math.max(10, Math.ceil(singleArrowMetrics.advanceWidth))
                            - (singleExchangeBadge.visible ? badgeWidth + 4 : 0)
                            - spacing * 2)

                        Text {
                            text: rootItem.isPositive ? "▲" : "▼"
                            color: rootItem.isPositive ? rootItem.positiveColor : rootItem.negativeColor
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
                                text: rootItem.showNameAndTicker
                                      ? rootItem.fitNameAndTicker(rootItem.singleCompanyName, rootItem.displayTicker(rootItem.singleTicker), singleHeaderNameRow.nameMaxWidth, singleNameMetrics)
                                      : (rootItem.swapNameAndTicker ? rootItem.singleCompanyName : rootItem.displayTicker(rootItem.singleTicker))
                                // The name keeps its natural width so the badge follows
                                // it, but never takes room from the status on the right.
                                width: Math.min(implicitWidth, singleHeaderNameRow.nameMaxWidth)
                                color: rootItem.tickerColor
                                opacity: rootItem.tickerOpacity / 100.0
                                font.bold: true
                                font.pixelSize: 15
                                font.family: "Arial"
                                elide: Text.ElideRight
                            }
                            // Short exchange label, e.g. BVB for BRD.RO, in the same mode as
                            // the watchlist. The full exchange name is in the tooltip.
                            Rectangle {
                                id: singleExchangeBadge
                                readonly property string label: rootItem.exchangeBadge(rootItem.singleTicker, rootItem.singleExchange)
                                visible: label !== ""
                                width: singleHeaderNameRow.badgeWidth
                                height: singleExchangeText.implicitHeight + Kirigami.Units.smallSpacing / 2
                                y: (singleNameGroup.height - height) / 2
                                radius: 3
                                color: Qt.rgba(rootItem.secondaryTextColor.r, rootItem.secondaryTextColor.g,
                                               rootItem.secondaryTextColor.b, 0.12)
                                border.width: 1
                                border.color: Qt.rgba(rootItem.secondaryTextColor.r, rootItem.secondaryTextColor.g,
                                                      rootItem.secondaryTextColor.b, 0.35)

                                Text {
                                    id: singleExchangeText
                                    anchors.centerIn: parent
                                    text: singleExchangeBadge.label
                                    color: rootItem.secondaryTextColor
                                    font.pixelSize: 9
                                    font.bold: true
                                    opacity: 0.85
                                }
                                HoverHandler { id: singleExchangeHover }
                                ToolTip.visible: singleExchangeHover.hovered
                                ToolTip.text: rootItem.singleExchangeFull || rootItem.singleExchange
                            }
                        }
                        Item { Layout.fillWidth: true }
                    }

                    Text {
                        // The first line already carries the company name when name and ticker are shown together.
                        visible: !rootItem.showNameAndTicker
                        text: rootItem.swapNameAndTicker
                              ? rootItem.displayTicker(rootItem.singleTicker) : rootItem.singleCompanyName
                        color: rootItem.secondaryTextColor
                        font.pixelSize: 10
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: rootItem.currentStatusText
                        color: rootItem.currentShowingCached ? rootItem.warningTextColor
                                                              : rootItem.secondaryTextColor
                        font.pixelSize: 9
                        // Cached values keep their age visible even when the user hid
                        // the normal refresh timestamps. The date makes the line longer
                        // than the usual time, so it must elide inside the card.
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        visible: rootItem.lastUpdated !== ""
                                 && (!rootItem.isMultiMode || rootItem.currentShowingCached)
                                 && (!rootItem.hideTimestamps || rootItem.currentShowingCached)
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
                    visible: singleStockRoot.marketSessionText !== "" || singleStockRoot.rootItem.newsAvailable

                    // The status (open/closed) doubles as the data-freshness affordance: its
                    // tooltip says how often the widget polls and when Yahoo last quoted this
                    // instrument, so delayed exchange data is visible without extra chrome.
                    PlasmaCore.ToolTipArea {
                        id: marketStatusTip
                        Layout.alignment: singleStockRoot.rootItem.newsAvailable ? Qt.AlignVCenter : Qt.AlignTop
                        implicitWidth: marketStatusRow.implicitWidth
                        implicitHeight: marketStatusRow.implicitHeight
                        visible: singleStockRoot.marketSessionText !== ""
                        active: singleStockRoot.marketDataAvailable
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
                                    color: singleStockRoot.marketSessionColor
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
                                        text: singleStockRoot.marketDataRefreshLabel
                                        color: Kirigami.Theme.disabledTextColor
                                        font.pixelSize: 9
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: singleStockRoot.marketDataUpdatedLine
                                color: Kirigami.Theme.textColor
                                font.pixelSize: 11
                                wrapMode: Text.WordWrap
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                visible: singleStockRoot.marketDataQuoteTime !== ""

                                Text {
                                    text: i18n("Yahoo quote %1", singleStockRoot.marketDataQuoteTime)
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
                                    color: singleStockRoot.marketDataWarnBackground
                                    border.width: 1
                                    border.color: Qt.rgba(singleStockRoot.marketDataWarnColor.r,
                                                          singleStockRoot.marketDataWarnColor.g,
                                                          singleStockRoot.marketDataWarnColor.b, 0.28)

                                    Text {
                                        id: marketTipDelayLabel
                                        anchors.centerIn: parent
                                        text: i18n("may be delayed")
                                        color: singleStockRoot.marketDataWarnColor
                                        font.pixelSize: 9
                                        font.weight: Font.DemiBold
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: singleStockRoot.waitingForFirstQuote
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
                                color: singleStockRoot.marketSessionColor
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Text {
                                text: singleStockRoot.marketSessionText
                                color: rootItem.secondaryTextColor
                                font.pixelSize: 9
                                Layout.alignment: Qt.AlignVCenter
                                // Centering the line box puts the x-height center 1 px below
                                // the dot and the icons; this lifts the text by 1 px (the dot
                                // stays centered on the taller cell).
                                Layout.bottomMargin: singleStockRoot.rootItem.newsAvailable ? 2 : 0
                            }
                        }
                    }

                    // Chart / News view selector, at the right edge of the header so it does
                    // not move with the length of the name. Hidden (not laid out) when the
                    // news is off.
                    Row {
                        id: viewPaneButtons
                        Layout.alignment: Qt.AlignVCenter
                        visible: singleStockRoot.rootItem.newsAvailable
                        spacing: 2

                        Repeater {
                            model: [
                                { pane: "chart", icon: "office-chart-line", tip: i18nc("@info:tooltip", "Chart") },
                                { pane: "news", icon: "news-subscribe", tip: i18nc("@info:tooltip", "News") }
                            ]
                            delegate: PlasmaCore.ToolTipArea {
                                id: paneButton
                                required property var modelData
                                readonly property bool selected: singleStockRoot.rootItem.singleViewPane === modelData.pane
                                width: 22
                                height: 20
                                mainText: modelData.tip

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 4
                                    color: paneButton.selected ? singleStockRoot.selectedTint
                                           : (paneMouse.containsMouse
                                              ? Qt.rgba(singleStockRoot.rootItem.tickerColor.r,
                                                        singleStockRoot.rootItem.tickerColor.g,
                                                        singleStockRoot.rootItem.tickerColor.b, 0.07)
                                              : "transparent")
                                }

                                Kirigami.Icon {
                                    anchors.centerIn: parent
                                    width: 16
                                    height: 16
                                    source: paneButton.modelData.icon
                                    isMask: true
                                    color: paneButton.selected ? singleStockRoot.rootItem.tickerColor
                                                               : singleStockRoot.rootItem.secondaryTextColor
                                }

                                MouseArea {
                                    id: paneMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: singleStockRoot.rootItem.singleViewPane = paneButton.modelData.pane
                                }
                            }
                        }
                    }
                }
            }

            // Two quote columns: the regular session and the extended session that is
            // relevant now (pre-market or after-hours). When there is no extended quote,
            // the single row below takes over instead of leaving an empty column.
            RowLayout {
                id: extendedQuoteRow
                readonly property color accent: singleStockRoot.hasExtendedQuote && singleStockRoot.extendedQuote.isPos
                                                ? rootItem.positiveColor : rootItem.negativeColor
                // Width shared by the two columns: the row minus the divider and its margins.
                readonly property real avail: width - extendedDivider.Layout.preferredWidth
                                              - extendedDivider.Layout.leftMargin - extendedDivider.Layout.rightMargin
                visible: singleStockRoot.hasExtendedQuote
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
                        color: rootItem.secondaryTextColor
                        font.pixelSize: 8
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.5
                    }

                    Text {
                        id: priceText
                        text: singleStockRoot.waitingForFirstQuote ? "—" : rootItem.currentPrice
                        color: rootItem.priceColor
                        opacity: rootItem.priceOpacity / 100.0
                        font.pixelSize: 25
                        Layout.fillWidth: true
                        elide: Text.ElideRight

                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }

                    Text {
                        text: singleStockRoot.waitingForFirstQuote ? ""
                              : (rootItem.priceChange !== ""
                                 ? rootItem.priceChange + " (" + rootItem.percentChange + ")" : "")
                        color: rootItem.isPositive ? rootItem.positiveColor : rootItem.negativeColor
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
                    color: rootItem.isLightTheme ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.075)
                }

                ColumnLayout {
                    id: extendedColumn
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 1

                    Text {
                        text: singleStockRoot.extendedQuoteLabel
                        color: singleStockRoot.hasExtendedQuote && singleStockRoot.extendedQuote.kind === "pre"
                               ? singleStockRoot.marketSessionColor : rootItem.secondaryTextColor
                        font.pixelSize: 8
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.5
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: singleStockRoot.hasExtendedQuote ? singleStockRoot.extendedQuote.price : ""
                        color: rootItem.priceColor
                        opacity: rootItem.priceOpacity / 100.0
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
                            text: singleStockRoot.hasExtendedQuote
                                  ? singleStockRoot.extendedQuote.change + " (" + singleStockRoot.extendedQuote.pct + ")" : ""
                            color: parent.accent
                            font.pixelSize: 9
                            font.weight: Font.Bold
                        }
                    }
                }
            }

            RowLayout {
                visible: !singleStockRoot.hasExtendedQuote
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                Layout.topMargin: 4
                spacing: 10

                Text {
                    text: i18nc("@item:compact quote", "Regular").toUpperCase()
                    color: rootItem.secondaryTextColor
                    font.pixelSize: 8
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.5
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    id: priceTextCompact
                    text: singleStockRoot.waitingForFirstQuote ? "—" : rootItem.currentPrice
                    color: rootItem.priceColor
                    opacity: rootItem.priceOpacity / 100.0
                    font.pixelSize: 25
                    Layout.alignment: Qt.AlignVCenter
                    Layout.minimumWidth: implicitWidth

                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                Text {
                    text: singleStockRoot.waitingForFirstQuote ? ""
                          : (rootItem.priceChange !== ""
                             ? rootItem.priceChange + " (" + rootItem.percentChange + ")" : "")
                    color: rootItem.isPositive ? rootItem.positiveColor : rootItem.negativeColor
                    font.pixelSize: 10
                    font.bold: true
                    Layout.alignment: Qt.AlignVCenter
                    Layout.minimumWidth: implicitWidth
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: singleStockRoot.noExtendedNote
                    visible: text !== ""
                    color: rootItem.secondaryTextColor
                    opacity: 0.72
                    font.pixelSize: 8
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                }
            }

            // Data-range selector shown in the chart when enabled in the settings. It uses
            // the same range values as the configuration page, but lets the range be changed
            // without opening the configuration dialog.
            RowLayout {
                id: chartHeaderRow
                // Bind to the settings, not to the children's visible: a child reads as
                // invisible while this row is hidden, which would keep the row hidden for good.
                // The news pane needs the row for its "Updated…" line and refresh button, but
                // merely enabling the news must not reserve an empty bar over the chart.
                visible: singleStockRoot.rootItem.showChartRangeButtons
                         || singleStockRoot.rootItem.showChartStyleButtons
                         || singleStockRoot.chartSessionNote !== ""
                         || singleStockRoot.newsMode
                Layout.fillWidth: true
                Layout.topMargin: 6
                Layout.bottomMargin: 2
                Layout.preferredHeight: Math.max(
                    singleStockRoot.rootItem.showChartRangeButtons ? chartRangeButtons.implicitHeight : 0,
                    singleStockRoot.rootItem.showChartStyleButtons ? 18 : 0,
                    singleStockRoot.chartSessionNote !== "" ? 14 : 0,
                    singleStockRoot.newsMode ? 18 : 0)
                spacing: 6
                // A Row, not a Flow: the buttons stay on one row and its implicitWidth (the
                // one-row width) feeds the card's minimum width.
                Row {
                    id: chartRangeButtons
                    objectName: "chartRangeButtons"
                    Layout.minimumWidth: implicitWidth
                    Layout.alignment: Qt.AlignTop
                    spacing: 3
                    visible: rootItem.showChartRangeButtons
                    // Stays laid out with the headlines (so the card's minimum width does
                    // not change when switching) but is not shown and takes no clicks.
                    opacity: singleStockRoot.newsMode ? 0 : 1
                    enabled: !singleStockRoot.newsMode

                    Repeater {
                        model: ["1D", "5D", "1M", "6M", "YTD", "1Y", "5Y", "Max"]
                        delegate: Rectangle {
                            id: rangeButton
                            objectName: "chartRangeButton_" + modelData
                            required property string modelData
                            readonly property bool selected: rangeButton.modelData === rootItem.effectiveChartRange
                            // Same weight in both states, so the selected range changes only the
                            // colors. A bold selected label would change this row's implicit width,
                            // and with it the content-derived minimum width of the card, shifting
                            // the two desktop columns by a pixel whenever another range is picked.
                            width: rangeButtonLabel.implicitWidth + 8
                            height: 18
                            radius: 4
                            color: selected
                                   ? Qt.rgba(rootItem.tickerColor.r, rootItem.tickerColor.g, rootItem.tickerColor.b, 0.14)
                                   : "transparent"

                            Text {
                                id: rangeButtonLabel
                                anchors.centerIn: parent
                                text: rootItem.chartRangeButtonLabel(rangeButton.modelData)
                                color: rangeButton.selected ? rootItem.tickerColor : rootItem.secondaryTextColor
                                font.pixelSize: 9
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: rootItem.setChartViewRange(rangeButton.modelData)
                            }
                        }
                    }
                }

                // Pushes the chart type selector to the right edge. The session note is
                // anchored inside this gap, so it never changes the card's minimum width.
                Item {
                    id: chartHeaderGap
                    Layout.fillWidth: true

                    Text {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: singleStockRoot.chartSessionNote
                        visible: text !== "" && !singleStockRoot.newsMode
                        color: rootItem.secondaryTextColor
                        opacity: 0.8
                        font.pixelSize: 9
                        elide: Text.ElideRight
                    }

                    // News header. A plain child of the gap Item, placed over the whole
                    // header row, so it never takes part in the row's layout.
                    Item {
                        visible: singleStockRoot.newsMode
                        x: -chartHeaderGap.x
                        y: -chartHeaderGap.y
                        width: chartHeaderRow.width
                        height: chartHeaderRow.height

                        RowLayout {
                            anchors.fill: parent
                            spacing: 6

                            // Source filters, in the same compact style as the chart
                            // range buttons.
                            Row {
                                id: newsSourceFilters
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 3

                                Repeater {
                                    model: singleStockRoot.newsSourceButtons
                                    delegate: Rectangle {
                                        id: newsSourceButton
                                        required property var modelData
                                        objectName: "newsSourceButton_" + (newsSourceButton.modelData.source === ""
                                                                            ? "all" : newsSourceButton.modelData.source)
                                        readonly property bool selected: !singleStockRoot.newsFilterRelevant
                                                                         || singleStockRoot.newsSourceFilter === newsSourceButton.modelData.source
                                        width: newsSourceButtonLabel.implicitWidth + 8
                                        height: 18
                                        radius: 4
                                        color: newsSourceButton.selected
                                               ? singleStockRoot.selectedTint
                                               : (newsSourceMouse.containsMouse
                                                  ? Qt.rgba(singleStockRoot.rootItem.tickerColor.r,
                                                            singleStockRoot.rootItem.tickerColor.g,
                                                            singleStockRoot.rootItem.tickerColor.b, 0.07)
                                                  : "transparent")

                                        Text {
                                            id: newsSourceButtonLabel
                                            anchors.centerIn: parent
                                            text: newsSourceButton.modelData.label
                                            textFormat: Text.PlainText
                                            color: newsSourceButton.selected ? singleStockRoot.rootItem.tickerColor
                                                                             : singleStockRoot.rootItem.secondaryTextColor
                                            font.pixelSize: 9
                                            font.bold: true
                                        }

                                        MouseArea {
                                            id: newsSourceMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                singleStockRoot.newsSource = newsSourceButton.modelData.source;
                                                newsPane.positionViewAtBeginning();
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                Layout.alignment: Qt.AlignVCenter
                                horizontalAlignment: Text.AlignRight
                                text: singleStockRoot.newsHeaderText
                                textFormat: Text.PlainText
                                color: singleStockRoot.newsHeaderWarning ? singleStockRoot.rootItem.warningTextColor
                                                                         : singleStockRoot.rootItem.secondaryTextColor
                                font.pixelSize: 9
                                elide: Text.ElideRight
                            }

                            PlasmaCore.ToolTipArea {
                                id: newsRefreshButton
                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 18
                                mainText: i18n("Refresh news")

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 4
                                    color: newsRefreshMouse.containsMouse ? singleStockRoot.selectedTint : "transparent"
                                }
                                Kirigami.Icon {
                                    anchors.centerIn: parent
                                    width: 14
                                    height: 14
                                    source: "view-refresh"
                                    isMask: true
                                    color: singleStockRoot.rootItem.secondaryTextColor
                                    opacity: singleStockRoot.newsEntry && singleStockRoot.newsEntry.pending ? 0.5 : 1
                                }
                                MouseArea {
                                    id: newsRefreshMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: singleStockRoot.rootItem.requestNews(singleStockRoot.rootItem.singleTicker, true)
                                }
                            }
                        }
                    }
                }
                // Chart type selector, same look as the range buttons. It writes the same
                // setting as the Chart & News page.
                Row {
                    id: chartStyleButtons
                    objectName: "chartStyleButtons"
                    visible: rootItem.showChartStyleButtons
                    opacity: singleStockRoot.newsMode ? 0 : 1
                    enabled: !singleStockRoot.newsMode
                    Layout.minimumWidth: implicitWidth
                    Layout.alignment: Qt.AlignTop | Qt.AlignRight
                    spacing: 3
                    Repeater {
                        model: [
                            { style: 0, label: i18nc("@item:chart style", "Line") },
                            { style: 1, label: i18nc("@item:chart style", "Candles") }
                        ]
                        delegate: Rectangle {
                            id: styleButton
                            objectName: "chartStyleButton_" + modelData.style
                            required property var modelData
                            readonly property bool selected: styleButton.modelData.style === rootItem.chartStyle
                            // Same as the range buttons: same weight in both states, so switching
                            // between Line and Candles cannot resize the card either.
                            width: styleButtonLabel.implicitWidth + 8
                            height: 18
                            radius: 4
                            color: selected
                                   ? Qt.rgba(rootItem.tickerColor.r, rootItem.tickerColor.g, rootItem.tickerColor.b, 0.14)
                                   : "transparent"
                            Text {
                                id: styleButtonLabel
                                anchors.centerIn: parent
                                text: styleButton.modelData.label
                                color: styleButton.selected ? rootItem.tickerColor : rootItem.secondaryTextColor
                                font.pixelSize: 9
                                font.bold: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: rootItem.setChartStyle(styleButton.modelData.style)
                            }
                        }
                    }
                }
            }
            Item {
                id: chartArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                // Room for the price scale, the time axis and, when enabled, the volume bars.
                Layout.minimumHeight: 130
                Layout.preferredHeight: 130
                Layout.topMargin: 8
                Layout.bottomMargin: 4

                ChartCanvas {
                    id: singleCanvas
                    anchors.fill: parent
                    visible: !singleStockRoot.newsMode
                             && Array.isArray(singleStockRoot.rootItem.chartDataPoints)
                             && singleStockRoot.rootItem.chartDataPoints.length > 0
                    applet: singleStockRoot.rootItem
                    host: singleStockRoot
                }

                // --- News pane: the headline list replaces the chart. ---
                NewsPane {
                    id: newsPane
                    anchors.fill: parent
                    applet: singleStockRoot.rootItem
                    active: singleStockRoot.newsMode
                    items: singleStockRoot.newsFilteredItems
                    stateText: singleStockRoot.newsStateText
                    moreSource: singleStockRoot.newsMoreSource
                    sources: singleStockRoot.newsSources
                }

                // The hover/click area lives inside the chart now. It must not cover the
                // range buttons above the plot.
                MouseArea {
                    id: chartMouseArea
                    anchors.fill: parent
                    visible: !singleStockRoot.newsMode
                    z: 100
                    hoverEnabled: true
                    cursorShape: singleStockRoot.chartHoverActive ? Qt.CrossCursor : Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                    onPositionChanged: (mouse) => {
                        singleStockRoot.chartHoverActive = true;
                        singleStockRoot.chartHoverX = mouse.x;
                    }
                    onExited: singleStockRoot.chartHoverActive = false

                    onClicked: (mouse) => {
                        if (mouse.button === Qt.MiddleButton) {
                            if (rootItem.performMiddleClick(rootItem.singleTicker)) {
                                if (priceText) priceText.opacity = 0.3;
                                if (priceTextCompact) priceTextCompact.opacity = 0.3;
                                timerFullFlicker.restart();
                            }
                        } else if (mouse.button === Qt.RightButton) {
                            chartMenu.popup();
                        }
                    }
                    onDoubleClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton)
                            rootItem.performDoubleClick(rootItem.singleTicker);
                    }

                    Menu {
                        id: chartMenu

                        MenuItem {
                            text: i18n("Open on Yahoo Finance")
                            onTriggered: rootItem.openYahooQuote(rootItem.singleTicker)
                        }
                        MenuItem {
                            text: i18n("Refresh")
                            onTriggered: rootItem.refreshData()
                        }
                    }

                    Timer {
                        id: timerFullFlicker
                        interval: 300
                        onTriggered: {
                            if (priceText) priceText.opacity = Qt.binding(function() { return rootItem.priceOpacity / 100.0; });
                            if (priceTextCompact) priceTextCompact.opacity = Qt.binding(function() { return rootItem.priceOpacity / 100.0; });
                        }
                    }
                }

                // The marker overlay owns its geometry, shapes and details popup.
                AnalystMarkers {
                    id: analystMarkers
                    anchors.fill: parent
                    z: 110
                    applet: rootItem
                    chartVisible: !singleStockRoot.newsMode

                    onMarkersShownChanged: singleStockRoot.analystMarkersShown = analystMarkers.markersShown
                    Component.onCompleted: singleStockRoot.analystMarkersShown = analystMarkers.markersShown
                }
            }

            // One line for the whole position: all the lots of this ticker added up (shares,
            // average cost, value, total gain, gain over the shown period).
            PositionLine {
                Layout.fillWidth: true
                Layout.topMargin: 3
                // The width comes only from the space in the card, never from the line itself,
                // so choosing the parts by width cannot loop.
                Layout.minimumWidth: 0
                Layout.preferredWidth: 0
                rootItem: singleStockRoot.rootItem
                summary: singleStockRoot.rootItem.showPortfolioMode ? singleStockRoot.rootItem.portfolioSummary : null
                sym: singleStockRoot.rootItem.currencySym
                periodLabel: singleStockRoot.rootItem.chartPeriodLabel
                centered: true
            }
        }
    }


    // ── Chart drawing ────────────────────────────────────────────
    // Settings → Chart selects between:
    //   0 = reference line split at yesterday's close
    //   1 = candlesticks
    // Both use the same right-hand price scale and the same time scale below. The
    // trading-volume strip is optional and works for either style; it only covers the
    // regular session because Yahoo reports no usable pre-market/after-hours volume.

    // Round tick values for a price scale, roughly `targetCount` of them.
}
