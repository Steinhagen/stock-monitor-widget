import QtQuick
import "../domain/exchanges.js" as Exchanges

// User intents that are not tied to a single view: selecting a row, the configurable
// mouse actions, the chart range/style buttons and the two-column divider. The views
// call these through main.qml, which remains the applet root.
Item {
    id: actions

    property var applet
    property var model
    property var configuration

    function openYahooQuote(symbol) {
        var clean = symbol ? String(symbol).trim() : "";
        if (clean === "") return;
        Qt.openUrlExternally("https://finance.yahoo.com/quote/" + clean);
    }

    // Left click on a watchlist row: select it (recommended) or open its quote page.
    function performRowLeftClick(symbol) {
        if (applet.mouseRowLeftAction === "open") openYahooQuote(symbol);
        else selectTicker(symbol);
    }

    // Middle click on a row, the chart or the panel indicator. Returns true when the
    // action was a refresh, so the caller can show the existing opacity flicker.
    function performMiddleClick(symbol) {
        if (applet.mouseMiddleAction === "refresh") {
            applet.refreshData();
            return true;
        }
        if (applet.mouseMiddleAction === "open") openYahooQuote(symbol);
        return false;
    }

    function performDoubleClick(symbol) {
        if (applet.mouseDoubleClickAction === "open") openYahooQuote(symbol);
    }

    // Chart range selected from the buttons. Applied and fetched right away; the config
    // write is only for persistence, so the UI does not wait for it.
    function setChartViewRange(range) {
        if (range === applet.effectiveChartRange) return;
        applet.chartViewRangeActive = range;
        if (applet.singleTicker.trim() !== "")
            applet.fetchSingleStock(applet.singleTicker, range);
        if (!configuration) return;
        try {
            configuration.chartViewRange = range;
        } catch (e) {
            console.log("Error saving chart range: " + e);
        }
    }

    // Chart type selected from the chart buttons. It writes the same setting as the
    // Chart & News page, so both stay in sync.
    function setChartStyle(style) {
        if (style === applet.chartStyle || !configuration) return;
        try {
            configuration.chartStyle = style;
        } catch (e) {
            console.log("Error saving chart style: " + e);
        }
    }

    // Side-by-side layout: the divider applies the width live and the configuration is
    // written only when the drag ends, so moving it does not hammer the config file.
    function setTwoColumnLeftWidth(width) {
        var value = Math.round(width);
        if (value < 0) value = 0;
        if (value !== applet.twoColumnLeftWidth) applet.twoColumnLeftWidth = value;
    }

    function saveTwoColumnLeftWidth() {
        if (!configuration) return;
        try {
            configuration.twoColumnLeftWidth = applet.twoColumnLeftWidth;
        } catch (e) {
            console.log("Error saving two-column width: " + e);
        }
    }

    // Copy the list row's values (configured data range) into the panel indicator.
    function updatePanelFromRow(ticker) {
        for (var i = 0; i < model.count; i++) {
            var row = model.get(i);
            if (row.ticker !== ticker) continue;
            applet.panelCurrentPrice = row.price;
            applet.panelCurrentPercent = row.pct;
            applet.panelCurrentIsPositive = row.isPos;
            applet.panelCurrentIsCached = row.cached === true;
            return;
        }
    }

    // ListModel turns a top-level array role into a nested ListModel, so the chart
    // arrays are cached as JSON strings and decoded here. Without this, selecting a list
    // row handed a ListModel to the Canvas, which blanked the chart.
    function chartArray(value) {
        if (!value) return [];
        if (Array.isArray(value)) return value;
        try {
            var parsed = JSON.parse(value);
            return Array.isArray(parsed) ? parsed : [];
        } catch (e) {
            return [];
        }
    }

    function selectTicker(ticker, persist) {
        var clean = ticker ? String(ticker).trim() : "";
        if (clean === "") return;
        applet.manualPanelTickerOverride = clean;
        applet.panelTicker = clean;
        // Auto-cycle changes the panel stock every few seconds; persisting those would
        // rewrite the config constantly. Only explicit user selections are remembered.
        if (persist !== false && configuration) {
            try {
                configuration.selectedTicker = clean;
            } catch (e) {
                console.log("Error saving selected ticker: " + e);
            }
        }
        updatePanelFromRow(clean);

        // Use the row that is already in the list so the title, quote, portfolio and
        // graph switch together, then refresh the chart in the background. Without
        // this, the header changed immediately while the chart waited for the reply.
        var row = null;
        for (var i = 0; i < model.count; i++) {
            if (model.get(i).ticker === clean) {
                row = model.get(i);
                break;
            }
        }
        var chartFromCache = false;
        // A row that has not been quoted yet has no exchange metadata; fall back to the
        // suffix so the badge appears immediately.
        applet.singleExchange = Exchanges.shortLabel(clean, "", "");
        applet.singleExchangeFull = applet.singleExchange;
        if (row) {
            applet.singleCompanyName = row.name;
            applet.singleExchange = row.exchange || applet.singleExchange;
            applet.singleExchangeFull = row.exchangeFull || applet.singleExchange;
            applet.currentRawPrice = row.currentRaw;
            applet.currentPrice = row.price;
            applet.currencySym = row.currencySym;
            applet.quoteCurrency = row.currency;
            applet.previousClose = row.prevClose;
            // The change and the chart itself depend on the selected range. They can only
            // be reused when the list and the chart share the range.
            if (applet.effectiveChartRange === applet.chartRange) {
                applet.isPositive = row.isPos;
                applet.priceChange = row.change;
                applet.percentChange = row.pct;
                applet.chartDataPoints = chartArray(row.chartPoints);
                applet.chartTimestamps = chartArray(row.chartTimes);
                var sessions = row.chartSessions;
                applet.chartSessions = (sessions && sessions.preValues !== undefined)
                                       ? sessions : null;
                applet.chartCandles = chartArray(row.chartCandles);
                applet.chartReferencePrice = row.chartRef;
                applet.chartPreSession = row.chartPre === true;
                applet.chartSessionStart = row.chartSessionStart || 0;
                applet.chartSessionCurrent = row.chartSessionCurrent !== false;
                applet.quoteTimestamp = row.quoteTime || 0;
                chartFromCache = applet.chartDataPoints.length > 0;
            }
        }

        // Switching to a row uses what was already fetched for it; the list refresh (and
        // middle-click) keep that data current. Ask for a chart only when the row has no
        // cached chart yet, or when the chart range differs from the list's.
        var needsChart = !chartFromCache || applet.effectiveChartRange !== applet.chartRange;
        if (applet.singleTicker !== clean) {
            applet.singleTicker = clean;
            if (needsChart) applet.fetchSingleStock(clean, applet.effectiveChartRange);
        } else if (needsChart) {
            applet.fetchSingleStock(clean, applet.effectiveChartRange);
        }
    }
}
