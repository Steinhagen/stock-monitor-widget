import QtQuick
import QtTest
import "../../contents/ui/settings/portfolio/portfolioQuotes.js" as Quotes

TestCase {
    name: "PortfolioQuotes"

    function test_tickers() {
        var lots = [
            { ticker: " sap " }, { ticker: "TLV" }, { ticker: "SAP" }, { ticker: "" }, {}
        ];
        var list = Quotes.tickers(lots);
        compare(list.length, 2);
        compare(list[0], "SAP");
        compare(list[1], "TLV");
        compare(Quotes.tickers([]).length, 0);
        compare(Quotes.tickers(null).length, 0);
    }

    function test_parse() {
        var reply = {
            chart: { result: [{ meta: {
                regularMarketPrice: 213.45,
                currency: "EUR",
                chartPreviousClose: 212.25,
                regularMarketTime: 1000
            } }] }
        };
        var quote = Quotes.parse(reply);
        compare(quote.price, 213.45);
        compare(quote.currency, "EUR");
        compare(quote.previousClose, 212.25);
        compare(quote.time, 1000);
    }

    function test_parseInvalid() {
        compare(Quotes.parse({}), null);
        compare(Quotes.parse({ chart: { result: [{ meta: {} }] } }), null);
        compare(Quotes.parse({ chart: { result: [{ meta: { regularMarketPrice: 0 } }] } }), null);
    }
}
