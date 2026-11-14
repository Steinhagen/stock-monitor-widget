import QtQuick
import "../../core/Http.js" as Http
import "portfolioQuotes.js" as QuoteData

// The portfolio page's price lookups: one Yahoo chart request per unique ticker, with
// a generation token so a refresh that follows a ticker change cannot mix replies.
QtObject {
    id: quotes

    property var data: ({})
    property bool loading: false
    property string error: ""
    property int pending: 0
    property int generation: 0

    function refresh(lots) {
        var tickers = QuoteData.tickers(lots);
        generation++;
        error = "";
        pending = tickers.length;
        loading = tickers.length > 0;
        if (tickers.length === 0) return;
        for (var i = 0; i < tickers.length; i++)
            fetchQuote(tickers[i], generation);
    }

    function fetchQuote(ticker, requestId) {
        Http.getJson("https://query1.finance.yahoo.com/v8/finance/chart/"
                     + encodeURIComponent(ticker) + "?range=1d&interval=1d", {},
                     function(reply, failure) {
            if (requestId !== quotes.generation) return;
            if (reply) {
                var quote = QuoteData.parse(reply);
                if (quote) {
                    var copy = Object.assign({}, quotes.data);
                    copy[ticker] = quote;
                    quotes.data = copy;
                } else {
                    quotes.error = i18n("Some quotes are unavailable.");
                }
            } else {
                quotes.error = i18n("Some quotes are unavailable.");
            }
            quotes.pending--;
            if (quotes.pending <= 0) quotes.loading = false;
        });
    }
}
