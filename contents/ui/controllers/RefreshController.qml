import QtQuick

// The refresh cycle: the periodic timer, the market-hours/weekend gate, the single vs
// list decision and the pre/post-hours requests. The actual quote requests stay in the
// quote controllers; this only decides when and what to ask for.
Item {
    id: refresh

    property var applet
    property var market

    // Tests create the controller with this off so the startup trigger does not fire.
    property bool enabled: true

    function refreshExtended() {
        if (!applet.showExtendedHours) return;
        if (applet.isMultiMode) {
            String(applet.multiTickers || "").split(",").forEach(function(t) {
                var clean = t.trim();
                if (clean !== "") market.fetchExtendedHours(clean);
            });
        } else if (applet.singleTicker.trim() !== "") {
            market.fetchExtendedHours(applet.singleTicker);
        }
    }

    function refreshQuotes() {
        if (applet.isMultiMode) {
            applet.fetchMultiStocks();
            // The list request covers the chart only when both use the same range.
            if (applet.effectiveChartRange !== applet.chartRange && applet.singleTicker.trim() !== "")
                applet.fetchSingleStock(applet.singleTicker);
        } else {
            applet.fetchSingleStock(applet.singleTicker);
            // The chart can use a range of its own; the panel must keep the configured one.
            if (applet.effectiveChartRange !== applet.chartRange)
                applet.fetchPanelStock(applet.singleTicker);
        }
        refreshExtended();
    }

    // Weekend and configured-hours gate in front of a refresh.
    function checkTime() {
        var d = new Date();
        var day = d.getDay();
        // 0 = Sunday, 6 = Saturday.
        if (applet.skipWeekendRefresh && (day === 0 || day === 6)) return;

        if (applet.limitHours) {
            var currentTimeVal = d.getHours() * 60 + d.getMinutes();
            var startTimeVal = applet.startHour * 60 + applet.startMinute;
            var endTimeVal = applet.endHour * 60 + applet.endMinute;
            if (currentTimeVal < startTimeVal || currentTimeVal >= endTimeVal) return;
        }

        refreshQuotes();
    }

    Timer {
        interval: Math.max(1, applet.refreshIntervalMinutes) * 60000
        running: refresh.enabled
        repeat: true
        triggeredOnStart: true
        onTriggered: refresh.checkTime()
    }
}
