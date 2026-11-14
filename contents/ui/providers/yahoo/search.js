.pragma library
// Yahoo's symbol search, used by the Symbols & Lists page. Returns the same compact
// { symbol, name } records the settings list shows.

.import "../../core/Http.js" as Http

function searchUrl(query) {
    return "https://query2.finance.yahoo.com/v1/finance/search?q=" + encodeURIComponent(query);
}

function parse(reply) {
    var quotes = reply && Array.isArray(reply.quotes) ? reply.quotes : [];
    var results = [];
    for (var i = 0; i < quotes.length; i++) {
        var item = quotes[i];
        if (!item || !item.symbol) continue;
        results.push({
            symbol: item.symbol,
            name: item.shortname || item.longname || item.symbol
        });
    }
    return results;
}

// done(results, error) with results = [{ symbol, name }].
function search(query, done) {
    var text = String(query === undefined || query === null ? "" : query).trim();
    if (text === "") {
        done([], null);
        return;
    }
    Http.getJson(searchUrl(text), { timeout: 20000 }, function(reply, error) {
        if (error) {
            done(null, error);
            return;
        }
        done(parse(reply), null);
    });
}
