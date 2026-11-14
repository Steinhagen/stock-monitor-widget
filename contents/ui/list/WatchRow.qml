import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../components"
import "../core/Text.js" as TextUtil

// One watchlist row: name/badge, price, the pre/post line and the per-lot summary.
// The list supplies the row object and width; the delayed-open state stays in the list.
Item {
    id: rowRoot
    property var applet
    property var row
    property int rowIndex: 0
    property int rowCount: 0
    property real rowWidth: 0
    property var requestPendingOpen: function(ticker) {}
    property var cancelPendingOpen: function() {}
    width: rowRoot.rowWidth
    // The position for this ticker: all its lots added up, or null when there are none (or
    // the feature is off). Computed here, not stored as a model role, so it stays reactive
    // to rowRoot.applet.portfolioData and the live price.
    property var rowSummary: (rowRoot.applet.showPortfolioMode && rowRoot.row.currentRaw > 0)
                             ? rowRoot.applet.getPortfolioSummary(rowRoot.row.ticker, rowRoot.applet.portfolioData, rowRoot.row.currentRaw, rowRoot.row.prevClose, rowRoot.row.currency)
                             : null
    // Base row, plus one summary line when the ticker has a position.
    height: 60 + (rowRoot.rowSummary !== null ? 20 : 0)
    property string rowCurrencySym: rowRoot.row.currencySym
    // Pre-market / after-hours quote for this ticker. Only present while that
    // session is the latest one, i.e. when the regular market is closed
    // (undefined otherwise).
    property var rowExt: rowRoot.applet.extendedQuote(rowRoot.row.ticker)
    // True while the market is closed, with or without a kept extended quote.
    property bool rowClosed: rowRoot.applet.showExtendedHours
                             && rowRoot.applet.isMarketClosedFor(rowRoot.row.ticker)
    // The market is in a pre-market/after-hours session but Yahoo has no quote for
    // it yet (thin extended trading, or the feed has not published it). Say so
    // instead of leaving the second line empty, which looked like a missing state.
    property string rowNoQuote: {
        if (rowRoot.rowExt || !rowRoot.applet.showExtendedHours) return "";
        var status = rowRoot.applet.marketStatusFor(rowRoot.row.ticker);
        if (status === "pre") return i18n("No pre-market quote");
        if (status === "post") return i18n("No after-hours quote");
        return "";
    }
    // Widths used to cap the name so the badge follows it without taking room
    // from the price. TextMetrics is available as soon as the delegate is built,
    // unlike the width of a Text created later in the layout.
    TextMetrics {
        id: listPriceMetrics
        font.pixelSize: 14
        text: rowRoot.row.price
    }
    TextMetrics {
        id: listExchangeMetrics
        font.pixelSize: 9
        font.bold: true
        text: rowRoot.applet.exchangeBadge(rowRoot.row.ticker, rowRoot.row.exchange)
    }
    TextMetrics {
        id: listArrowMetrics
        font.pixelSize: 10
        text: "▲"
    }

    MouseArea {
        anchors.fill: parent
        z: 100 // Above the row layout
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.MiddleButton) {
                rowRoot.cancelPendingOpen();
                if (rowRoot.applet.performMiddleClick(rowRoot.row.ticker)) {
                    rowRoot.opacity = 0.4;
                    timerListFlicker.restart();
                }
            } else if (mouse.button === Qt.LeftButton) {
                // Delay the optional "open" action briefly so a double click does
                // not open the quote page twice.
                if (rowRoot.applet.mouseRowLeftAction === "open") {
                    rowRoot.requestPendingOpen(rowRoot.row.ticker);
                } else {
                    rowRoot.cancelPendingOpen();
                    rowRoot.applet.performRowLeftClick(rowRoot.row.ticker);
                }
            } else if (mouse.button === Qt.RightButton) {
                rowRoot.cancelPendingOpen();
                rowMenu.popup();
            }
        }
        onDoubleClicked: (mouse) => {
            if (mouse.button !== Qt.LeftButton) return;
            rowRoot.cancelPendingOpen();
            // A double click opens once, whichever of the two configured actions
            // is responsible for it.
            if (rowRoot.applet.mouseDoubleClickAction === "open"
                || rowRoot.applet.mouseRowLeftAction === "open")
                rowRoot.applet.openYahooQuote(rowRoot.row.ticker);
        }

        Menu {
            id: rowMenu

            MenuItem {
                text: i18n("Open on Yahoo Finance")
                onTriggered: rowRoot.applet.openYahooQuote(rowRoot.row.ticker)
            }
            MenuItem {
                text: i18n("Set as panel stock")
                onTriggered: rowRoot.applet.selectTicker(rowRoot.row.ticker)
            }
            MenuSeparator {}
            MenuItem {
                text: i18n("Refresh")
                onTriggered: rowRoot.applet.refreshData()
            }
        }

        Timer {
            id: timerListFlicker
            interval: 300
            onTriggered: rowRoot.opacity = 1.0;
        }
    }

    // Outer ColumnLayout so the per-lot lines stack *below* the name/price row instead
    // of inside it — keeping them inside the row's own ColumnLayout would grow that
    // column's content height and, since it's independently vertically-centered, pull
    // the price up out of line with the ticker name whenever a ticker had lots.
    ColumnLayout {
        anchors.fill: parent
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            spacing: 10
            // The two lines are separate RowLayouts, so each one sizes on its own:
            // the wide change badge on the second line must not take width away from
            // the name on the first line (they used to share two columns).
            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                // Line 1: arrow, name with its exchange badge, a spacer and the
                // price. The badge follows the name instead of sitting at the
                // right edge; the spacer keeps the price right-aligned.
                RowLayout {
                    id: listLineRow
                    Layout.fillWidth: true
                    spacing: 4

                    readonly property real badgeWidth: listExchangeBadge.visible
                        ? Math.ceil(listExchangeMetrics.advanceWidth)
                          + Kirigami.Units.smallSpacing * 2 : 0
                    // Room left for the name after the arrow, badge, price and
                    // the gaps between them. None of these depends on the name
                    // width, so capping the name here cannot loop.
                    readonly property real nameMaxWidth: Math.max(0, width
                        - Math.max(10, Math.ceil(listArrowMetrics.advanceWidth))
                        - (Math.ceil(listPriceMetrics.advanceWidth) + 2)
                        - (listExchangeBadge.visible ? badgeWidth + 4 : 0)
                        - spacing * 3)

                    Text {
                        id: listArrowText
                        text: rowRoot.row.isPos ? "▲" : "▼"
                        color: rowRoot.row.isPos ? rowRoot.applet.positiveColor : rowRoot.applet.negativeColor
                        font.pixelSize: 10
                    }
                    Row {
                        id: listNameGroup
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 4
                        Text {
                            id: listNameText
                            FontMetrics { id: listNameMetrics; font: listNameText.font }
                            // Use the row width available to the name, not this Text.width:
                            // width depends on implicitWidth, which depends on the text.
                            text: rowRoot.applet.showNameAndTicker
                                  ? rowRoot.applet.fitNameAndTicker(rowRoot.row.name, rowRoot.applet.displayTicker(rowRoot.row.ticker), listLineRow.nameMaxWidth, listNameMetrics)
                                  : (rowRoot.applet.swapNameAndTicker ? rowRoot.row.name : rowRoot.applet.displayTicker(rowRoot.row.ticker))
                            // The name keeps its natural width so the badge
                            // follows it, but never takes room from the price.
                            width: Math.min(implicitWidth, listLineRow.nameMaxWidth)
                            color: rowRoot.applet.tickerColor
                            opacity: rowRoot.applet.tickerOpacity / 100.0
                            font.pixelSize: 14
                            elide: Text.ElideRight
                        }
                        // Short exchange label, e.g. BVB for BRD.RO. Only shown in
                        // the "symbol and exchange" mode and only when the Yahoo
                        // ticker actually had an exchange suffix.
                        Rectangle {
                            id: listExchangeBadge
                            readonly property string label: rowRoot.applet.exchangeBadge(rowRoot.row.ticker, rowRoot.row.exchange)
                            visible: label !== ""
                            width: listLineRow.badgeWidth
                            height: listExchangeText.implicitHeight + Kirigami.Units.smallSpacing / 2
                            y: (listNameGroup.height - height) / 2
                            radius: 3
                            color: Qt.rgba(rowRoot.applet.secondaryTextColor.r, rowRoot.applet.secondaryTextColor.g,
                                           rowRoot.applet.secondaryTextColor.b, 0.12)
                            border.width: 1
                            border.color: Qt.rgba(rowRoot.applet.secondaryTextColor.r, rowRoot.applet.secondaryTextColor.g,
                                                  rowRoot.applet.secondaryTextColor.b, 0.35)

                            Text {
                                id: listExchangeText
                                anchors.centerIn: parent
                                text: listExchangeBadge.label
                                color: rowRoot.applet.secondaryTextColor
                                font.pixelSize: 9
                                font.bold: true
                                opacity: 0.85
                            }
                            HoverHandler { id: listExchangeHover }
                            ToolTip.visible: listExchangeHover.hovered
                            ToolTip.text: rowRoot.row.exchangeFull || rowRoot.row.exchange
                        }
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        id: listPriceText
                        text: rowRoot.row.price
                        color: rowRoot.applet.priceColor
                        opacity: rowRoot.applet.priceOpacity / 100.0
                        font.pixelSize: 14
                        Layout.alignment: Qt.AlignRight
                        Layout.minimumWidth: implicitWidth
                    }
                }

                // Line 2: secondary text (elided when too long), change badge.
                // While the market is closed and the ticker has a pre-market / after-hours
                // quote, that quote takes the place of the secondary text, so the row keeps
                // its two lines.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Text {
                        id: secondLine
                        readonly property var ext: rowRoot.rowExt

                        FontMetrics { id: secondLineMetrics; font.pixelSize: 10; font.bold: true }

                        // Longest wording that fits in `avail` pixels, richest first:
                        // "After-Hours · closed    $342.65    -0.28 (-0.08%)" ... down to just the price.
                        function extText(avail) {
                            var e = secondLine.ext;
                            if (!e) return "";
                            var closedSuffix = rowRoot.rowClosed
                                               ? "&nbsp;·&nbsp;" + i18nc("@item:market status", "closed") : "";
                            // The caption comes from the translation, so escape it before it is
                            // embedded in the rich text; the &nbsp; gap is added afterwards.
                            var fullLabel = TextUtil.escapeHtml(e.label) + closedSuffix;
                            var shortLabel = TextUtil.escapeHtml(e.kind === "pre"
                                                                 ? i18nc("@item:short stock market session", "Pre")
                                                                 : i18nc("@item:short stock market session", "After")) + closedSuffix;
                            var tiers = [
                                [fullLabel, e.price, e.change + " (" + e.pct + ")"],
                                [shortLabel, e.price, e.pct],
                                [null, e.price, e.pct],
                                [null, e.price, null]
                            ];
                            // Wide, non-collapsible gaps between the parts, matching the
                            // spacing the portfolio line below uses instead of the single
                            // space a plain text would give.
                            var gap = "&nbsp;&nbsp;&nbsp;&nbsp;";
                            var plainGap = "    ";
                            var plain = function(s) { return String(s).replace(/&nbsp;/g, " "); };
                            var pick = tiers[tiers.length - 1];
                            for (var i = 0; i < tiers.length; i++) {
                                var plainText = tiers[i].filter(function(p) { return p !== null; })
                                                       .map(plain).join(plainGap);
                                if (secondLineMetrics.advanceWidth(plainText) <= avail) { pick = tiers[i]; break; }
                            }
                            var accent = e.isPos ? rowRoot.applet.positiveColor : rowRoot.applet.negativeColor;
                            var out = "";
                            if (pick[0] !== null) out += '<font color="' + rowRoot.applet.secondaryTextColor + '">' + pick[0] + '</font>' + gap;
                            // With no change shown, colour the price itself so the direction is still visible.
                            out += '<font color="' + (pick[2] === null ? accent : rowRoot.applet.priceColor) + '"><b>' + pick[1] + '</b></font>';
                            if (pick[2] !== null) out += gap + '<font color="' + accent + '">' + pick[2] + '</font>';
                            return out;
                        }

                        textFormat: ext ? Text.StyledText : Text.PlainText
                        // Line 1 already carries the company name when name and ticker are shown together.
                        function plainText() {
                            if (rowRoot.applet.showNameAndTicker) {
                                if (rowRoot.rowClosed) return i18n("Market closed");
                                return rowRoot.rowNoQuote;
                            }
                            var name = rowRoot.applet.swapNameAndTicker
                                       ? rowRoot.applet.displayTicker(rowRoot.row.ticker) : rowRoot.row.name;
                            if (rowRoot.rowClosed) return i18n("Market closed") + " · " + name;
                            if (rowRoot.rowNoQuote !== "") return rowRoot.rowNoQuote + " · " + name;
                            return name;
                        }
                        text: ext ? extText(width) : plainText()
                        color: rowRoot.applet.secondaryTextColor
                        font.pixelSize: 10
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        // Width comes only from the space the badge leaves, never from the
                        // text, so choosing the wording by width cannot loop.
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                    }
                    Rectangle {
                        radius: 4
                        // Background: translucent tint of the color for theme independence
                        color: rowRoot.row.isPos
                            ? Qt.rgba(rowRoot.applet.positiveColor.r, rowRoot.applet.positiveColor.g, rowRoot.applet.positiveColor.b, 0.15)
                            : Qt.rgba(rowRoot.applet.negativeColor.r, rowRoot.applet.negativeColor.g, rowRoot.applet.negativeColor.b, 0.15)
                        border.color: rowRoot.row.isPos ? rowRoot.applet.positiveColor : rowRoot.applet.negativeColor
                        border.width: 1
                        Layout.preferredWidth: pctTextL.implicitWidth + (Kirigami.Units.smallSpacing * 2)
                        Layout.minimumWidth: Layout.preferredWidth
                        Layout.preferredHeight: pctTextL.implicitHeight + (Kirigami.Units.smallSpacing / 2)
                        Layout.alignment: Qt.AlignRight

                        Text {
                            id: pctTextL
                            anchors.centerIn: parent
                            text: rowRoot.row.change + " (" + rowRoot.row.pct + ")"
                            color: rowRoot.row.isPos ? rowRoot.applet.positiveColor : rowRoot.applet.negativeColor
                            font.pixelSize: 11
                            font.weight: Font.Black
                        }
                    }
                }
            }
        }

        // One line for the whole position of this ticker, below the core row so it never
        // affects that row's own alignment.
        PositionLine {
            Layout.fillWidth: true
            // The core row above is vertically centred in 60 px, so pull this line up
            // towards its content and leave room before the separator.
            Layout.topMargin: -4
            // The width comes only from the row, never from the line itself, so choosing
            // the parts by width cannot loop.
            Layout.minimumWidth: 0
            Layout.preferredWidth: 0
            applet: rowRoot.applet
            summary: rowRoot.rowSummary
            sym: rowRoot.rowCurrencySym
        }
    }
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: rowRoot.applet.chartBaseColor
        visible: rowRoot.rowIndex < rowRoot.rowCount - 1
    }
}
