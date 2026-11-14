.pragma library
// Yahoo Finance as a news source. The endpoint and parsing live in ../yahoo/news.js;
// this descriptor is what the registry and the controller work with.

.import "../yahoo/news.js" as Yahoo

var id = "yahoo";
var label = "Yahoo";
// A failure is reported even when other sources produced headlines.
var optional = false;

function supports(settings, symbol) {
    return settings.newsSourceYahoo === true;
}

function fetch(ctx, done) {
    Yahoo.fetch(ctx, done);
}

function pageUrl(symbol) {
    return Yahoo.newsPageUrl(symbol);
}
