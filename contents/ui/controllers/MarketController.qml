import QtQuick
import "../domain/chart.js" as Chart
import "../domain/format.js" as Format
import "../domain/sessions.js" as Sessions
import "../providers/yahoo/chart.js" as YahooChart

// Pre-market and after-hours state for every requested symbol: the latest quote, the
// trading periods from the quote metadata, and the clock that keeps the open/closed
// state fresh. The quote workflows call setSession()/processExtendedData() as replies
// arrive; the views read the status through the small functions below.
Item {
    id: market

    // Owned by the app and bound to the configuration.
    property bool showExtendedHours: false
    property bool keepExtendedAfterClose: true
    property bool hideDecimals: false
    property bool formatPrices: true

    // Latest pre/post quote per symbol, as { kind, label, time, price, change, pct, isPos }.
    property var extendedData: ({})
    // Last extended quote seen, kept so it can still be shown after the session ends.
    property var lastExtendedData: ({})
    // Trading sessions from the latest quote metadata, per symbol.
    property var marketSessions: ({})
    // Bumped once a minute so callers re-evaluate when a session boundary passes.
    property int marketClock: 0

    function setExtendedData(symbol, entry) {
        var copy = Object.assign({}, extendedData);
        if (entry) copy[symbol] = entry;
        else delete copy[symbol];
        extendedData = copy;
    }

    function setLastExtendedData(symbol, entry) {
        var copy = Object.assign({}, lastExtendedData);
        if (entry) copy[symbol] = entry;
        else delete copy[symbol];
        lastExtendedData = copy;
    }

    function setMarketSession(symbol, meta) {
        var periods = meta.currentTradingPeriod || ({});
        var previous = marketSessions[symbol] || ({});
        var copy = Object.assign({}, marketSessions);
        copy[symbol] = {
            "pre": periods.pre || null,
            "regular": periods.regular || null,
            "post": periods.post || null,
            "hasPrePost": meta.hasPrePostMarketData !== 0 && meta.hasPrePostMarketData !== false,
            "crypto": meta.instrumentType === "CRYPTOCURRENCY",
            // Time of the latest regular quote, used to tell a fresh open quote from
            // the previous close that Yahoo still returns during the first seconds.
            // Extended-hours responses can repeat an older time; never go backwards.
            "quoteTime": Math.max(meta.regularMarketTime || 0, previous.quoteTime || 0)
        };
        marketSessions = copy;
    }

    function hasSession(symbol) {
        return !!marketSessions[symbol];
    }

    // Drop every symbol's extended data, keeping the sessions so status still works.
    function clearExtended() {
        extendedData = ({});
        lastExtendedData = ({});
    }

    function clearLastExtended() {
        lastExtendedData = ({});
    }

    // "open", "pre", "post" or "closed" for the exchange the symbol trades on.
    function statusFor(symbol) {
        var session = marketSessions[symbol];
        if (!session) return "";
        // Read the clock so QML re-evaluates callers when a session boundary passes.
        if (marketClock < 0) return "";
        return Sessions.status(session, Math.floor(Date.now() / 1000));
    }

    function hasPrePostDataFor(symbol) {
        var session = marketSessions[symbol];
        return session ? session.hasPrePost : true;
    }

    // True when the instrument's market is closed: outside every session, or in a
    // pre/post window for an instrument without extended-hours trading (indices).
    function isMarketClosedFor(symbol) {
        var session = marketSessions[symbol];
        if (!session) return false;
        return Sessions.isClosed(session, statusFor(symbol));
    }

    // True while the regular session has started but its first quote has not arrived.
    function awaitingFirstRegularQuote(symbol) {
        var session = marketSessions[symbol];
        if (!session || !session.regular) return false;
        // Read the clock so the waiting state re-evaluates at the session boundary.
        if (marketClock < 0) return false;
        return Sessions.awaitingFirstRegularQuote(session, Math.floor(Date.now() / 1000));
    }

    // The extended quote to show for a symbol: the live one while its session runs, or —
    // when the option is enabled — the last one after the market closes. The session
    // checks keep a Friday after-hours quote from being shown during a later pre-market.
    function extendedQuoteFor(symbol) {
        if (!showExtendedHours) return undefined;
        var status = statusFor(symbol);
        var session = marketSessions[symbol];
        if (status === "open" && awaitingFirstRegularQuote(symbol)) {
            // The market is open, but Yahoo has not published the first regular trade
            // yet. Keep showing the last pre-market quote instead of the previous close.
            if (!session || !session.regular) return undefined;
            var last = lastExtendedData[symbol];
            var preStart = session.pre && session.pre.start < session.regular.start
                           ? session.pre.start : (session.regular.start - 12 * 3600);
            if (last && last.kind === "pre" && last.time >= preStart && last.time < session.regular.start)
                return last;
            return undefined;
        }
        if (status === "closed") {
            if (!keepExtendedAfterClose) return undefined;
            // The last extended quote of the most recent session, kept so it can still
            // be shown once the market closes.
            return lastExtendedData[symbol];
        }
        var entry = extendedData[symbol];
        if (!entry || !session || !entry.time) return undefined;
        var period = status === "pre" ? session.pre : (status === "post" ? session.post : null);
        if (!period) return undefined;
        if (!Chart.inExtendedSession(period, entry.time, status)) return undefined;
        if ((status === "pre" && entry.kind !== "pre")
            || (status === "post" && entry.kind !== "post")) return undefined;
        return entry;
    }

    // The chart API returns pre/post candles when asked for them. The current session
    // comes from the metadata, not from the last candle alone: Yahoo keeps serving the
    // last session's candles after it has ended.
    function processExtendedData(symbol, json) {
        try {
            var result = json.chart.result[0];
            var meta = result.meta;
            setMarketSession(symbol, meta);
            var status = statusFor(symbol);
            if (status === "open") { setExtendedData(symbol, null); return; }
            if (status === "closed" && !keepExtendedAfterClose) {
                setExtendedData(symbol, null);
                return;
            }
            if (!hasPrePostDataFor(symbol)) { setExtendedData(symbol, null); return; }

            var closes = result.indicators.quote[0].close;
            var stamps = result.timestamp;
            if (!stamps || !closes) { setExtendedData(symbol, null); return; }

            var last = -1;
            for (var i = closes.length - 1; i >= 0; i--) {
                if (closes[i] !== null) { last = i; break; }
            }
            if (last < 0) { setExtendedData(symbol, null); return; }

            var session = marketSessions[symbol];
            var period = null;
            // The session is kept as an untranslated kind as well, so the checks further
            // down never depend on the wording of the (translated) label.
            var kind = "";
            var label = "";
            if (status === "pre" || status === "post") {
                period = status === "pre" ? session.pre : session.post;
                kind = status;
                label = status === "pre" ? i18n("Pre-Market") : i18n("After-Hours");
            } else {
                // Closed: keep the last session's quote if the option asks for it. The
                // session comes from meta.tradingPeriods, not currentTradingPeriod: the
                // latter already describes the next trading day before its pre-market
                // starts, while the last candle still belongs to the previous day's
                // after-hours. Looking only at today's periods dropped that quote and
                // left "No after-hours" on screen after a restart.
                var days = Chart.tradingDays(meta);
                for (var d = days.length - 1; d >= 0 && !period; d--) {
                    if (Chart.inExtendedSession(days[d].post, stamps[last], "post")) {
                        period = days[d].post;
                        kind = "post";
                        label = i18n("After-Hours");
                    } else if (Chart.inExtendedSession(days[d].pre, stamps[last], "pre")) {
                        period = days[d].pre;
                        kind = "pre";
                        label = i18n("Pre-Market");
                    }
                }
            }
            if (!Chart.inExtendedSession(period, stamps[last], kind)) {
                setExtendedData(symbol, null);
                return;
            }

            var base = meta.regularMarketPrice;
            if (!base) { setExtendedData(symbol, null); return; }

            var price = closes[last];
            var change = price - base;
            var entry = {
                "kind": kind,
                "label": label,
                "time": stamps[last],
                "price": Format.currencySymbol(meta.currency)
                         + Format.number(price, false, hideDecimals, formatPrices),
                "change": Format.number(change, true, hideDecimals, formatPrices),
                "pct": Format.number((change / base) * 100, true, hideDecimals, formatPrices) + "%",
                "isPos": change >= 0
            };
            setExtendedData(symbol, entry);
            setLastExtendedData(symbol, entry);
        } catch (e) { console.log("Error parsing extended hours: " + e); }
    }

    function fetchExtendedHours(symbol) {
        YahooChart.getExtended(symbol, function(response, error) {
            if (!error) processExtendedData(symbol, response);
        });
    }

    Timer {
        interval: 60000
        repeat: true
        running: market.showExtendedHours
        onTriggered: market.marketClock++
    }
}
