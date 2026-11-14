import QtQuick
import "../domain/chart.js" as Chart
import "../domain/candles.js" as Candles
import "../domain/exchanges.js" as Exchanges
import "../domain/format.js" as Format
import "../domain/symbols.js" as Symbols
import "../providers/yahoo/chart.js" as YahooChart

// The single-stock and panel quote requests: fetching one symbol and turning the Yahoo
// chart reply into the values QuoteStore exposes. The multi-stock list keeps its own
// row processing in main.qml for now; it calls process() when it can reuse a reply.
Item {
    id: quotes

    property var applet
    property var store
    property var market
    property var stockModel

    function fetch(symbol, range) {
        var chartRange = range || applet.effectiveChartRange;
        YahooChart.get(symbol, chartRange, applet.showExtendedHours, function(response, error) {
            if (error) { applet.scheduleQuoteRetry(); return; }
            // Ignore a reply for a range or symbol the user has already switched away from.
            if (chartRange !== applet.effectiveChartRange || symbol !== applet.singleTicker) return;
            process(response, symbol, chartRange);
        });
    }

    // Quote for the compact panel indicator, fetched separately when the chart uses a
    // range of its own. The panel always follows the configured data range.
    function fetchPanel(symbol) {
        var range = applet.chartRange;
        YahooChart.get(symbol, range, applet.showExtendedHours, function(response, error) {
            if (error) { applet.scheduleQuoteRetry(); return; }
            if (range !== applet.chartRange || symbol !== applet.panelSymbol) return;
            processPanel(response, symbol, range);
        });
    }

    function processPanel(json, symbol, range) {
        try {
            var result = json.chart.result[0];
            var meta = result.meta;
            market.setMarketSession(symbol, meta);
            if (!applet.isMultiMode && symbol === applet.singleTicker) {
                store.singleExchange = Exchanges.shortLabel(symbol, meta.exchangeName, meta.fullExchangeName);
                store.singleExchangeFull = Exchanges.fullLabel(symbol, meta.exchangeName, meta.fullExchangeName);
            }
            var current = meta.regularMarketPrice;
            var curSym = Format.currencySymbol(meta.currency);
            var prev;
            if (range === "1D") {
                prev = meta.regularMarketPreviousClose || meta.previousClose || meta.chartPreviousClose;
            } else {
                prev = meta.chartPreviousClose;
                if (!prev || prev === 0) {
                    var quotes = result.indicators.quote[0].close;
                    var timestamps = result.timestamp;
                    var startTime = (meta.currentTradingPeriod && meta.currentTradingPeriod.regular) ? meta.currentTradingPeriod.regular.start : 0;
                    var cleanData = Chart.cleanChartData(quotes, timestamps, startTime, range).values;
                    prev = cleanData.length > 0 ? cleanData[0] : meta.regularMarketPreviousClose;
                }
            }
            var change = current - prev;
            store.panelCurrentPrice = curSym + Format.number(current, false, applet.hideDecimals, applet.formatPrices);
            store.panelCurrentPercent = Format.number(prev > 0 ? (change / prev) * 100 : 0, true,
                                                     applet.hideDecimals, applet.formatPrices) + "%";
            store.panelCurrentIsPositive = change >= 0;
            store.panelCurrentIsCached = false;
            applet.noteQuoteReceived();
        } catch (e) { console.log("Error parsing panel quote: " + e); }
    }

    function process(json, fallbackSymbol, range) {
        try {
            var chartRange = range || applet.effectiveChartRange;
            var result = json.chart.result[0];
            var meta = result.meta;
            var symbol = fallbackSymbol || applet.singleTicker;
            market.setMarketSession(symbol, meta);
            var quote = result.indicators.quote[0] || {};
            var quotes = quote.close || [];
            var timestamps = result.timestamp;

            applet.singleCompanyName = Symbols.companyName(meta, fallbackSymbol || applet.singleTicker);
            store.singleExchange = Exchanges.shortLabel(symbol, meta.exchangeName, meta.fullExchangeName);
            store.singleExchangeFull = Exchanges.fullLabel(symbol, meta.exchangeName, meta.fullExchangeName);
            store.currencySym = Format.currencySymbol(meta.currency);
            store.quoteCurrency = meta.currency || "";
            store.currentRawPrice = meta.regularMarketPrice;
            store.quoteTimestamp = meta.regularMarketTime || 0;
            store.currentPrice = store.currencySym
                                 + Format.number(meta.regularMarketPrice, false,
                                                 applet.hideDecimals, applet.formatPrices);

            var startTime = (meta.currentTradingPeriod && meta.currentTradingPeriod.regular) ? meta.currentTradingPeriod.regular.start : 0;
            // The 1D chart plots the running pre-market, or the last completed regular
            // session when there is nothing current to show (see chartDayFor).
            var chartDay = chartRange === "1D" ? Chart.chartDayFor(meta, timestamps, quotes) : null;
            var preChart = chartRange === "1D" && Chart.isPreSessionDay(meta, chartDay);
            var day = (chartRange === "1D" && applet.showExtendedHours) ? chartDay : null;
            store.chartSessionStart = (chartDay && chartDay.regular) ? chartDay.regular.start : 0;
            // The chart is "current" when it shows today's pre-market or regular session;
            // otherwise it still shows a previous session and the view labels it.
            store.chartSessionCurrent = !(store.chartSessionStart > 0)
                || !(meta.currentTradingPeriod)
                || (meta.currentTradingPeriod.regular && store.chartSessionStart === meta.currentTradingPeriod.regular.start)
                || (meta.currentTradingPeriod.pre && store.chartSessionStart === meta.currentTradingPeriod.pre.start);
            store.chartPreSession = preChart;
            var chart = Chart.cleanChartData(quotes, timestamps, startTime, chartRange, quote, day);
            if (chartRange === "1D")
                Chart.seedFirstSessionPoint(chart, (day && day.regular) ? day.regular.start : startTime, meta);
            var cleanData = chart.values;
            store.chartSessions = (day && cleanData.length >= 2)
                                  ? Chart.extendedSessionSeries(quotes, timestamps, day) : null;
            store.chartDataPoints = cleanData;
            store.chartTimestamps = chart.times;

            // The candlestick chart can be drawn from the same response; the reference
            // chart marks yesterday's close, so it reads the same way as the daily change.
            store.chartCandles = Candles.chartCandlesFor(chart, chartRange, quote, timestamps, day);
            // The pre-market is measured against the last regular close (the official
            // close, as shown in the regular quote); the regular chart uses the close
            // before the session it shows.
            var reference = preChart ? (meta.regularMarketPrice || 0) : 0;
            store.chartReferencePrice = reference > 0 ? reference
                : Chart.dailyPreviousClose(meta, cleanData.length > 0 ? cleanData[0] : 0);

            // Keep the row's cached chart in sync with every fresh chart, so choosing that
            // row again does not briefly show the older snapshot from the list refresh.
            if (applet.isMultiMode && chartRange === applet.chartRange && stockModel) {
                for (var ci = 0; ci < stockModel.count; ci++) {
                    if (stockModel.get(ci).ticker === symbol) {
                        stockModel.set(ci, {
                            "chartPoints": JSON.stringify(cleanData),
                            "chartTimes": JSON.stringify(chart.times),
                            "chartSessions": store.chartSessions,
                            "chartCandles": JSON.stringify(store.chartCandles),
                            "chartRef": store.chartReferencePrice,
                            "chartPre": store.chartPreSession,
                            "chartSessionStart": store.chartSessionStart,
                            "chartSessionCurrent": store.chartSessionCurrent,
                            "quoteTime": store.quoteTimestamp
                        });
                        break;
                    }
                }
            }

            if (chartRange === "1D") {
                store.previousClose = meta.regularMarketPreviousClose || meta.previousClose || meta.chartPreviousClose;
            } else {
                store.previousClose = meta.chartPreviousClose;
                if (!store.previousClose || store.previousClose === 0) {
                    store.previousClose = cleanData.length > 0 ? cleanData[0] : meta.regularMarketPreviousClose;
                }
            }

            var change = meta.regularMarketPrice - store.previousClose;
            store.isPositive = change >= 0;
            store.priceChange = Format.number(change, true, applet.hideDecimals, applet.formatPrices);
            store.percentChange = Format.number((change / store.previousClose) * 100, true,
                                                applet.hideDecimals, applet.formatPrices) + "%";

            // In single mode this response can also serve the panel when the chart is
            // showing the configured range. When the chart has its own range, a separate
            // panel request supplies these values instead.
            if (!applet.isMultiMode && chartRange === applet.chartRange) {
                store.panelCurrentPrice = store.currentPrice;
                store.panelCurrentPercent = store.percentChange;
                store.panelCurrentIsPositive = store.isPositive;
                store.panelCurrentIsCached = false;
            }

            var now = new Date();
            applet.lastUpdated = now.toLocaleTimeString(Qt.locale(), "HH:mm");
            var next = new Date(now.getTime() + (applet.refreshIntervalMinutes * 60000));
            applet.nextUpdate = next.toLocaleTimeString(Qt.locale(), "HH:mm");
            store.singleDataRange = chartRange;
            store.singleDataTicker = symbol;
            if (!applet.isMultiMode) applet.showingCachedData = false;
            applet.noteQuoteReceived();
            applet.queueQuotesCacheSave();
        } catch (e) { console.log("Error parsing single: " + e); }
    }
}
