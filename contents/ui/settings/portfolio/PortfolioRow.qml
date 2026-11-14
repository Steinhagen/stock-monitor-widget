import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// One lot row in the portfolio table. The page owns the data and formatting; this
// component lays out the values and its edit\/remove menu.
ColumnLayout {
    id: row
    property var page
    property var lot
    property var market: page ? page.lotMarketData(lot) : null
    Layout.fillWidth: true
    spacing: 0

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.smallSpacing
        Layout.rightMargin: Kirigami.Units.smallSpacing
        Layout.topMargin: Kirigami.Units.smallSpacing
        Layout.bottomMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        ColumnLayout {
            Layout.preferredWidth: page.tableSymbolWidth
            Layout.minimumWidth: page.tableSymbolWidth
            Layout.maximumWidth: page.tableSymbolWidth
            clip: true
            spacing: 0

            Label {
                Layout.fillWidth: true
                text: lot.ticker || ""
                font.bold: true
                elide: Text.ElideRight
                clip: true
            }
            Label {
                Layout.fillWidth: true
                visible: text !== ""
                text: lot.details || ""
                color: Kirigami.Theme.disabledTextColor
                font.pixelSize: 9
                elide: Text.ElideRight
                clip: true
            }
        }
        Label {
            text: String(Number(lot.shares) || 0)
            Layout.preferredWidth: 45
            Layout.minimumWidth: 45
            Layout.maximumWidth: 45
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideLeft
        }
        Label {
            text: page.formatNumber(lot.averageCost || 0)
            Layout.preferredWidth: 65
            Layout.minimumWidth: 65
            Layout.maximumWidth: 65
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideLeft
        }
        Label {
            text: lot.currency || "USD"
            Layout.preferredWidth: 45
            Layout.minimumWidth: 45
            Layout.maximumWidth: 45
            elide: Text.ElideRight
        }
        Label {
            text: page.formatLotDate(lot.addedDate)
            Layout.preferredWidth: 100
            Layout.minimumWidth: 100
            Layout.maximumWidth: 100
            elide: Text.ElideRight
        }
        Label {
            text: page.lotValueText(lot)
            Layout.preferredWidth: page.tableValueWidth
            Layout.minimumWidth: page.tableValueWidth
            Layout.maximumWidth: page.tableValueWidth
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideLeft
            color: market ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
        }
        ColumnLayout {
            Layout.preferredWidth: page.tableGainWidth
            Layout.minimumWidth: page.tableGainWidth
            Layout.maximumWidth: page.tableGainWidth
            spacing: 0

            HoverHandler { id: gainHover }
            ToolTip.visible: gainHover.hovered
            ToolTip.text: market
                          ? i18n("Gain per share: %1",
                                 page.moneyText(market.currency, market.perShare))
                          : i18n("Quote unavailable.")

            Label {
                Layout.fillWidth: true
                text: page.lotGainText(lot)
                color: market
                       ? (market.gain >= 0 ? Kirigami.Theme.positiveTextColor
                                           : Kirigami.Theme.negativeTextColor)
                       : Kirigami.Theme.disabledTextColor
                horizontalAlignment: Text.AlignRight
                font.bold: true
                elide: Text.ElideLeft
            }

            Label {
                Layout.fillWidth: true
                visible: market !== null
                text: page.lotGainPercentText(lot)
                color: market
                       ? (market.gain >= 0 ? Kirigami.Theme.positiveTextColor
                                           : Kirigami.Theme.negativeTextColor)
                       : Kirigami.Theme.disabledTextColor
                horizontalAlignment: Text.AlignRight
                font.pixelSize: 9
                opacity: 0.8
                elide: Text.ElideLeft
            }
        }
        ToolButton {
            id: rowActionButton
            text: "⋮"
            Layout.preferredWidth: 45
            Layout.minimumWidth: 45
            Layout.maximumWidth: 45
            onClicked: rowMenu.popup()
            ToolTip.visible: hovered
            ToolTip.text: i18n("Lot actions")

            Menu {
                id: rowMenu
                MenuItem {
                    text: i18n("Edit")
                    onTriggered: page.editLot(lot._index)
                }
                MenuItem {
                    text: i18n("Remove")
                    onTriggered: page.removeLot(lot._index)
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                       Kirigami.Theme.textColor.b, 0.09)
    }
}
