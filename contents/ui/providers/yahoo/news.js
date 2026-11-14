.pragma library

.import "../../core/Http.js" as Http
// Latest headlines for one symbol, from the Yahoo search endpoint the symbol search in
// the settings already uses (no cookie or crumb needed):
//   https://query2.finance.yahoo.com/v1/finance/search?q=<query>&quotesCount=0&newsCount=<n>
// Each news[] item has uuid, title, publisher, link, providerPublishTime (unix seconds)
// and relatedTickers[]. Only items tagged with the symbol are kept.
//
// The Yahoo RSS headline feed is deliberately not used: for symbols it has no news for
// it can return unrelated headlines, and it has no ticker tags to filter them out.
//
// Callers must not set a User-Agent. Yahoo's edge answers 429 to non-browser agents,
// and Qt's default "Mozilla/5.0" is accepted.

// Yahoo deduplicates its own results and returns about n - 1 items for newsCount=n, and
// the ticker filter can drop a few more. Ask for a few extra and cut after filtering.
var EXTRA_REQUESTED = 4;

// Source label attached to this endpoint's headlines. The news view builds its filter
// buttons from the labels of the shown items, so another provider (BVB, for example)
// only has to return its own label here.
var YAHOO_SOURCE = "Yahoo";

function searchUrl(query, shown) {
    return "https://query2.finance.yahoo.com/v1/finance/search?q=" + encodeURIComponent(query)
        + "&quotesCount=0&newsCount=" + (Number(shown) + EXTRA_REQUESTED);
}

// Yahoo's news page for a symbol: the footer link and the fallback for odd article links.
function newsPageUrl(symbol) {
    return "https://finance.yahoo.com/quote/" + encodeURIComponent(String(symbol).trim()) + "/news";
}

// Only web links are opened. Anything else (javascript:, file:, empty) opens the symbol's
// news page instead.
function safeLink(url, symbol) {
    var link = String(url === undefined || url === null ? "" : url).trim();
    return /^https?:\/\//i.test(link) ? link : newsPageUrl(symbol);
}

// One pass, so "&amp;lt;" becomes "&lt;" and is not decoded twice. The result is shown
// as plain text, so tags in a title stay visible text and are never rendered.
function decodeEntities(s) {
    var named = { amp: "&", lt: "<", gt: ">", quot: "\"", apos: "'" };
    return String(s === undefined || s === null ? "" : s).replace(/&(#[xX][0-9a-fA-F]+|#[0-9]+|amp|lt|gt|quot|apos);/g,
        function (match, entity) {
            if (entity.charAt(0) !== "#") return named[entity];
            var hex = entity.charAt(1) === "x" || entity.charAt(1) === "X";
            var code = parseInt(entity.substring(hex ? 2 : 1), hex ? 16 : 10);
            if (!isFinite(code) || code <= 0 || code > 0x10FFFF) return match;
            return String.fromCodePoint(code);
        });
}

function matchesSymbol(related, symbol, base) {
    if (!Array.isArray(related)) return false;
    for (var i = 0; i < related.length; i++) {
        var tag = String(related[i]).trim().toUpperCase();
        if (tag === symbol || (base !== "" && tag === base)) return true;
    }
    return false;
}

// `data` is the parsed JSON reply. Returns [{id, title, publisher, source, link, time}],
// newest first and at most `limit` items. `allowBase` also accepts the symbol without its
// exchange suffix (SAP.DE -> SAP). Use it only for the company-name query: for a ticker
// query the base can be another company (RRC.RO is not Range Resources, RRC).
function parse(data, symbol, allowBase, limit) {
    if (!data || !Array.isArray(data.news)) return [];
    var sym = String(symbol === undefined || symbol === null ? "" : symbol).trim().toUpperCase();
    if (sym === "") return [];
    var dot = sym.lastIndexOf(".");
    var base = allowBase && dot > 0 ? sym.substring(0, dot) : "";

    var items = [];
    var seen = {};
    for (var i = 0; i < data.news.length; i++) {
        var item = data.news[i];
        if (!item || !matchesSymbol(item.relatedTickers, sym, base)) continue;
        var title = decodeEntities(item.title).trim();
        if (title === "") continue;
        var link = String(item.link === undefined || item.link === null ? "" : item.link).trim();
        var id = item.uuid ? String(item.uuid) : (link !== "" ? link : title);
        var keys = ["u:" + (item.uuid || ""), "l:" + link, "t:" + title];
        var duplicate = false;
        for (var k = 0; k < keys.length; k++) {
            if (keys[k].length > 2 && seen[keys[k]]) duplicate = true;
        }
        if (duplicate) continue;
        for (var m = 0; m < keys.length; m++) {
            if (keys[m].length > 2) seen[keys[m]] = true;
        }
        items.push({
            id: id,
            title: title,
            publisher: decodeEntities(item.publisher).trim(),
            source: YAHOO_SOURCE,
            link: link,
            time: Number(item.providerPublishTime) || 0
        });
    }
    items.sort(function (a, b) { return b.time - a.time; });
    var max = Number(limit);
    return max >= 0 ? items.slice(0, max) : items;
}


// Provider entry point. The ticker query keeps only items tagged with the symbol; when
// it finds nothing, the company name is searched and the base symbol is accepted too.
// `ctx.name` is null while the quote has not supplied it yet: the caller is told that
// the source needs the name and retries when it is known.
function fetch(ctx, done) {
    var symbol = String(ctx.symbol || "").trim();
    var limit = Number(ctx.limit);
    var finished = false;
    var finish = function(items, error, flags) {
        if (finished) return;
        finished = true;
        done(items, error, flags || {});
    };

    var search = function(query, allowBase) {
        Http.getJson(searchUrl(query, limit), { timeout: 20000 }, function(data, error) {
            if (error) {
                finish([], error.message);
                return;
            }
            var items = parse(data, symbol, allowBase, limit);
            if (items.length === 0 && !allowBase) {
                var name = ctx.name;
                if (name === null) {
                    finish([], "", { needsName: true });
                    return;
                }
                if (name !== "") {
                    search(name, true);
                    return;
                }
            }
            finish(items, "");
        });
    };
    search(symbol, false);
}
