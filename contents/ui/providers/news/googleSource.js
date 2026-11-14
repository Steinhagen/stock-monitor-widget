.pragma library
// A Google News search by company name. Parsing and the query live in
// ../google/news.js.

.import "../google/news.js" as Google

var id = "google";
var label = "Google";
// The third, optional feed: some networks cannot reach it, so a failure is only
// reported when it leaves the headline list empty.
var optional = true;

function supports(settings, symbol) {
    return settings.newsSourceGoogle === true;
}

function fetch(ctx, done) {
    Google.fetch(ctx, done);
}

function pageUrl(name, locale) {
    return Google.searchPageUrl(name, locale);
}
