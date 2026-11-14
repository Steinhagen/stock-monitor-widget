import QtQuick
import QtTest

TestCase {
    name: "MarketController"

    function make(extended, keep) {
        var component = Qt.createComponent(Qt.resolvedUrl("../../contents/ui/controllers/MarketController.qml"));
        compare(component.status, Component.Ready, component.errorString());
        var controller = component.createObject(this, {
            "showExtendedHours": extended === undefined ? true : extended,
            "keepExtendedAfterClose": keep === undefined ? true : keep
        });
        verify(controller !== null);
        return controller;
    }

    function meta(regularStart, regularEnd) {
        return {
            currentTradingPeriod: { regular: { start: regularStart, end: regularEnd } },
            hasPrePostMarketData: true,
            regularMarketTime: regularStart + 60,
            instrumentType: "EQUITY"
        };
    }

    function test_openSession() {
        var market = make();
        var now = Math.floor(Date.now() / 1000);
        market.setMarketSession("X", meta(now - 3600, now + 3600));
        compare(market.statusFor("X"), "open");
        compare(market.isMarketClosedFor("X"), false);
        compare(market.awaitingFirstRegularQuote("X"), false);
    }

    function test_awaitingFirstQuoteKeepsPreMarket() {
        var market = make();
        var now = Math.floor(Date.now() / 1000);
        // The regular session started but the quote is still the previous close.
        market.setMarketSession("X", {
            currentTradingPeriod: { regular: { start: now - 60, end: now + 600 } },
            hasPrePostMarketData: true,
            regularMarketTime: 0
        });
        compare(market.statusFor("X"), "open");
        compare(market.awaitingFirstRegularQuote("X"), true);
        market.setLastExtendedData("X", { kind: "pre", time: now - 300, price: "1", change: "+0.1", pct: "+1%" });
        compare(market.extendedQuoteFor("X").kind, "pre");
    }

    function test_closedKeepsLastQuoteWhenAsked() {
        var now = Math.floor(Date.now() / 1000);
        var post = { kind: "post", time: now - 4000, price: "1", change: "+0.1", pct: "+1%" };

        var keep = make(true, true);
        keep.setMarketSession("X", meta(now - 7200, now - 3600));
        keep.setLastExtendedData("X", post);
        compare(keep.statusFor("X"), "closed");
        compare(keep.extendedQuoteFor("X").kind, "post");

        var drop = make(true, false);
        drop.setMarketSession("X", meta(now - 7200, now - 3600));
        drop.setLastExtendedData("X", post);
        compare(drop.extendedQuoteFor("X"), undefined);
    }

    function test_clears() {
        var market = make();
        var now = Math.floor(Date.now() / 1000);
        market.setMarketSession("X", meta(now - 3600, now + 3600));
        market.setExtendedData("X", { kind: "pre", time: now });
        market.setLastExtendedData("X", { kind: "pre", time: now });
        market.clearExtended();
        compare(market.extendedData.X, undefined);
        compare(market.lastExtendedData.X, undefined);
        verify(market.hasSession("X"));
    }

    function test_disabled() {
        var market = make(false);
        var now = Math.floor(Date.now() / 1000);
        market.setMarketSession("X", meta(now - 3600, now + 3600));
        market.setLastExtendedData("X", { kind: "post", time: now });
        compare(market.extendedQuoteFor("X"), undefined);
    }
}
