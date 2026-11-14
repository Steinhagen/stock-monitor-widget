// Delegates (all with required properties) may use the ids of this file, such as
// singleStockRoot and newsPane.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import "single"

Rectangle {
    id: singleStockRoot

    property var rootItem

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
    readonly property real chartControlsWidth: chartControls.rangeButtonsWidth
                                                + chartControls.styleButtonsWidth
                                                + 2 * chartControls.rowSpacing
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

            StockHeader {
                id: stockHeader
                applet: singleStockRoot.rootItem
                host: singleStockRoot
                contentWidth: contentColumn.width
            }

            QuoteBlock {
                id: quoteBlock
                applet: singleStockRoot.rootItem
                host: singleStockRoot
            }


            // Data-range selector shown in the chart when enabled in the settings. It uses
            // the same range values as the configuration page, but lets the range be changed
            // without opening the configuration dialog.
            ChartControls {
                id: chartControls
                applet: singleStockRoot.rootItem
                host: singleStockRoot
                newsPane: newsPane
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
                                quoteBlock.flicker();
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
                            quoteBlock.restorePriceOpacity();
                        }
                    }
                }

                // The marker overlay owns its geometry, shapes and details popup.
                AnalystOverlay {
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
