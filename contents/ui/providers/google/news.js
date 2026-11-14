.pragma library

.import "../../core/Http.js" as Http
// Headlines from a Google News search, as an extra provider next to Yahoo Finance and
// BVB. Google publishes an RSS 2.0 feed for any news search, with no key or cookie:
//   https://news.google.com/rss/search?q=<query>&hl=<lang>&gl=<country>&ceid=<country>:<lang>
//
// The query is the company name as a quoted phrase. Quoting matters: an unquoted short
// name such as "Vale" also matches a show-jumping venue and a high school. Legal
// suffixes are dropped when the rest still has two words ("Banca Transilvania S.A." ->
// "Banca Transilvania"), but a single word keeps them, because "Vale" or "Eni" alone
// are ambiguous. The feed has no ticker tags (unlike Yahoo's relatedTickers), so
// relevance comes from the query itself; the caller still merges the items with the
// other providers and removes duplicate titles.
//
// The feed's copyright note allows it for personal, non-commercial use in a feed reader
// only. The settings expose it as its own source, so it can be turned off.

var SOURCE = "Google";
var ENDPOINT = "https://news.google.com/rss/search?";
var SEARCH_PAGE = "https://news.google.com/search?";

var MONTHS = { Jan: 0, Feb: 1, Mar: 2, Apr: 3, May: 4, Jun: 5,
               Jul: 6, Aug: 7, Sep: 8, Oct: 9, Nov: 10, Dec: 11 };

// Google indexes the auto-generated "quote" pages of finance sites as news
// ("… Stock Price, News, Quote & History"). They are about the company but are not
// headlines, so they are dropped.
var QUOTE_PAGE = /\bstock price[, ]+news[, ]+quote\b/i;

// "ro_RO" -> hl=ro&gl=RO&ceid=RO:ro. Google's non-English editions take the bare
// language code; the English ones need a region (hl=en-US), so English always uses the
// US edition. Anything that does not look like a locale falls back to that edition too.
function localeParams(locale) {
    var m = /^([A-Za-z]{2,3})(?:[_-]([A-Za-z]{2}))?/.exec(String(locale === undefined || locale === null ? "" : locale));
    if (!m) return "&hl=en-US&gl=US&ceid=US:en";
    var lang = m[1].toLowerCase();
    var country = m[2] ? m[2].toUpperCase() : "";
    if (lang === "en" || country === "") return "&hl=en-US&gl=US&ceid=US:en";
    return "&hl=" + lang + "&gl=" + country + "&ceid=" + country + ":" + lang;
}

// Trailing legal forms that add little to a news search. They are only removed when
// the remaining name still has two words, so short names stay unambiguous.
var LEGAL_SUFFIX = /(?:[,\s]+(?:s\.?a\.?|s\.?e\.?|ag|plc|inc\.?|ltd\.?|limited|n\.?v\.?|a\/s|asa|ab|oyj|spa|s\.?p\.?a\.?|corp\.?|corporation|company|co\.?|gmbh|kgaa|b\.?v\.?|srl|s\.?r\.?l\.?))+$/i;

function cleanName(name) {
    var text = String(name === undefined || name === null ? "" : name)
        .replace(/[\r\n\t]+/g, " ")
        .replace(/\s+/g, " ")
        .trim();
    var short = text.replace(LEGAL_SUFFIX, "").replace(/[,\s]+$/, "").trim();
    return short !== "" && /\s/.test(short) ? short : text;
}

// The quoted phrase Google searches for. The company name comes from the quote and can
// contain quotes; those would break the query.
function query(name) {
    var text = cleanName(name)
        .replace(/\u0022/g, " ")
        .replace(/\s+/g, " ")
        .trim();
    return text === "" ? "" : "\"" + text + "\"";
}

function feedUrl(name, locale) {
    var text = query(name);
    return text === "" ? "" : ENDPOINT + "q=" + encodeURIComponent(text) + localeParams(locale);
}

// The "More on Google" page for the same query.
function searchPageUrl(name, locale) {
    var text = query(name);
    return text === "" ? "" : SEARCH_PAGE + "q=" + encodeURIComponent(text) + localeParams(locale);
}

// The RSS titles are plain text with entities (and occasionally CDATA), so one pass is
// enough. The result is shown as plain text, never as markup.
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

function tagText(block, name) {
    var m = new RegExp("<" + name + "(?:\\s[^>]*)?>([\\s\\S]*?)</" + name + ">", "i").exec(String(block));
    if (!m) return "";
    return m[1].replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, "$1");
}

// "Tue, 10 Nov 2026 07:55:22 GMT". Google always prints GMT; parsing it explicitly
// avoids relying on the engine's RFC 822 support.
function parseRfc822(text) {
    var m = /(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+(\d{1,2}):(\d{2}):(\d{2})/.exec(String(text || ""));
    if (!m) return 0;
    var key = m[2].charAt(0).toUpperCase() + m[2].substring(1).toLowerCase();
    var month = MONTHS[key];
    if (month === undefined) return 0;
    var t = Date.UTC(Number(m[3]), month, Number(m[1]), Number(m[4]), Number(m[5]), Number(m[6]));
    return isFinite(t) ? Math.floor(t / 1000) : 0;
}

// Google appends " - Publisher" to every title and repeats the publisher in <source>.
// Strip only that exact suffix, so a dash inside the headline survives.
function splitPublisher(title, publisher) {
    var clean = String(title || "").trim();
    var name = String(publisher || "").trim();
    if (name === "") return clean;
    var suffix = " - " + name;
    if (clean.length > suffix.length
            && clean.toLowerCase().lastIndexOf(suffix.toLowerCase()) === clean.length - suffix.length)
        return clean.substring(0, clean.length - suffix.length).trim();
    return clean;
}

// `text` is the RSS body. Returns [{id, title, publisher, source, link, time}], newest
// first and at most `limit` items.
function parse(text, limit) {
    var xml = String(text === undefined || text === null ? "" : text);
    var blocks = xml.match(/<item\b[\s\S]*?<\/item>/gi) || [];
    var items = [];
    var seen = {};
    for (var i = 0; i < blocks.length; i++) {
        var block = blocks[i];
        var link = decodeEntities(tagText(block, "link")).trim();
        if (link === "") continue;
        var publisher = decodeEntities(tagText(block, "source")).trim();
        var title = splitPublisher(decodeEntities(tagText(block, "title")), publisher);
        if (title === "" || QUOTE_PAGE.test(title)) continue;
        var keys = ["u:" + link.toLowerCase(), "t:" + title.toLowerCase()];
        var duplicate = false;
        for (var k = 0; k < keys.length; k++) {
            if (seen[keys[k]]) duplicate = true;
        }
        if (duplicate) continue;
        for (var m = 0; m < keys.length; m++) seen[keys[m]] = true;
        var guid = decodeEntities(tagText(block, "guid")).trim();
        items.push({
            id: guid !== "" ? guid : link,
            title: title,
            publisher: publisher,
            source: SOURCE,
            link: link,
            time: parseRfc822(tagText(block, "pubDate"))
        });
    }
    items.sort(function (a, b) { return (b.time || 0) - (a.time || 0); });
    var max = Number(limit);
    return max >= 0 ? items.slice(0, max) : items;
}

// Provider entry point. The query needs the company name, so a null name (the quote has
// not supplied it yet) is reported as `needsName` and retried by the caller. A reply
// that is not RSS (a redirect, or Google's rate limit) is an error, not "no headlines".
function fetch(ctx, done) {
    if (ctx.name === null) {
        done([], "", { needsName: true });
        return;
    }
    if (ctx.name === "") {
        done([], "", {});
        return;
    }
    var url = feedUrl(ctx.name, ctx.locale);
    if (url === "") {
        done([], "", {});
        return;
    }
    Http.getText(url, { timeout: 20000 }, function(body, error) {
        if (error) {
            done([], error.message, {});
            return;
        }
        if (String(body).indexOf("<rss") < 0) {
            done([], "unexpected reply", {});
            return;
        }
        var items;
        try {
            items = parse(body, ctx.limit);
        } catch (e) {
            done([], "could not parse the reply: " + e, {});
            return;
        }
        done(items, "", {});
    });
}
