import QtQuick
import QtTest
import "../../contents/ui/domain/chart.js" as Chart

TestCase {
    name: "Chart"

    function test_inExtendedSession() {
        var period = { start: 100, end: 200 };
        verify(Chart.inExtendedSession(period, 100, "pre"));
        verify(!Chart.inExtendedSession(period, 200, "pre"));
        verify(Chart.inExtendedSession(period, 200, "post"));
        verify(!Chart.inExtendedSession(null, 150, "pre"));
    }

    function test_tradingDays() {
        var meta = { tradingPeriods: { regular: [[{ start: 10, end: 20 }]] },
                     currentTradingPeriod: { regular: { start: 10, end: 20 } } };
        var days = Chart.tradingDays(meta);
        compare(days.length, 1);
        compare(days[0].regular.start, 10);
        compare(days[0].pre, null);
        compare(Chart.tradingDays(null).length, 0);
    }

    function test_dailyPreviousClose() {
        compare(Chart.dailyPreviousClose({ regularMarketPreviousClose: 10 }, 0), 10);
        compare(Chart.dailyPreviousClose({ regularMarketPrice: 10, fulldayChange: 2 }, 0), 8);
        compare(Chart.dailyPreviousClose({ regularMarketPrice: 11, regularMarketChangePercent: 10 }, 0), 10);
        compare(Chart.dailyPreviousClose(null, 7), 7);
        compare(Chart.dailyPreviousClose(null, 0), 0);
    }
}
