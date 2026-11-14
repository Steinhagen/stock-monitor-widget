import QtQuick
import "../domain/exchanges.js" as Exchanges

// The quote cache and the startup retry. The last successful batch is stored in the
// applet configuration so a launch without a network still has prices; only display
// values are kept (the chart is fetched fresh, since a stale graph would look live).
// Failed first requests are retried soon after, backing off to 30 s.
Item {
    id: cache

    property var applet
    property var model
    property var configuration
    property var config

    // A restored value is replaced by its own reply within moments on a working
    // network. A ticker that never answers must not keep its old price while the rest
    // shows live data, so it falls back to a placeholder after this grace period.
    readonly property int maxAgeSeconds: 7 * 24 * 60 * 60
    readonly property int rowGraceMs: 15000

    property double cachedQuotesTime: Number(configuration ? configuration.cachedQuotesTime : 0) || 0
    property bool showingCachedData: false
    property var snapshot: null

    // Startup retry state
    property int retryDelay: 5
    property int retryAttempts: 0
    property bool retryScheduled: false
    // Set only by a successful network response, never by cached data.
    property bool dataReceived: false

    Timer {
        id: retryTimer
        repeat: false
        onTriggered: {
            cache.retryScheduled = false;
            if (cache.dataReceived || cache.retryAttempts >= 8) return;
            cache.retryAttempts++;
            cache.retryDelay = Math.min(cache.retryDelay * 2, 30);
            // Respect the active-hours and weekend settings, like the normal timer.
            applet.checkTimeAndRefresh();
        }
    }

    function scheduleQuoteRetry() {
        if (dataReceived || retryScheduled || retryAttempts >= 8) return;
        retryScheduled = true;
        retryTimer.interval = retryDelay * 1000;
        retryTimer.start();
    }

    function noteQuoteReceived() {
        dataReceived = true;
        retryDelay = 5;
        retryAttempts = 0;
        retryScheduled = false;
        if (retryTimer.running) retryTimer.stop();
        // In multi mode the list stays marked as cached until every restored row has its
        // own network reply; one answered ticker must not make the others look live. In
        // single mode the caller that owns the header values clears the flag itself.
        if (applet.isMultiMode) refreshRowsState();
    }

    Timer {
        id: rowGraceTimer
        interval: cache.rowGraceMs
        repeat: false
        onTriggered: cache.dropUnrefreshed()
    }

    function refreshRowsState() {
        var any = false;
        for (var i = 0; i < model.count; i++) {
            if (model.get(i).cached === true) { any = true; break; }
        }
        showingCachedData = any;
        if (!any) {
            if (rowGraceTimer.running) rowGraceTimer.stop();
        } else if (dataReceived && !rowGraceTimer.running) {
            rowGraceTimer.start();
        }
    }

    // Drops the rows the network never refreshed, after the grace period.
    function dropUnrefreshed() {
        var dropped = false;
        for (var i = 0; i < model.count; i++) {
            var row = model.get(i);
            if (row.cached !== true) continue;
            model.set(i, {
                "price": "---", "change": "", "pct": "", "isPos": true,
                "currentRaw": 0.0, "prevClose": 0.0, "quoteTime": 0.0,
                "cached": false
            });
            dropped = true;
            if (row.ticker === applet.panelTicker) {
                applet.panelCurrentPrice = "---";
                applet.panelCurrentPercent = "+0.00%";
                applet.panelCurrentIsPositive = true;
                applet.panelCurrentIsCached = false;
                applet.currentPrice = "---";
                applet.priceChange = "";
                applet.percentChange = "";
                applet.currentRawPrice = 0;
                applet.previousClose = 0;
                applet.quoteTimestamp = 0;
            }
        }
        showingCachedData = false;
        if (dropped) queueSave();
    }

    // Parses the stored snapshot. Kept separate from read() because the startup refresh
    // timer can fire before Component.onCompleted, and the list still needs the rows.
    function parse() {
        if (!config) return null;
        var raw = config.cachedQuotes;
        var saved = Number(config.cachedQuotesTime) || 0;
        if (!raw || !(saved > 0)) return null;
        var data;
        try { data = JSON.parse(raw); } catch (e) { return null; }
        return data || null;
    }

    // Restores the cached snapshot at startup. The single view gets its values here; the
    // multi rows are filled by the watchlist fetch, which owns the row order.
    function read() {
        if (dataReceived) return;
        var data = parse();
        if (!data) return;
        var saved = Number(config.cachedQuotesTime) || 0;
        snapshot = data;
        cachedQuotesTime = saved;
        if (applet.isMultiMode) {
            // The refresh may be skipped at startup (weekend or outside the configured
            // hours); create the rows anyway so the cached values have somewhere to go.
            applet.ensureStockRows(applet.configuredTickers());
            applyToRows();
            return;
        }
        var s = data.single;
        // Never show another instrument's values after the configured ticker changed,
        // nor a change/percentage that belongs to a different data range.
        if (!s || s.ticker !== applet.singleTicker || s.range !== applet.effectiveChartRange
                || !s.price || s.price === "---") return;
        // Each half of the snapshot carries its own timestamp, so refreshing the list
        // never makes an older single-mode value look newer than it is.
        var singleTime = Number(data.singleTime) || saved;
        var now = Math.floor(Date.now() / 1000);
        if (now - singleTime > maxAgeSeconds) return;
        cachedQuotesTime = singleTime;
        showingCachedData = true;
        applet.singleCompanyName = s.name || applet.singleTicker;
        applet.singleExchange = s.exchange || Exchanges.shortLabel(applet.singleTicker, "", "");
        applet.singleExchangeFull = s.exchangeFull || applet.singleExchange;
        applet.currentPrice = s.price;
        applet.priceChange = s.change || "";
        applet.percentChange = s.pct || "";
        applet.isPositive = s.isPos !== false;
        applet.currentRawPrice = Number(s.currentRaw) || 0;
        applet.previousClose = Number(s.prevClose) || 0;
        applet.currencySym = s.currencySym || "";
        applet.quoteCurrency = s.currency || "";
        applet.quoteTimestamp = Number(s.quoteTime) || 0;
        // The panel follows the configured range, while the header may show the chart's
        // own range. Restore the panel values only when the two ranges agree.
        if (applet.effectiveChartRange === applet.chartRange) {
            applet.panelCurrentPrice = applet.currentPrice;
            applet.panelCurrentPercent = applet.percentChange;
            applet.panelCurrentIsPositive = applet.isPositive;
            applet.panelCurrentIsCached = true;
        }
        applet.lastUpdated = new Date(singleTime * 1000).toLocaleTimeString(Qt.locale(), "HH:mm");
        applet.nextUpdate = "";
        applet.singleDataRange = s.range;
        applet.singleDataTicker = s.ticker;
    }

    // Fills the list placeholders from the cached snapshot, matching by ticker so the
    // configured order and any newly added symbols are respected. Rows that already have
    // a live value are left alone, which also makes this safe on retries.
    function applyToRows() {
        if (!snapshot) snapshot = parse();
        var data = snapshot;
        if (!data || !data.rows || dataReceived) return;
        // The stored change and percentage belong to the range they were fetched with.
        if ((data.rowsRange || data.range) !== applet.chartRange) return;
        var rowsTime = Number(data.rowsTime) || cachedQuotesTime;
        var now = Math.floor(Date.now() / 1000);
        if (rowsTime > 0 && now - rowsTime > maxAgeSeconds) return;
        var applied = false;
        for (var i = 0; i < data.rows.length; i++) {
            var c = data.rows[i];
            if (!c || !c.ticker || !c.price || c.price === "---") continue;
            for (var k = 0; k < model.count; k++) {
                var row = model.get(k);
                if (row.ticker !== c.ticker || row.price !== "---") continue;
                model.set(k, {
                    "name": c.name || c.ticker,
                    "price": c.price || "---",
                    "change": c.change || "",
                    "pct": c.pct || "",
                    "isPos": c.isPos !== false,
                    "currentRaw": Number(c.currentRaw) || 0,
                    "prevClose": Number(c.prevClose) || 0,
                    "currencySym": c.currencySym || "",
                    "currency": c.currency || "",
                    "exchange": c.exchange || Exchanges.shortLabel(c.ticker, "", ""),
                    "exchangeFull": c.exchangeFull || "",
                    "quoteTime": Number(c.quoteTime) || 0,
                    "cached": true
                });
                applied = true;
                break;
            }
        }
        if (!applied) return;
        cachedQuotesTime = rowsTime > 0 ? rowsTime : cachedQuotesTime;
        showingCachedData = true;
        applet.lastUpdated = new Date(cachedQuotesTime * 1000).toLocaleTimeString(Qt.locale(), "HH:mm");
        applet.nextUpdate = "";
        applet.updatePanelFromRow(applet.panelTicker);
        // The two-column desktop view also shows the selected row in the single column.
        applySingleFromRow(applet.singleTicker);
    }

    // Mirrors selectTicker() for cached rows: price and currency always, the change and
    // the quote time only when the chart shares the list's range.
    function applySingleFromRow(ticker) {
        for (var i = 0; i < model.count; i++) {
            var row = model.get(i);
            if (row.ticker !== ticker || row.price === "---") continue;
            applet.singleCompanyName = row.name || ticker;
            applet.singleExchange = row.exchange || Exchanges.shortLabel(ticker, "", "");
            applet.singleExchangeFull = row.exchangeFull || applet.singleExchange;
            applet.currentRawPrice = Number(row.currentRaw) || 0;
            applet.currentPrice = row.price;
            applet.currencySym = row.currencySym || "";
            applet.quoteCurrency = row.currency || "";
            applet.previousClose = Number(row.prevClose) || 0;
            if (applet.effectiveChartRange === applet.chartRange) {
                applet.isPositive = row.isPos !== false;
                applet.priceChange = row.change || "";
                applet.percentChange = row.pct || "";
                applet.quoteTimestamp = Number(row.quoteTime) || 0;
            }
            return;
        }
    }

    // Writes are debounced because a refresh answers one ticker at a time.
    Timer {
        id: saveTimer
        interval: 1500
        repeat: false
        onTriggered: cache.write()
    }

    function queueSave() {
        if (showingCachedData) return;
        saveTimer.restart();
    }

    function stopPendingSave() {
        if (saveTimer.running) saveTimer.stop();
    }

    function stopGrace() {
        if (rowGraceTimer.running) rowGraceTimer.stop();
    }

    function write() {
        if (!configuration) return;
        var previous = null;
        try { previous = JSON.parse(config.cachedQuotes || "null"); } catch (e) {}
        var now = Math.floor(Date.now() / 1000);
        var data = { "time": now, "range": applet.chartRange, "rowsRange": applet.chartRange,
                     "rows": [], "rowsTime": 0, "single": null, "singleTime": 0 };

        for (var i = 0; i < model.count; i++) {
            var row = model.get(i);
            // Never re-stamp a restored value as if it had just been fetched.
            if (!row || !row.ticker || row.cached === true || row.price === "---") continue;
            data.rows.push({
                "ticker": row.ticker, "name": row.name,
                "price": row.price, "change": row.change, "pct": row.pct,
                "isPos": row.isPos,
                "currentRaw": row.currentRaw, "prevClose": row.prevClose,
                "currencySym": row.currencySym, "currency": row.currency,
                "exchange": row.exchange, "exchangeFull": row.exchangeFull,
                "quoteTime": row.quoteTime
            });
        }
        if (data.rows.length > 0) {
            data.rowsTime = now;
        } else if (previous && previous.rows && previous.rows.length > 0) {
            // The other view is the live source right now; keep its older snapshot with
            // its own timestamp instead of presenting it as just refreshed.
            data.rows = previous.rows;
            data.rowsRange = previous.rowsRange || previous.range || data.rowsRange;
            data.rowsTime = Number(previous.rowsTime) || Number(previous.time) || 0;
        }

        if (!applet.isMultiMode && !showingCachedData
                && applet.singleTicker !== "" && applet.singleDataTicker === applet.singleTicker
                && applet.currentPrice !== "---") {
            data.single = {
                "ticker": applet.singleTicker,
                "name": applet.singleCompanyName,
                "price": applet.currentPrice,
                "change": applet.priceChange,
                "pct": applet.percentChange,
                "isPos": applet.isPositive,
                "currentRaw": applet.currentRawPrice,
                "prevClose": applet.previousClose,
                "currencySym": applet.currencySym,
                "currency": applet.quoteCurrency,
                "exchange": applet.singleExchange,
                "exchangeFull": applet.singleExchangeFull,
                "quoteTime": applet.quoteTimestamp,
                "range": applet.singleDataRange || applet.effectiveChartRange
            };
            data.singleTime = now;
        } else if (previous && previous.single) {
            data.single = previous.single;
            data.singleTime = Number(previous.singleTime) || Number(previous.time) || 0;
        }

        if (data.rows.length === 0 && !data.single) return;
        data.time = Math.max(data.rowsTime, data.singleTime) || now;
        try {
            configuration.cachedQuotes = JSON.stringify(data);
            configuration.cachedQuotesTime = String(data.time);
            cachedQuotesTime = data.time;
            snapshot = data;
        } catch (e) { console.log("Error saving cached quotes: " + e); }
    }
}
