import QtQuick
import QtTest
import "Fixture.js" as Fixture
import "../../contents/ui/googlenews.js" as GoogleNews

TestCase {
    name: "GoogleNews"

    function test_localeParams() {
        compare(GoogleNews.localeParams("ro_RO"), "&hl=ro&gl=RO&ceid=RO:ro");
        compare(GoogleNews.localeParams("de_DE"), "&hl=de&gl=DE&ceid=DE:de");
        // Google's English editions need a region, so English always uses en-US.
        compare(GoogleNews.localeParams("en_GB"), "&hl=en-US&gl=US&ceid=US:en");
        compare(GoogleNews.localeParams("C"), "&hl=en-US&gl=US&ceid=US:en");
        compare(GoogleNews.localeParams(""), "&hl=en-US&gl=US&ceid=US:en");
    }

    function test_query() {
        // Legal suffixes go away when two words remain.
        compare(GoogleNews.query("Banca Transilvania S.A."), "\"Banca Transilvania\"");
        compare(GoogleNews.query("A.P. Møller - Mærsk A/S"), "\"A.P. Møller - Mærsk\"");
        // A single word keeps them, because "Vale" or "Eni" alone are ambiguous.
        compare(GoogleNews.query("Vale S.A."), "\"Vale S.A.\"");
        compare(GoogleNews.query("SAP SE"), "\"SAP SE\"");
        compare(GoogleNews.query("  "), "");
        compare(GoogleNews.query("A \"quoted\" name"), "\"A quoted name\"");
    }

    function test_urls() {
        var url = GoogleNews.feedUrl("SAP SE", "en_US");
        compare(url, "https://news.google.com/rss/search?q=%22SAP%20SE%22&hl=en-US&gl=US&ceid=US:en");
        var page = GoogleNews.searchPageUrl("SAP SE", "ro_RO");
        compare(page, "https://news.google.com/search?q=%22SAP%20SE%22&hl=ro&gl=RO&ceid=RO:ro");
        compare(GoogleNews.feedUrl("", "ro_RO"), "");
    }

    function test_parseFixture() {
        var items = GoogleNews.parse(Fixture.read(Qt.resolvedUrl("../fixtures/google-news-sap.xml")), 100);
        compare(items.length, 6);
        for (var i = 0; i < items.length; i++) {
            compare(items[i].source, "Google");
            verify(items[i].title !== "");
            verify(items[i].link.indexOf("https://") === 0);
            verify(items[i].time > 0);
            // The " - Publisher" suffix is stripped, not repeated in the title.
            if (items[i].publisher !== "")
                verify(items[i].title.indexOf(" - " + items[i].publisher) < 0);
        }
        for (var j = 1; j < items.length; j++)
            verify(items[j - 1].time >= items[j].time);
        compare(GoogleNews.parse(Fixture.read(Qt.resolvedUrl("../fixtures/google-news-sap.xml")), 2).length, 2);
    }

    function test_parseRejectsHtml() {
        var body = Fixture.read(Qt.resolvedUrl("../fixtures/google-news-blocked.html"));
        compare(GoogleNews.parse(body, 10).length, 0);
    }

    function test_parseFiltersQuotePagesAndDedupes() {
        var xml = "<rss><channel>"
            + "<item><title>Vale S.A. (VALE) Stock Price, News, Quote &amp; History - Yahoo Finance</title>"
            + "<link>https://x/q</link><source>Yahoo Finance</source></item>"
            + "<item><title>Real headline - Pub</title><link>https://x/1</link>"
            + "<pubDate>Fri, 14 Nov 2026 10:00:00 GMT</pubDate><source>Pub</source><guid>g1</guid></item>"
            + "<item><title>Real headline - Pub</title><link>https://x/1</link><source>Pub</source></item>"
            + "<item><title>No source</title><link>https://x/2</link></item>"
            + "</channel></rss>";
        var items = GoogleNews.parse(xml, 10);
        compare(items.length, 2);
        compare(items[0].title, "Real headline");
        compare(items[1].title, "No source");
    }

    function test_parseRfc822() {
        compare(GoogleNews.parseRfc822("Tue, 10 Nov 2026 07:55:22 GMT"),
                Math.floor(Date.UTC(2026, 10, 10, 7, 55, 22) / 1000));
        compare(GoogleNews.parseRfc822("not a date"), 0);
        compare(GoogleNews.parseRfc822(""), 0);
    }
}
