import QtQuick
import "../domain/chart.js" as Chart
import "../domain/candles.js" as Candles
import "../domain/exchanges.js" as Exchanges
import "../domain/format.js" as Format
import "../domain/symbols.js" as Symbols
import "../providers/yahoo/chart.js" as YahooChart

// The multi-stock watchlist: the row model, the row order, the per-symbol quote
// requests and the reply processing. The cached-quote layer still lives in main.qml for
// now and is reached through the applet.
Item {
    id: watchlist

    property var applet
    property var store
    property var market
    property var singleQuotes

    readonly property ListModel model: rows

    ListModel { id: rows }

    // The configured watchlist, cleaned and in display order.
    function configuredTickers() {
        var tickers = String(applet.multiTickers || "").split(",");
        var list = [];
        tickers.forEach(function(t) {
            var clean = t.trim();
            if (clean !== "") list.push(clean);
        });
        if (applet.sortAlphabetically) {
            list.sort(function(a, b) {
                return a.localeCompare(b);
            });
        }
        return list;
    }

    // Creates the list placeholders in display order and keeps the panel selection.
    function ensureRows(targetTickers) {
        var defaultPanelTicker = targetTickers.length > 0 ? targetTickers[0] : "";
        applet.panelTicker = applet.manualPanelTickerOverride !== ""
                             && targetTickers.indexOf(applet.manualPanelTickerOverride) !== -1
                             ? applet.manualPanelTickerOverride : defaultPanelTicker;
        applet.singleTicker = applet.panelTicker;

        if (rows.count === targetTickers.length) return;
        rows.clear();
        targetTickers.forEach(function(cleanSymbol) {
            rows.append({
                "ticker": cleanSymbol,
                "name": applet.loadingText,
                "price": "---",
                "change": "",
                "pct": "",
                "isPos": true,
                "chartPoints": "[]",
                "chartTimes": "[]",
                // ListModel does not create a role from a null value; use an empty
                // object as the placeholder and treat it as "no sessions" on read.
                "chartSessions": ({}),
                "chartCandles": "[]",
                "chartRef": 0.0,
                "chartPre": false,
                "chartSessionStart": 0.0,
                "chartSessionCurrent": true,
                "quoteTime": 0.0,
                "prevClose": 0.0,
                "currentRaw": 0.0,
                "currencySym": "",
                "currency": "",
                "exchange": Exchanges.shortLabel(cleanSymbol, "", ""),
                "exchangeFull": "",
                "cached": false
            });
        });
    }

    function fetch() {
        var range = applet.chartRange;
        var targets = configuredTickers();
        ensureRows(targets);

        // Show the previous values (marked as cached) while the replies are in flight.
        applet.applyCachedQuotesToRows();

        targets.forEach(function(symbol) {
            YahooChart.get(symbol, range, applet.showExtendedHours, function(response, error) {
                if (error) { applet.scheduleQuoteRetry(); return; }
                // Ignore a reply for a range the user has already switched away from.
                if (range !== applet.chartRange) return;
                processRow(symbol, response, range);
            });
        });
    }

    function processRow(symbol, json, range) {
        var listRange = range || applet.chartRange;
        // When both views use the same range, the chart can reuse this response. With a
        // chart-only range, the chart is refreshed by its own request instead.
        if (applet.isMultiMode && symbol === applet.panelTicker
                && listRange === applet.effectiveChartRange) {
            singleQuotes.process(json, symbol, listRange);
        }
        try {
            var result = json.chart.result[0];
            var meta = result.meta;
            market.setMarketSession(symbol, meta);
            var quote = result.indicators.quote[0] || {};
            var quotes = quote.close || [];
            var timestamps = result.timestamp;

            var current = meta.regularMarketPrice;
            var curSym = Format.currencySymbol(meta.currency);

            var startTime = (meta.currentTradingPeriod && meta.currentTradingPeriod.regular) ? meta.currentTradingPeriod.regular.start : 0;
            var chartDay = listRange === "1D" ? Chart.chartDayFor(meta, timestamps, quotes) : null;
            var preChart = listRange === "1D" && Chart.isPreSessionDay(meta, chartDay);
            var listDay = (listRange === "1D" && applet.showExtendedHours) ? chartDay : null;
            var cleanChart = Chart.cleanChartData(quotes, timestamps, startTime, listRange, quote, listDay);
            if (listRange === "1D")
                Chart.seedFirstSessionPoint(cleanChart, (listDay && listDay.regular) ? listDay.regular.start : startTime, meta);
            var cleanData = cleanChart.values;
            var prev;
            if (listRange === "1D") {
                prev = meta.regularMarketPreviousClose || meta.previousClose || meta.chartPreviousClose;
            } else {
                prev = meta.chartPreviousClose;
                if (!prev || prev === 0) {
                    prev = cleanData.length > 0 ? cleanData[0] : meta.regularMarketPreviousClose;
                }
            }

            var change = current - prev;
            var pct = prev > 0 ? (change / prev) * 100 : 0;

            // Keep the chart state of the list range with the row, so selecting it can
            // show its graph immediately instead of waiting for another request.
            var chartSessions = (listDay && cleanData.length >= 2)
                                ? Chart.extendedSessionSeries(quotes, timestamps, listDay) : null;
            var chartCandles = Candles.chartCandlesFor(cleanChart, listRange, quote, timestamps, listDay);
            var chartRef = preChart ? (meta.regularMarketPrice || 0) : 0;
            if (!(chartRef > 0))
                chartRef = Chart.dailyPreviousClose(meta, cleanData.length > 0 ? cleanData[0] : 0);
            // The session label shown above the chart travels with the cached chart, so a
            // selection that reuses it does not keep the previous ticker's label.
            var sessionStart = (chartDay && chartDay.regular) ? chartDay.regular.start : 0;
            var sessionCurrent = !(sessionStart > 0)
                || !(meta.currentTradingPeriod)
                || (meta.currentTradingPeriod.regular && sessionStart === meta.currentTradingPeriod.regular.start)
                || (meta.currentTradingPeriod.pre && sessionStart === meta.currentTradingPeriod.pre.start);

            var exchange = Exchanges.shortLabel(symbol, meta.exchangeName, meta.fullExchangeName);
            var exchangeFull = Exchanges.fullLabel(symbol, meta.exchangeName, meta.fullExchangeName);
            var itemData = {
                "ticker": symbol,
                "name": Symbols.companyName(meta, symbol),
                "price": curSym + Format.number(current, false, applet.hideDecimals, applet.formatPrices),
                "change": Format.number(change, true, applet.hideDecimals, applet.formatPrices),
                "pct": Format.number(pct, true, applet.hideDecimals, applet.formatPrices) + "%",
                "isPos": change >= 0,
                "chartPoints": JSON.stringify(cleanData),
                "chartTimes": JSON.stringify(cleanChart.times),
                "chartSessions": chartSessions,
                "chartCandles": JSON.stringify(chartCandles),
                "chartRef": chartRef,
                "chartPre": preChart,
                "chartSessionStart": sessionStart,
                "chartSessionCurrent": sessionCurrent,
                "quoteTime": meta.regularMarketTime || 0,
                "prevClose": prev,
                "currentRaw": current,
                "currencySym": curSym,
                "currency": meta.currency || "",
                "exchange": exchange,
                "exchangeFull": exchangeFull,
                "cached": false
            };

            if (applet.isMultiMode && symbol === applet.panelTicker) {
                store.panelCurrentPrice = itemData.price;
                store.panelCurrentPercent = itemData.pct;
                store.panelCurrentIsPositive = itemData.isPos;
                store.panelCurrentIsCached = false;
                store.singleExchange = itemData.exchange;
                store.singleExchangeFull = itemData.exchangeFull;
            }

            var found = false;
            for (var k = 0; k < rows.count; k++) {
                if (rows.get(k).ticker === symbol) {
                    rows.set(k, itemData);
                    found = true;
                    break;
                }
            }
            if (!found) rows.append(itemData);

            var now = new Date();
            applet.lastUpdated = now.toLocaleTimeString(Qt.locale(), "HH:mm");
            var next = new Date(now.getTime() + (applet.refreshIntervalMinutes * 60000));
            applet.nextUpdate = next.toLocaleTimeString(Qt.locale(), "HH:mm");
            applet.noteQuoteReceived();
            applet.queueQuotesCacheSave();
        } catch (e) { console.log("Error parsing multi: " + e); }
    }
}
