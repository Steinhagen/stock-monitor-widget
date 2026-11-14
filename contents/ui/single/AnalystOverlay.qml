import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../domain/analysts.js" as Analyst

// Analyst price-target markers overlaid on the chart. The component owns the geometry,
// the marker shapes and the details popup; SingleStockView only places it over the
// chart and asks whether a small plot gap should be reserved for it.
Item {
    id: analystRoot
    property var applet
    // The news pane uses the same chart area, so the markers must disappear with it.
    property bool chartVisible: true

    readonly property bool markersShown: applet !== null && applet !== undefined
                                         && applet.showAnalystTargets
                                         && chartVisible
                                         && marks.length > 0
    visible: markersShown
    clip: false

    property var selectedMark: null
    property point popupAnchor: Qt.point(0, 0)
    // The marker under the cursor, for the hover card.
    property var hoverMark: null
    property point hoverAnchor: Qt.point(0, 0)

    readonly property color popupBackground: applet && applet.appDrawnSurface
                                             ? (applet.isLightTheme ? "#ffffff" : "#1a1a1a")
                                             : Kirigami.Theme.backgroundColor
    readonly property color popupText: applet && applet.appDrawnSurface
                                       ? (applet.isLightTheme ? "#171a1c" : "#f3f5f6")
                                       : Kirigami.Theme.textColor

    FontMetrics {
        id: axisMetrics
        font.pixelSize: 9
        font.family: "sans-serif"
    }
    FontMetrics { id: firmMetrics; font.pixelSize: 11; font.bold: true; font.family: "sans-serif" }
    FontMetrics { id: captionMetrics; font.pixelSize: 10; font.bold: true; font.family: "sans-serif" }
    FontMetrics { id: smallMetrics; font.pixelSize: 9; font.family: "sans-serif" }
    FontMetrics { id: oldMetrics; font.pixelSize: 10; font.family: "sans-serif" }
    FontMetrics { id: priceMetrics; font.pixelSize: 12; font.bold: true; font.family: "sans-serif" }

    onMarkersShownChanged: if (!markersShown && detailsPopup) detailsPopup.close()

    Connections {
        target: analystRoot.applet
        function onSingleTickerChanged() { if (detailsPopup) detailsPopup.close(); }
    }

    // The price range used by the chart, so the width reserved by its price scale can
    // be reproduced here. This mirrors drawReferenceChart()/drawCandleChart().
    function targetRange() {
        if (!applet) return null;
        var data = applet.chartDataPoints;
        if (!Array.isArray(data) || data.length < 2) return null;
        var candles = applet.chartCandles;
        if (applet.chartStyle === 1 && Array.isArray(candles) && candles.length > 1) {
            var cMin = Infinity, cMax = -Infinity;
            for (var ci = 0; ci < candles.length; ci++) {
                if (candles[ci].low < cMin) cMin = candles[ci].low;
                if (candles[ci].high > cMax) cMax = candles[ci].high;
            }
            if (!(cMax > cMin)) return null;
            var cPad = (cMax - cMin) * 0.06;
            return { min: cMin - cPad, max: cMax + cPad };
        }
        var times = applet.chartTimestamps;
        var s = applet.chartSessions;
        if (s && (!Array.isArray(times) || times.length !== data.length)) s = null;
        var allData = data;
        if (s) {
            var pre = Array.isArray(s.preValues) ? s.preValues : [];
            var post = Array.isArray(s.postValues) ? s.postValues : [];
            allData = pre.concat(data, post);
        }
        var minVal = Math.min.apply(null, allData);
        var maxVal = Math.max.apply(null, allData);
        if (!isFinite(minVal) || !isFinite(maxVal)) return null;
        var ref = applet.chartReferencePrice > 0
                  ? applet.chartReferencePrice
                  : (applet.previousClose > 0 ? applet.previousClose : data[0]);
        if (!isFinite(ref)) return null;
        if (ref < minVal) minVal = ref;
        if (ref > maxVal) maxVal = ref;
        var range = maxVal - minVal;
        if (!(range > 0)) range = 1;
        var padding = range * 0.08;
        return { min: minVal - padding, max: maxVal + padding };
    }

    readonly property real plotRight: {
        if (!applet) return 0;
        var w = analystRoot.width;
        if (!(w > 20)) return 0;
        if (!applet.showChartAxis) return w;
        var bounds = targetRange();
        if (!bounds) return w;
        var ticks = axisTicks(bounds.min, bounds.max, 5);
        var labelW = 0;
        for (var i = 0; i < ticks.length; i++) {
            labelW = Math.max(labelW,
                              Math.ceil(axisMetrics.advanceWidth(
                                  applet.formatNumber(ticks[i], false))));
        }
        var right = w - labelW - 10;
        return right < 24 ? w : right;
    }

    function axisTicks(minVal, maxVal, targetCount) {
        var range = maxVal - minVal;
        if (!(range > 0)) range = 1;
        var rawStep = range / Math.max(2, targetCount || 5);
        var mag = Math.pow(10, Math.floor(Math.log(rawStep) / Math.LN10));
        var norm = rawStep / mag;
        var step = (norm < 1.5 ? 1 : norm < 3 ? 2 : norm < 7 ? 5 : 10) * mag;
        var ticks = [];
        for (var v = Math.ceil(minVal / step) * step; v <= maxVal + step * 1e-6; v += step)
            ticks.push(v);
        return ticks;
    }

    // Vertical layout around the existing price/volume separator line. This mirrors the
    // time-axis and volume-strip decisions in the chart drawing functions.
    readonly property real timeAxisHeight: {
        if (!applet || !applet.showTimeAxis) return 0;
        var h = analystRoot.height;
        if (!(h > 20)) return 0;
        var candles = applet.chartCandles;
        if (applet.chartStyle === 1 && Array.isArray(candles) && candles.length > 1) {
            return Number(candles[0].time) > 0
                   && Number(candles[candles.length - 1].time) > 0 ? 16 : 0;
        }
        var data = applet.chartDataPoints;
        var times = applet.chartTimestamps;
        return Array.isArray(data) && Array.isArray(times) && data.length > 1
               && times.length === data.length && Number(times[0]) > 0 ? 16 : 0;
    }

    readonly property real volumeTop: {
        if (!applet) return -1;
        var h = analystRoot.height;
        if (!(h > 20) || !applet.showChartVolume || applet.chartPreSession) return -1;
        var candles = applet.chartCandles;
        if (!Array.isArray(candles)) return -1;
        var useCandles = applet.chartStyle === 1 && candles.length > 1;
        var maxVolume = 0;
        var regularCount = 0;
        for (var i = 0; i < candles.length; i++) {
            var candle = candles[i];
            if (!candle || candle.zone === "pre" || candle.zone === "post") continue;
            regularCount++;
            if (candle.volume > maxVolume) maxVolume = candle.volume;
        }
        if (!(maxVolume > 0) || (!useCandles && regularCount < 2)) return -1;
        var volumeBottom = h - timeAxisHeight;
        var volumeHeight = Math.min(54, Math.max(26, h * 0.13));
        var top = volumeBottom - volumeHeight;
        if (top - (markersShown ? 22 : 8) < 36) return -1;
        return top;
    }

    // Top of the 14 px marker item. The chart reserves a gap above the volume separator
    // so the glyphs sit a few pixels above the line; without a volume strip the same gap
    // keeps them above the time axis, not over its labels.
    readonly property real markerTop: {
        var h = analystRoot.height;
        var bottom = h - timeAxisHeight;
        return (volumeTop > 0 ? volumeTop : bottom) - 18;
    }

    function sameCalendarDay(a, b) {
        var da = new Date(a * 1000);
        var db = new Date(b * 1000);
        return da.getFullYear() === db.getFullYear()
               && da.getMonth() === db.getMonth()
               && da.getDate() === db.getDate();
    }

    function nearestTimeIndex(times, time) {
        if (time <= times[0]) return 0;
        if (time >= times[times.length - 1]) return times.length - 1;
        var lo = 0, hi = times.length - 1;
        while (lo + 1 < hi) {
            var mid = Math.floor((lo + hi) / 2);
            if (Number(times[mid]) <= time) lo = mid; else hi = mid;
        }
        return time - Number(times[lo]) <= Number(times[hi]) - time ? lo : hi;
    }

    // Pixel position of one timestamp on the chart's x scale.
    function timeX(time) {
        if (!applet) return -1;
        var plot = plotRight;
        if (!(plot > 20) || !(time > 0)) return -1;
        var data = applet.chartDataPoints;
        var times = applet.chartTimestamps;
        var candles = applet.chartCandles;
        var useCandles = applet.chartStyle === 1
                         && Array.isArray(candles) && candles.length > 1;
        if (useCandles) {
            var cFirst = Number(candles[0].time);
            var cLast = Number(candles[candles.length - 1].time);
            if (!(cFirst > 0) || !(cLast >= cFirst)) return -1;
            if (time < cFirst) return sameCalendarDay(time, cFirst) ? 0 : -1;
            if (time > cLast) return sameCalendarDay(time, cLast) ? plot : -1;
            var ci = 0, cDiff = Infinity;
            for (var i = 0; i < candles.length; i++) {
                var d = Math.abs(Number(candles[i].time) - time);
                if (d < cDiff) { cDiff = d; ci = i; }
            }
            return plot * (ci + 0.5) / candles.length;
        }
        var s = applet.chartSessions;
        if (s && Array.isArray(data) && Array.isArray(times)
                && times.length === data.length) {
            var allTimes = (s.preTimes || []).concat(times, s.postTimes || []);
            if (allTimes.length >= 2 && allTimes[0] > 0
                    && allTimes[allTimes.length - 1] > allTimes[0]) {
                if (time < allTimes[0])
                    return sameCalendarDay(time, allTimes[0]) ? 0 : -1;
                if (time > allTimes[allTimes.length - 1])
                    return sameCalendarDay(time, allTimes[allTimes.length - 1]) ? plot : -1;
                return plot * (time - allTimes[0])
                       / (allTimes[allTimes.length - 1] - allTimes[0]);
            }
        }
        if (!Array.isArray(times) || !Array.isArray(data)
                || times.length !== data.length || data.length < 2
                || !(times[0] > 0) || !(times[times.length - 1] > times[0]))
            return -1;
        if (time < times[0]) return sameCalendarDay(time, times[0]) ? 0 : -1;
        if (time > times[times.length - 1])
            return sameCalendarDay(time, times[times.length - 1]) ? plot : -1;
        var index = nearestTimeIndex(times, time);
        return plot * index / (times.length - 1);
    }

    readonly property var marks: {
        if (!applet || !applet.showAnalystTargets) return [];
        var items = applet.analystItems;
        if (!Array.isArray(items) || items.length === 0) return [];
        var plot = plotRight;
        if (!(plot > 20)) return [];
        var buckets = ({});
        for (var i = 0; i < items.length; i++) {
            var item = items[i];
            var x = timeX(Number(item.time));
            if (!(x >= 0)) continue;
            var bucket = Math.round(x / 16);
            var group = buckets[bucket];
            if (!group) {
                group = { xSum: 0, entries: [] };
                buckets[bucket] = group;
            }
            group.xSum += x;
            group.entries.push(item);
        }
        var result = [];
        for (var key in buckets) {
            var g = buckets[key];
            if (!g || g.entries.length === 0) continue;
            g.entries.sort(function(a, b) { return b.time - a.time; });
            var counts = Analyst.directions(g.entries);
            var direction = directionForCounts(counts);
            result.push({
                x: g.xSum / g.entries.length,
                direction: direction,
                entries: g.entries,
                total: g.entries.length,
                newest: g.entries[0]
            });
        }
        result.sort(function(a, b) { return a.x - b.x; });

        // Bucket edges can leave two markers closer than their own width, so their
        // glyphs overlap. Merge those groups into one marker that reflects every
        // action, keeping the combined entries newest-first.
        var merged = [];
        for (var m = 0; m < result.length; m++) {
            var mark = result[m];
            var last = merged[merged.length - 1];
            if (last && Math.abs(mark.x - last.x) < 18) {
                var combined = last.entries.concat(mark.entries);
                combined.sort(function(a, b) { return b.time - a.time; });
                var totalBefore = last.total + mark.total;
                last.x = (last.x * last.total + mark.x * mark.total) / totalBefore;
                last.total = combined.length;
                last.entries = combined;
                last.newest = combined[0];
                last.direction = directionForCounts(Analyst.directions(combined));
            } else {
                merged.push(mark);
            }
        }
        return merged;
    }

    function directionForCounts(counts) {
        if (counts.up > 0 && counts.down === 0) return "up";
        if (counts.down > 0 && counts.up === 0) return "down";
        if (counts.up === 0 && counts.down === 0) {
            if (counts.maintain > 0 && counts.announce === 0) return "maintain";
            if (counts.announce > 0 && counts.maintain === 0) return "announce";
        }
        return "neutral";
    }

    function money(value) {
        return value > 0 ? applet.currencySym + applet.formatNumber(value, false) : "";
    }

    function targetText(entry) {
        if (!entry) return "";
        var target = money(entry.target);
        var prior = money(entry.prior);
        switch (entry.kind) {
            case "up":
                return prior !== "" ? i18n("Raised target from %1 to %2", prior, target)
                                    : i18n("New target %1", target);
            case "down":
                return prior !== "" ? i18n("Lowered target from %1 to %2", prior, target)
                                    : i18n("New target %1", target);
            case "maintain":
                return i18n("Maintained target at %1", target);
            default:
                return i18n("New target %1", target);
        }
    }

    function ratingText(entry) {
        if (!entry) return "";
        var from = String(entry.fromGrade || "").trim();
        var to = String(entry.toGrade || "").trim();
        if (from !== "" && to !== "" && from !== to)
            return i18n("Rating: %1 → %2", from, to);
        if (to !== "") return i18n("Rating: %1", to);
        if (from !== "") return i18n("Rating: %1", from);
        return "";
    }

    function entryDate(entry) {
        return new Date(entry.time * 1000).toLocaleDateString(Qt.locale(), "d MMM yyyy");
    }

    function markerTooltip(mark) {
        if (!mark || !mark.newest) return "";
        var latest = mark.newest;
        var prefix = mark.total > 1
                     ? i18np("%1 analyst action", "%1 analyst actions", mark.total) + " · "
                     : "";
        return prefix + latest.firm + " · " + targetText(latest);
    }

    function hoverCaption(entry) {
        if (!entry) return "";
        if (entry.kind === "up") return i18n("Target raised");
        if (entry.kind === "down") return i18n("Target lowered");
        if (entry.kind === "maintain") return i18n("Target maintained");
        return i18n("New target");
    }

    function hoverGlyph(entry) {
        if (!entry) return "";
        if (entry.kind === "up") return "▲";
        if (entry.kind === "down") return "▼";
        if (entry.kind === "maintain") return "—";
        return "+";
    }

    function hoverFooterCount(mark) {
        if (!mark) return "";
        return mark.total > 3
               ? i18n("Showing the latest %1 of %2 actions", 3, mark.total)
               : i18np("Showing %1 action", "Showing %1 actions", mark.total);
    }

    // Width of one action row, without the card padding.
    function rowWidth(entry) {
        if (!entry) return 0;
        var firmDate = firmMetrics.advanceWidth(entry.firm) + 8 + 66;
        var caption = captionMetrics.advanceWidth(hoverCaption(entry));
        var prices = oldMetrics.advanceWidth(money(entry.prior)) + 12
                   + priceMetrics.advanceWidth(money(entry.target));
        return 32 + Math.max(firmDate, caption, prices);
    }

    function hoverCardWidth(mark) {
        if (!mark) return 240;
        var width = Math.max(smallMetrics.advanceWidth(hoverFooterCount(mark)),
                             smallMetrics.advanceWidth(i18n("Click for more details")));
        var shown = Math.min(3, mark.entries.length);
        for (var i = 0; i < shown; i++)
            width = Math.max(width, rowWidth(mark.entries[i]));
        return Math.max(220, Math.min(300, width + 20));
    }

    function detailsWidth(mark) {
        var width = firmMetrics.advanceWidth(i18n("Analyst price targets")) + 70;
        width = Math.max(width, Math.min(300, smallMetrics.advanceWidth(summaryText())));
        if (mark) {
            for (var i = 0; i < mark.entries.length; i++) {
                var entry = mark.entries[i];
                var firmDate = firmMetrics.advanceWidth(entry.firm) + 8
                             + smallMetrics.advanceWidth(entryDate(entry));
                var caption = captionMetrics.advanceWidth(hoverCaption(entry));
                var prices = oldMetrics.advanceWidth(money(entry.prior)) + 12
                           + priceMetrics.advanceWidth(money(entry.target));
                var rating = smallMetrics.advanceWidth(ratingText(entry));
                width = Math.max(width, 32 + Math.max(firmDate, caption, prices, rating));
            }
        }
        return Math.max(260, Math.min(340, width + 20));
    }

    function summaryText() {
        var s = applet ? applet.analystSummary : null;
        if (!s || !(s.mean > 0)) return "";
        var text = i18n("Consensus %1", money(s.mean));
        if (s.low > 0 && s.high > 0)
            text += " · " + i18n("range %1 – %2", money(s.low), money(s.high));
        if (s.count > 0)
            text += " · " + i18np("%1 analyst", "%1 analysts", s.count);
        return text;
    }

    function positionPopup() {
        if (!detailsPopup || !detailsPopup.opened) return;
        var x = popupAnchor.x - detailsPopup.width / 2;
        var y = popupAnchor.y - detailsPopup.height - 8;
        detailsPopup.x = Math.max(8, Math.min(analystRoot.width - detailsPopup.width - 8, x));
        detailsPopup.y = Math.max(8, Math.min(analystRoot.height - detailsPopup.height - 8, y));
    }

    function openPopup(marker, mark) {
        selectedMark = mark;
        popupAnchor = marker.mapToItem(analystRoot, marker.width / 2, 0);
        detailsPopup.open();
        positionPopup();
        Qt.callLater(positionPopup);
    }

    Repeater {
        model: analystRoot.marks
        delegate: Item {
            id: marker
            required property var modelData
            readonly property color accent: modelData.direction === "up"
                                            ? applet.positiveColor
                                            : (modelData.direction === "down"
                                               ? applet.negativeColor
                                               : applet.secondaryTextColor)
            x: Math.max(0, Math.min(analystRoot.plotRight - width,
                                    modelData.x - width / 2))
            y: analystRoot.markerTop
            width: 16
            height: 14

            // Filled triangles mean a real increase/decrease. The neutral actions use
            // shapes rather than text glyphs so all markers have a comparable visual
            // size and the 16x14 item stays easy to click.
            Text {
                anchors.centerIn: parent
                visible: marker.modelData.direction === "up"
                         || marker.modelData.direction === "down"
                text: marker.modelData.direction === "up" ? "▲" : "▼"
                color: marker.accent
                opacity: 0.95
                font.pixelSize: 9
                font.bold: true
            }
            // Maintained target: a short bar, meaning "unchanged".
            Rectangle {
                anchors.centerIn: parent
                visible: marker.modelData.direction === "maintain"
                width: 8
                height: 2
                radius: 1
                color: applet.secondaryTextColor
                opacity: 0.85
            }
            // Newly announced target: a hollow circle, with no direction.
            Rectangle {
                anchors.centerIn: parent
                visible: marker.modelData.direction === "announce"
                width: 7
                height: 7
                radius: 3.5
                color: "transparent"
                border.width: 1
                border.color: applet.secondaryTextColor
                opacity: 0.9
            }
            // Mixed group: a small neutral dot.
            Rectangle {
                anchors.centerIn: parent
                visible: marker.modelData.direction === "neutral"
                width: 6
                height: 6
                radius: 3
                color: applet.secondaryTextColor
                opacity: 0.7
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    analystRoot.hoverMark = null;
                    analystRoot.openPopup(marker, marker.modelData);
                }
            }

            HoverHandler {
                id: markerHover
                onHoveredChanged: {
                    if (hovered) {
                        analystRoot.hoverMark = marker.modelData;
                        analystRoot.hoverAnchor = marker.mapToItem(analystRoot, marker.width / 2, 0);
                    } else if (analystRoot.hoverMark !== null) {
                        analystRoot.hoverMark = null;
                    }
                }
            }
        }
    }

    // Hover card for the marker under the cursor: up to three latest actions, with a
    // footer pointing at the full list.
    Item {
        id: hoverCard
        readonly property var mark: analystRoot.hoverMark
        visible: analystRoot.hoverMark !== null && !detailsPopup.opened
        z: 200
        width: analystRoot.hoverCardWidth(hoverCard.mark)
        height: cardContent.implicitHeight + 20
        x: Math.max(4, Math.min(analystRoot.width - width - 4,
                                analystRoot.hoverAnchor.x - width / 2))
        // Prefer above the marker; drop below it when the card would leave the chart.
        y: analystRoot.hoverAnchor.y - height - 10 >= 4
           ? analystRoot.hoverAnchor.y - height - 10
           : Math.max(4, Math.min(analystRoot.height - height - 4, analystRoot.hoverAnchor.y + 16))

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: analystRoot.popupBackground
            border.width: 1
            border.color: applet && applet.isLightTheme
                          ? Qt.rgba(0, 0, 0, 0.16) : Qt.rgba(1, 1, 1, 0.18)
        }

        Column {
            id: cardContent
            x: 10; y: 10
            width: parent.width - 20
            spacing: 5

            Repeater {
                model: hoverCard.mark ? hoverCard.mark.entries.slice(0, 3) : []

                delegate: Column {
                    id: hoverEntry
                    required property var modelData
                    required property int index
                    readonly property color accent: modelData.kind === "up"
                                                    ? applet.positiveColor
                                                    : (modelData.kind === "down"
                                                       ? applet.negativeColor
                                                       : applet.secondaryTextColor)
                    width: cardContent.width
                    spacing: 2

                    Rectangle {
                        width: parent.width
                        height: hoverEntry.index > 0 ? 1 : 0
                        color: applet && applet.isLightTheme
                               ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.10)
                    }

                    Row {
                        width: parent.width
                        spacing: 8

                        Rectangle {
                            width: 24; height: 24; radius: 12
                            anchors.verticalCenter: parent.verticalCenter
                            color: Qt.rgba(hoverEntry.accent.r, hoverEntry.accent.g,
                                           hoverEntry.accent.b, 0.16)
                            border.width: 1
                            border.color: hoverEntry.accent
                            Text {
                                anchors.centerIn: parent
                                text: analystRoot.hoverGlyph(hoverEntry.modelData)
                                color: hoverEntry.accent
                                font.pixelSize: 10
                                font.bold: true
                            }
                        }

                        Column {
                            width: parent.width - 32
                            spacing: 1

                            Row {
                                width: parent.width
                                Text {
                                    width: parent.width - 66
                                    text: hoverEntry.modelData.firm
                                    color: analystRoot.popupText
                                    font.pixelSize: 11
                                    font.bold: true
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: 66
                                    text: analystRoot.entryDate(hoverEntry.modelData)
                                    color: applet ? applet.secondaryTextColor : analystRoot.popupText
                                    font.pixelSize: 9
                                    horizontalAlignment: Text.AlignRight
                                }
                            }

                            Text {
                                width: parent.width
                                text: analystRoot.hoverCaption(hoverEntry.modelData)
                                color: hoverEntry.accent
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            Row {
                                spacing: 6
                                Text {
                                    visible: hoverEntry.modelData.prior > 0
                                    text: analystRoot.money(hoverEntry.modelData.prior)
                                    color: applet ? applet.secondaryTextColor : analystRoot.popupText
                                    font.pixelSize: 10
                                }
                                Text {
                                    visible: hoverEntry.modelData.prior > 0
                                    text: "→"
                                    color: applet ? applet.secondaryTextColor : analystRoot.popupText
                                    font.pixelSize: 10
                                }
                                Text {
                                    text: analystRoot.money(hoverEntry.modelData.target)
                                    color: hoverEntry.accent
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }
                            }
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 1
                Text {
                    width: parent.width
                    visible: hoverCard.mark && hoverCard.mark.total > 3
                    text: analystRoot.hoverFooterCount(hoverCard.mark)
                    color: applet ? applet.secondaryTextColor : analystRoot.popupText
                    font.pixelSize: 9
                    wrapMode: Text.WordWrap
                }
                Text {
                    width: parent.width
                    text: i18n("Click for more details")
                    color: applet ? applet.secondaryTextColor : analystRoot.popupText
                    font.pixelSize: 9
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    // Details popup for the selected marker group, using the same card language as
    // the hover card: direction badge, firm/date, action caption and old -> new target.
    Popup {
        id: detailsPopup
        parent: analystRoot
        width: Math.min(analystRoot.detailsWidth(detailsPopup.mark),
                        Math.max(200, analystRoot.width - 16))
        padding: 10
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        readonly property var mark: analystRoot.selectedMark

        onOpened: analystRoot.positionPopup()
        onHeightChanged: if (opened) analystRoot.positionPopup()
        onWidthChanged: if (opened) analystRoot.positionPopup()
        onClosed: analystRoot.selectedMark = null

        background: Rectangle {
            color: analystRoot.popupBackground
            radius: 8
            border.width: 1
            border.color: applet && applet.isLightTheme
                          ? Qt.rgba(0, 0, 0, 0.16) : Qt.rgba(1, 1, 1, 0.18)
        }

        contentItem: ColumnLayout {
            width: detailsPopup.availableWidth
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: i18n("Analyst price targets")
                    color: analystRoot.popupText
                    font.pixelSize: 11
                    font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    text: detailsPopup.mark && detailsPopup.mark.total > 1
                          ? i18np("%1 action", "%1 actions", detailsPopup.mark.total) : ""
                    color: analystRoot.applet.secondaryTextColor
                    font.pixelSize: 9
                }
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: analystRoot.summaryText()
                color: analystRoot.applet.secondaryTextColor
                font.pixelSize: 9
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(entriesColumn.implicitHeight, 360)
                spacing: entriesFlick.overflows ? 10 : 0

                Flickable {
                    id: entriesFlick
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: width
                    contentHeight: entriesColumn.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    readonly property bool overflows: contentHeight > height

                    ColumnLayout {
                        id: entriesColumn
                        width: entriesFlick.width
                        spacing: 6

                    Repeater {
                        model: detailsPopup.mark ? detailsPopup.mark.entries : []

                delegate: ColumnLayout {
                    id: popupEntry
                    required property var modelData
                    required property int index
                    readonly property color accent: modelData.kind === "up"
                                                    ? applet.positiveColor
                                                    : (modelData.kind === "down"
                                                       ? applet.negativeColor
                                                       : applet.secondaryTextColor)
                    Layout.fillWidth: true
                    spacing: 4

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: popupEntry.index > 0 ? 4 : 0
                        height: popupEntry.index > 0 ? 1 : 0
                        color: analystRoot.applet.chartBaseColor
                        opacity: 0.6
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            width: 24; height: 24; radius: 12
                            Layout.alignment: Qt.AlignVCenter
                            color: Qt.rgba(popupEntry.accent.r, popupEntry.accent.g,
                                           popupEntry.accent.b, 0.16)
                            border.width: 1
                            border.color: popupEntry.accent
                            Text {
                                anchors.centerIn: parent
                                text: analystRoot.hoverGlyph(popupEntry.modelData)
                                color: popupEntry.accent
                                font.pixelSize: 10
                                font.bold: true
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Text {
                                    Layout.fillWidth: true
                                    text: popupEntry.modelData.firm
                                    color: analystRoot.popupText
                                    font.pixelSize: 11
                                    font.bold: true
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: analystRoot.entryDate(popupEntry.modelData)
                                    color: analystRoot.applet.secondaryTextColor
                                    font.pixelSize: 9
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: analystRoot.hoverCaption(popupEntry.modelData)
                                color: popupEntry.accent
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Text {
                                    visible: popupEntry.modelData.prior > 0
                                    text: analystRoot.money(popupEntry.modelData.prior)
                                    color: analystRoot.applet.secondaryTextColor
                                    font.pixelSize: 10
                                }
                                Text {
                                    visible: popupEntry.modelData.prior > 0
                                    text: "→"
                                    color: analystRoot.applet.secondaryTextColor
                                    font.pixelSize: 10
                                }
                                Text {
                                    text: analystRoot.money(popupEntry.modelData.target)
                                    color: popupEntry.accent
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: analystRoot.ratingText(popupEntry.modelData)
                                color: analystRoot.applet.secondaryTextColor
                                font.pixelSize: 9
                                opacity: 0.8
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
                    }
                }
            }

                Item {
                    id: entriesBar
                    visible: entriesFlick.overflows
                    Layout.preferredWidth: visible ? 8 : 0
                    Layout.minimumWidth: visible ? 8 : 0
                    Layout.maximumWidth: visible ? 8 : 0
                    Layout.fillHeight: true

                    Rectangle {
                        id: entriesHandle
                        x: 1
                        width: 6
                        radius: 3
                        color: analystRoot.popupText
                        opacity: 0.35
                        height: Math.max(24, entriesFlick.visibleArea.heightRatio * entriesBar.height)
                        y: entriesFlick.visibleArea.yPosition * (entriesBar.height - height)

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            property real lastY: 0
                            onPressed: lastY = mouse.y
                            onPositionChanged: if (pressed) {
                                var maxScroll = entriesFlick.contentHeight - entriesFlick.height;
                                var maxHandle = entriesBar.height - entriesHandle.height;
                                if (maxScroll > 0 && maxHandle > 0) {
                                    entriesFlick.contentY = Math.max(0, Math.min(maxScroll,
                                        entriesFlick.contentY + (mouse.y - lastY) / maxHandle * maxScroll));
                                    lastY = mouse.y;
                                }
                            }
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: detailsPopup.mark
                      && detailsPopup.mark.total > detailsPopup.mark.entries.length
                      ? i18n("… and %1 more",
                             detailsPopup.mark.total - detailsPopup.mark.entries.length)
                      : ""
                color: analystRoot.applet.secondaryTextColor
                font.pixelSize: 9
            }
        }
    }
}
