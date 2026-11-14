import QtQuick
import QtTest
import "Fixture.js" as Fixture
import "../../contents/ui/providers/yahoo/news.js" as News

TestCase {
    name: "YahooNews"

    function test_searchUrl() {
        var url = News.searchUrl("SAP SE", 24);
        compare(url, "https://query2.finance.yahoo.com/v1/finance/search?q=SAP%20SE&quotesCount=0&newsCount=28");
    }

    function test_safeLink() {
        compare(News.safeLink("https://example.com/a", "SAP.DE"), "https://example.com/a");
        compare(News.safeLink("javascript:alert(1)", "SAP.DE"),
                "https://finance.yahoo.com/quote/SAP.DE/news");
        compare(News.safeLink("", "SAP.DE"), "https://finance.yahoo.com/quote/SAP.DE/news");
    }

    function test_decodeEntities() {
        compare(News.decodeEntities("A &amp; B &lt; C &#233; &#x27;"), "A & B < C é '");
        compare(News.decodeEntities("no entities"), "no entities");
        compare(News.decodeEntities("&#x110000;"), "&#x110000;");
    }

    function test_parseFixture() {
        var data = JSON.parse(Fixture.read(Qt.resolvedUrl("../fixtures/yahoo-search-sap.json")));
        // The ticker query accepts only the exact tag, which Yahoo does not use for SAP.DE.
        compare(News.parse(data, "SAP.DE", false, 10).length, 0);
        // The name query accepts the base symbol; every kept item is tagged SAP.
        var items = News.parse(data, "SAP.DE", true, 10);
        verify(items.length > 0);
        for (var i = 0; i < items.length; i++) {
            compare(items[i].source, "Yahoo");
            verify(items[i].title !== "");
            verify(items[i].link.indexOf("http") === 0);
        }
        // Newest first.
        for (var j = 1; j < items.length; j++)
            verify(items[j - 1].time >= items[j].time);
        // The limit is applied after filtering.
        compare(News.parse(data, "SAP.DE", true, 2).length, 2);
    }

    function test_parseFiltersAndDedupes() {
        var data = { news: [
            { uuid: "u1", title: "One", publisher: "P", link: "https://a", providerPublishTime: 3, relatedTickers: ["SAP"] },
            { uuid: "u1", title: "One again", publisher: "P", link: "https://b", providerPublishTime: 2, relatedTickers: ["SAP"] },
            { uuid: "u2", title: "Other", publisher: "P", link: "https://c", providerPublishTime: 1, relatedTickers: ["MSFT"] },
            { uuid: "u3", title: "", publisher: "P", link: "https://d", providerPublishTime: 0, relatedTickers: ["SAP"] }
        ] };
        var items = News.parse(data, "SAP.DE", true, 10);
        compare(items.length, 1);
        compare(items[0].title, "One");
        compare(items[0].id, "u1");
    }

}
