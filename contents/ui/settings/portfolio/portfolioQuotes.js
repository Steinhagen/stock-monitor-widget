.pragma library
// Ticker extraction and Yahoo chart-meta parsing for the portfolio page's quotes.
// Kept out of the QML so the shapes can be tested without a network.

// Unique, upper-case tickers for the lots, in first-seen order.
function tickers(lots) {
    var seen = {};
    var result = [];
    for (var i = 0; i < (lots ? lots.length : 0); i++) {
        var ticker = String(lots[i].ticker || "").trim().toUpperCase();
        if (ticker === "" || seen[ticker]) continue;
        seen[ticker] = true;
        result.push(ticker);
    }
    return result;
}

// The quote fields the portfolio needs from a /v8/finance/chart reply: the current
// price, currency, previous close and quote time. Returns null on any unexpected shape
// or a missing price.
function parse(reply) {
    try {
        var result = reply.chart.result[0];
        var meta = result.meta;
        var price = Number(meta.regularMarketPrice);
        if (!(price > 0)) return null;
        return {
            price: price,
            currency: meta.currency || "",
            previousClose: Number(meta.chartPreviousClose) || Number(meta.previousClose) || 0,
            time: Number(meta.regularMarketTime) || 0
        };
    } catch (e) {
        return null;
    }
}
