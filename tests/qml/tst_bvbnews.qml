import QtQuick
import QtTest
import "Fixture.js" as Fixture
import "../../contents/ui/bvbnews.js" as BvbNews

TestCase {
    name: "BvbNews"

    function test_symbols() {
        compare(BvbNews.baseSymbol("TLV.RO"), "TLV");
        compare(BvbNews.baseSymbol("tlv.ro"), "TLV");
        compare(BvbNews.baseSymbol("SAP.DE"), "");
        compare(BvbNews.baseSymbol("TLV.RO "), "TLV");
        compare(BvbNews.detailUrl("TLV.RO"),
                "https://www.bvb.ro/FinancialInstruments/Details/FinancialInstrumentsDetails.aspx?s=TLV");
        compare(BvbNews.detailUrl("SAP.DE"), "");
    }

    function test_parseTop() {
        var html = Fixture.read(Qt.resolvedUrl("../fixtures/bvb-issuer-tlv.html"));
        var items = BvbNews.parseTop(html, "TLV.RO", 10);
        compare(items.length, 5);
        // A headline containing ">" inside the attribute must not be dropped.
        compare(items[0].title, "Notificare prag detineri > 5%");
        for (var i = 0; i < items.length; i++) {
            compare(items[i].source, "BVB");
            compare(items[i].publisher, "BVB");
            verify(items[i].link.indexOf("https://bvb.ro/") === 0);
            verify(items[i].time > 0);
        }
        for (var j = 1; j < items.length; j++)
            verify(items[j - 1].time >= items[j].time);
        compare(BvbNews.parseTop(html, "TLV.RO", 2).length, 2);
    }

    function test_postBody() {
        var html = Fixture.read(Qt.resolvedUrl("../fixtures/bvb-issuer-tlv.html"));
        var body = BvbNews.postBody(html);
        verify(body.length > 0);
        verify(body.indexOf("__VIEWSTATE=") === 0);
        verify(body.indexOf("__EVENTVALIDATION=") > 0);
        verify(body.indexOf("IFTC") > 0);
        verify(body.indexOf("=Stiri") > 0);
        // Without the ASP.NET state the caller keeps the five embedded entries.
        compare(BvbNews.postBody("<html><body>no form</body></html>"), "");
    }

    function test_parseTopMissingTable() {
        compare(BvbNews.parseTop("<html></html>", "TLV.RO", 10).length, 0);
    }
}
