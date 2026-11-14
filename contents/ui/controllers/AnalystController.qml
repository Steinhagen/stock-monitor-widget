import QtQuick
import "../providers/yahoo/quoteSummary.js" as QuoteSummary
import "../core/Cache.js" as Cache

// Analyst price-target history for the shown stock. The crumb/cookie flow and the
// parsing live in providers/yahoo/quoteSummary.js; this controller keeps the per-symbol
// cache and decides when a request is due. The data lives in memory only, like the
// headlines.
Item {
    id: analystController
    property var applet
    property var cache: ({})

    readonly property string symbol: applet ? String(applet.singleTicker || "").trim() : ""
    readonly property var entry: cache[newsKey(symbol)] || null
    readonly property var items: entry ? entry.items : []
    readonly property var summary: entry ? entry.summary : null
    readonly property bool pending: entry ? entry.pending === true : false
    readonly property bool error: entry ? entry.error === true : false

    // Analyst actions move slowly; a fresh copy is enough for hours. A failed request
    // is retried only after a minute, so opening the pane or changing options cannot
    // hammer Yahoo.
    readonly property int cacheMinutes: 6 * 60
    readonly property int retryMilliseconds: 60 * 1000

    function newsKey(symbol) {
        return Cache.key(symbol);
    }

    // Copy-on-write, so the QML bindings on `entry`, `items` and `summary` update.
    function setEntry(key, changes) {
        var old = cache[key];
        var entry = old ? Object.assign({}, old)
                        : { items: [], summary: null, time: 0, attempt: 0,
                            loaded: false, error: false, pending: false };
        Object.assign(entry, changes);
        var copy = Object.assign({}, cache);
        copy[key] = entry;
        cache = copy;
    }

    function invalidate() {
        cache = ({});
    }

    // Fetches the price-target history for `symbol` unless a fresh copy is cached.
    function request(symbol, force) {
        if (!applet || !applet.showAnalystTargets) return;
        var sym = String(symbol || "").trim();
        if (sym === "") return;
        var key = newsKey(sym);
        var entry = cache[key];
        var now = Date.now();
        if (entry && entry.pending) return;
        if (!force && Cache.isFresh(entry, cacheMinutes * 60000, now)) return;
        if (!force && Cache.isThrottled(entry, retryMilliseconds, now)) return;
        setEntry(key, { pending: true, attempt: now, error: false });
        QuoteSummary.fetch(sym, function(items, summary, error) {
            finish(key, items, summary, error);
        });
    }

    function finish(key, items, summary, error) {
        var old = cache[key];
        var failed = error !== "";
        var changes = {
            loaded: true,
            pending: false,
            error: failed,
            attempt: old ? (old.attempt || 0) : 0
        };
        if (failed) {
            // Keep the previous successful data; a temporary outage must not erase it.
            changes.items = old ? (old.items || []) : [];
            changes.summary = old ? (old.summary || null) : null;
            changes.time = old ? (old.time || 0) : 0;
            console.log("Analyst price targets: " + error);
        } else {
            changes.items = Array.isArray(items) ? items : [];
            changes.summary = summary || null;
            changes.time = Date.now();
        }
        setEntry(key, changes);
    }
}
