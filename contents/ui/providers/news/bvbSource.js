.pragma library
// The issuer's announcements from the Bucharest Stock Exchange, for symbols ending in
// .RO. Parsing and the postback live in ../bvb/issuer.js.

.import "../bvb/issuer.js" as Bvb

var id = "bvb";
var label = "BVB";
var optional = false;

function supports(settings, symbol) {
    return settings.newsSourceBvb === true && Bvb.baseSymbol(symbol) !== "";
}

function fetch(ctx, done) {
    Bvb.fetch(ctx, done);
}

function pageUrl(symbol) {
    return Bvb.detailUrl(symbol);
}
