import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// The portfolio summary row: invested, current value, total gain and today. The page
// passes the computed totals and its money/percent formatters in.
Rectangle {
    id: totalsRoot
    property var totals: ({})
    property bool compactLayout: false
    property var moneyText: function(value) { return value === null ? "—" : String(value); }
    property var percentText: function(value) { return value === null ? "" : Number(value).toFixed(2) + "%"; }
    Layout.fillWidth: true
    Layout.preferredHeight: totalsRow.implicitHeight + Kirigami.Units.largeSpacing * 2
    color: Kirigami.Theme.alternateBackgroundColor
    radius: Kirigami.Units.smallSpacing
    border.width: 1
    border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                          Kirigami.Theme.textColor.b, 0.16)

    GridLayout {
        id: totalsRow
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        columns: compactLayout ? 2 : 4
        columnSpacing: Kirigami.Units.largeSpacing
        rowSpacing: Kirigami.Units.smallSpacing

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Label {
                text: i18n("Invested")
                color: Kirigami.Theme.disabledTextColor
                font.pixelSize: 9
            }
            Label {
                text: moneyText(totals.cost)
                font.pixelSize: 15
                font.bold: true
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Label {
                text: i18n("Current value")
                color: Kirigami.Theme.disabledTextColor
                font.pixelSize: 9
            }
            Label {
                text: moneyText(totals.value)
                font.pixelSize: 15
                font.bold: true
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Label {
                text: i18n("Total gain")
                color: Kirigami.Theme.disabledTextColor
                font.pixelSize: 9
            }
            Label {
                text: moneyText(totals.gain)
                color: totals.gain === null
                       ? Kirigami.Theme.disabledTextColor
                       : (totals.gain >= 0 ? Kirigami.Theme.positiveTextColor
                                                : Kirigami.Theme.negativeTextColor)
                font.pixelSize: 15
                font.bold: true
            }
            Label {
                text: percentText(totals.gainPercent)
                visible: totals.gain !== null
                color: totals.gain !== null && totals.gain >= 0
                       ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
                font.pixelSize: 9
                opacity: 0.8
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Label {
                text: i18n("Today")
                color: Kirigami.Theme.disabledTextColor
                font.pixelSize: 9
            }
            Label {
                text: moneyText(totals.day)
                color: totals.day === null
                       ? Kirigami.Theme.disabledTextColor
                       : (totals.day >= 0 ? Kirigami.Theme.positiveTextColor
                                               : Kirigami.Theme.negativeTextColor)
                font.pixelSize: 15
                font.bold: true
            }
            Label {
                text: percentText(totals.dayPercent)
                visible: totals.day !== null
                color: totals.day !== null && totals.day >= 0
                       ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
                font.pixelSize: 9
                opacity: 0.8
            }
        }
    }
}
