import QtQuick
import QtTest
import "../../contents/ui/providers/news/registry.js" as Registry

TestCase {
    name: "NewsRegistry"

    function settings(yahoo, bvb, google) {
        return { newsSourceYahoo: yahoo, newsSourceBvb: bvb, newsSourceGoogle: google };
    }

    function ids(sources) {
        var out = [];
        for (var i = 0; i < sources.length; i++) out.push(sources[i].id);
        return out.join(",");
    }

    function test_orderAndSettings() {
        compare(ids(Registry.enabledSources(settings(true, true, true), "TLV.RO")),
                "yahoo,bvb,google");
        // BVB only covers .RO symbols.
        compare(ids(Registry.enabledSources(settings(true, true, true), "AAPL")),
                "yahoo,google");
        compare(ids(Registry.enabledSources(settings(false, false, true), "TLV.RO")),
                "google");
        compare(ids(Registry.enabledSources(settings(false, false, false), "TLV.RO")), "");
    }

    function test_hasAny() {
        verify(Registry.hasAny(settings(true, false, false), "AAPL"));
        verify(!Registry.hasAny(settings(false, true, false), "AAPL"));
        verify(Registry.hasAny(settings(false, true, false), "BRD.RO"));
    }

    function test_optional() {
        compare(Registry.byId("yahoo").optional, false);
        compare(Registry.byId("bvb").optional, false);
        compare(Registry.byId("google").optional, true);
        compare(Registry.byId("nope"), null);
    }
}
