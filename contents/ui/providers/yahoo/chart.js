.pragma library
// Yahoo Finance chart quotes and history. The range -> interval mapping lives in
// domain/quotes.js; this module only builds the URL and performs the request.

.import "../../core/Http.js" as Http
.import "../../domain/quotes.js" as Quotes

var BASE = "https://query1.finance.yahoo.com/v8/finance/chart/";

function chartUrl(symbol, range, showExtendedHours) {
    return BASE + symbol + "?" + Quotes.apiParams(range, showExtendedHours);
}

// The 1D intraday series used for the pre/post quote, independent of the chart range.
function extendedUrl(symbol) {
    return BASE + symbol + "?range=1d&interval=5m&includePrePost=true";
}

// done(response, error) with the parsed chart reply.
function get(symbol, range, showExtendedHours, done) {
    Http.getJson(chartUrl(symbol, range, showExtendedHours), { timeout: 20000 }, done);
}

function getExtended(symbol, done) {
    Http.getJson(extendedUrl(symbol), { timeout: 20000 }, done);
}
