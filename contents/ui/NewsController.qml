import QtQuick
import "domain/news.js" as NewsModel
import "core/Cache.js" as Cache
import "providers/news/registry.js" as NewsRegistry
import "providers/yahoo/news.js" as YahooNews
import "providers/bvb/issuer.js" as BvbIssuer
import "providers/google/news.js" as GoogleNews

Item {
    id: newsController
    property var applet
    property var newsCache: ({})
    // Bumped when the cache is dropped, so a reply that was already on its way is ignored.
    property int newsGeneration: 0
    property int newsClock: 0

    readonly property var entry: newsCache[newsKey(applet.singleTicker)] || null
    readonly property var items: entry ? entry.items : []
    // At least one enabled source can serve the shown symbol. The main item uses this
    // for the chart/news switch and to close the pane when every source is turned off.
    readonly property bool available: applet ? NewsRegistry.hasAny(applet, applet.singleTicker || "") : false

    function newsKey(symbol) {
        return Cache.key(symbol);
    }

    // Copy-on-write, so bindings on newsCache (and newsEntry) re-evaluate.
    function setNewsEntry(key, changes) {
        var old = newsCache[key];
        var entry = old ? Object.assign({}, old)
                        : { items: [], sourceItems: {}, sourceNeedsName: {},
                            time: 0, attempt: 0, loaded: false, error: false, pending: false,
                            remaining: 0 };
        Object.assign(entry, changes);
        var copy = Object.assign({}, newsCache);
        copy[key] = entry;
        newsCache = copy;
    }

    // Company name for the queries that need it, only when it is known to belong to
    // `symbol`. In single mode the name keeps the previous ticker's value until the new
    // quote arrives, so it is trusted only once singleDataTicker matches. In multi mode
    // it is taken from the selected list row. Returns null while it is still unknown,
    // and "" when there is no name other than the ticker.
    function newsCompanyName(symbol) {
        var sym = String(symbol || "").trim();
        if (sym === "" || newsKey(applet.singleTicker) !== newsKey(sym)) return null;
        if (!applet.isMultiMode && applet.singleDataTicker !== applet.singleTicker) return null;
        var name = String(applet.singleCompanyName || "").trim();
        if (name === applet.loadingText) return null;
        if (name === "" || name.toUpperCase() === sym.toUpperCase()) return "";
        return name;
    }

    // Headlines from the per-source lists, newest first, in registry order. Exposed so
    // the merge can be tested without a network request.
    function mergeSourceItems(sourceItems) {
        var lists = [];
        for (var i = 0; i < NewsRegistry.SOURCES.length; i++)
            lists.push((sourceItems || {})[NewsRegistry.SOURCES[i].id] || []);
        return NewsModel.merge(lists);
    }

    function needsName(entry) {
        var flags = entry ? (entry.sourceNeedsName || {}) : {};
        for (var id in flags) {
            if (flags[id]) return true;
        }
        return false;
    }

    // Called once for each provider. It keeps that provider's previous items when the
    // request failed, so a temporary error does not clear the list; `error` still drives
    // the "Could not update headlines" note, except for an optional source that still
    // has other headlines to show.
    function finishNewsSource(key, source, items, error, flags) {
        var entry = newsCache[key];
        if (!entry || !entry.pending) return;
        var failed = error !== "";

        var sourceItems = Object.assign({}, entry.sourceItems || {});
        if (failed) {
            if (!sourceItems[source.id]) sourceItems[source.id] = [];
        } else {
            sourceItems[source.id] = items || [];
        }
        var sourceNeedsName = Object.assign({}, entry.sourceNeedsName || {});
        sourceNeedsName[source.id] = !!(flags && flags.needsName);

        var changes = { sourceItems: sourceItems, sourceNeedsName: sourceNeedsName };
        changes.items = mergeSourceItems(sourceItems);
        changes.loaded = true;
        var hasItems = changes.items.length > 0;
        changes.error = entry.error || (failed && (!source.optional || !hasItems));
        if (!failed) changes.time = Date.now();
        changes.remaining = Math.max(0, (entry.remaining || 0) - 1);
        changes.pending = changes.remaining > 0;
        setNewsEntry(key, changes);
        if (failed) console.log("News headlines (" + source.id + "): " + error);
    }

    function fetchSource(key, symbol, source) {
        var generation = newsGeneration;
        source.fetch({
            symbol: symbol,
            name: newsCompanyName(symbol),
            locale: Qt.locale().name,
            limit: applet.newsCount
        }, function(items, error, flags) {
            if (generation !== newsGeneration) return;
            finishNewsSource(key, source, items, error, flags);
        });
    }

    // Fetches the headlines for `symbol` unless they are fresh. `force` (the refresh
    // button and menu) skips the freshness and retry checks.
    function requestNews(symbol, force) {
        if (!applet.newsAvailable) return;
        var sym = String(symbol || "").trim();
        if (sym === "") return;
        var key = newsKey(sym);
        var entry = newsCache[key];
        var now = Date.now();
        if (entry && entry.pending) return;
        if (!force && entry) {
            if (Cache.isFresh(entry, applet.newsRefreshMinutes * 60000, now)) {
                if (needsName(entry)) retryNewsWithName();
                return;
            }
            // Do not hammer the feeds after a failure; the next try comes with the
            // interval, the next time the pane opens, or the refresh button.
            if (Cache.isThrottled(entry, 60000, now)) return;
        }
        var sources = NewsRegistry.enabledSources(applet, sym);
        if (sources.length === 0) return;
        setNewsEntry(key, { pending: true, remaining: sources.length,
                            attempt: now, error: false, sourceNeedsName: {} });
        for (var i = 0; i < sources.length; i++) fetchSource(key, sym, sources[i]);
    }

    // Runs the sources that were waiting for the company name once the quote has
    // supplied it. Sources whose name query already ran are left alone.
    function retryNewsWithName() {
        if (!applet.newsPaneShown) return;
        var sym = applet.singleTicker.trim();
        if (sym === "") return;
        var key = newsKey(sym);
        var entry = newsCache[key];
        if (!entry || !entry.loaded || entry.pending) return;
        var name = newsCompanyName(sym);
        if (name === null) return;

        var retry = [];
        var sources = NewsRegistry.enabledSources(applet, sym);
        for (var i = 0; i < sources.length; i++) {
            var source = sources[i];
            var items = (entry.sourceItems || {})[source.id] || [];
            if ((entry.sourceNeedsName || {})[source.id] === true && items.length === 0)
                retry.push(source);
        }
        if (retry.length === 0) return;

        if (name === "") {
            var cleared = Object.assign({}, entry.sourceNeedsName || {});
            for (var j = 0; j < retry.length; j++) cleared[retry[j].id] = false;
            setNewsEntry(key, { sourceNeedsName: cleared });
            return;
        }
        setNewsEntry(key, { pending: true, remaining: retry.length,
                            attempt: Date.now(), error: false });
        for (var k = 0; k < retry.length; k++) fetchSource(key, sym, retry[k]);
    }

    function openNewsLink(url) {
        Qt.openUrlExternally(YahooNews.safeLink(url, applet.singleTicker));
    }

    function openYahooNews(symbol) {
        var clean = symbol ? String(symbol).trim() : "";
        if (clean === "") return;
        Qt.openUrlExternally(YahooNews.newsPageUrl(clean));
    }

    function openBvbNews(symbol) {
        var url = BvbIssuer.detailUrl(symbol);
        if (url !== "") Qt.openUrlExternally(url);
    }

    // The Google News search page for the shown company, using the same query as the
    // feed (the name may not be known yet, in which case the symbol is searched).
    function openGoogleNews(symbol) {
        var clean = String(symbol === undefined || symbol === null ? "" : symbol).trim();
        if (clean === "") return;
        var name = newsCompanyName(clean);
        var query = (name === null || name === "") ? clean : name;
        var url = GoogleNews.searchPageUrl(query, Qt.locale().name);
        if (url !== "") Qt.openUrlExternally(url);
    }

    // Bumped once a minute while the headlines are shown, so their ages re-evaluate.
    Timer {
        interval: 60000
        running: applet.newsPaneShown
        repeat: true
        // The binding is not evaluated while the pane is hidden, and the age timer only
        // ticks after a minute. Bump the clock as soon as the pane comes back, so the
        // "Updated ..." label does not keep the age from the previous visit until the
        // first tick (or until another change forces a re-evaluation).
        triggeredOnStart: true
        onTriggered: newsClock++
    }

    // "just now", "5 min ago", "2 h ago", "3 d ago", or the date after a week.
    function newsAge(timeSec) {
        // Read the clock so QML re-evaluates callers every minute.
        if (newsClock < 0) return "";
        if (!(timeSec > 0)) return "";
        var age = NewsModel.age(timeSec, Date.now());
        switch (age.unit) {
            case "now": return i18nc("@item:news age", "just now");
            case "min": return i18ncp("@item:news age", "%1 min ago", "%1 min ago", age.n);
            case "h": return i18ncp("@item:news age", "%1 h ago", "%1 h ago", age.n);
            case "d": return i18ncp("@item:news age", "%1 d ago", "%1 d ago", age.n);
            default: return new Date(timeSec * 1000).toLocaleDateString(Qt.locale(), "d MMM");
        }
    }

    // Starts (and fires at once) every time the pane comes on screen, then refreshes on
    // the interval. requestNews() skips the request while the cache is fresh.
    Timer {
        interval: Math.max(10, applet.newsRefreshMinutes) * 60000
        running: applet.newsPaneShown
        repeat: true
        triggeredOnStart: true
        onTriggered: requestNews(applet.singleTicker, false)
    }

    // The source selection changes what a cached entry can contain, so drop it. If the
    // current symbol has no remaining source, close the News pane and hide its icons.
    function refreshNewsSources() {
        newsGeneration++;
        newsCache = ({});
        if (!applet.newsAvailable) {
            applet.singleViewPane = "chart";
            return;
        }
        if (applet.newsPaneShown) requestNews(applet.singleTicker, true);
    }

    function invalidate() {
        newsGeneration++;
        newsCache = ({});
    }
}
