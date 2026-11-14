pragma ComponentBehavior: Bound
import QtQuick
import "../components"
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore

// The controls above the chart: the range and style buttons, the session note and the
// news header (source filters, updated line, refresh).
RowLayout {
    id: chartHeaderRow
    property var applet
    property var host
    property var newsPane
    readonly property real rangeButtonsWidth: chartRangeButtons.implicitWidth
    readonly property real styleButtonsWidth: chartStyleButtons.implicitWidth
    readonly property real rowSpacing: spacing
    // Bind to the settings, not to the children's visible: a child reads as
    // invisible while this row is hidden, which would keep the row hidden for good.
    // The news pane needs the row for its "Updated…" line and refresh button, but
    // merely enabling the news must not reserve an empty bar over the chart.
    visible: applet.showChartRangeButtons
             || applet.showChartStyleButtons
             || host.chartSessionNote !== ""
             || host.newsMode
    Layout.fillWidth: true
    Layout.topMargin: 6
    Layout.bottomMargin: 2
    Layout.preferredHeight: Math.max(
        applet.showChartRangeButtons ? chartRangeButtons.implicitHeight : 0,
        applet.showChartStyleButtons ? 18 : 0,
        host.chartSessionNote !== "" ? 14 : 0,
        host.newsMode ? 18 : 0)
    spacing: 6
    // A Row, not a Flow: the buttons stay on one row and its implicitWidth (the
    // one-row width) feeds the card's minimum width.
    Row {
        id: chartRangeButtons
        objectName: "chartRangeButtons"
        Layout.minimumWidth: implicitWidth
        Layout.alignment: Qt.AlignTop
        spacing: 3
        visible: applet.showChartRangeButtons
        // Stays laid out with the headlines (so the card's minimum width does
        // not change when switching) but is not shown and takes no clicks.
        opacity: host.newsMode ? 0 : 1
        enabled: !host.newsMode

        Repeater {
            model: ["1D", "5D", "1M", "6M", "YTD", "1Y", "5Y", "Max"]
            delegate: PillButton {
                id: rangeButton
                objectName: "chartRangeButton_" + modelData
                required property string modelData
                applet: chartHeaderRow.applet
                text: applet.chartRangeButtonLabel(modelData)
                selected: modelData === applet.effectiveChartRange
                onClicked: applet.setChartViewRange(modelData)
            }
        }
    }

    // Pushes the chart type selector to the right edge. The session note is
    // anchored inside this gap, so it never changes the card's minimum width.
    Item {
        id: chartHeaderGap
        Layout.fillWidth: true

        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: host.chartSessionNote
            visible: text !== "" && !host.newsMode
            color: applet.secondaryTextColor
            opacity: 0.8
            font.pixelSize: 9
            elide: Text.ElideRight
        }

        // News header. A plain child of the gap Item, placed over the whole
        // header row, so it never takes part in the row's layout.
        Item {
            visible: host.newsMode
            x: -chartHeaderGap.x
            y: -chartHeaderGap.y
            width: chartHeaderRow.width
            height: chartHeaderRow.height

            RowLayout {
                anchors.fill: parent
                spacing: 6

                // Source filters, in the same compact style as the chart
                // range buttons.
                Row {
                    id: newsSourceFilters
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 3

                    Repeater {
                        model: host.newsSourceButtons
                        delegate: PillButton {
                            id: newsSourceButton
                            required property var modelData
                            objectName: "newsSourceButton_" + (modelData.source === "" ? "all" : modelData.source)
                            applet: chartHeaderRow.applet
                            text: modelData.label
                            selected: !chartHeaderRow.host.newsFilterRelevant
                                      || chartHeaderRow.host.newsSourceFilter === modelData.source
                            hoverHighlight: true
                            onClicked: {
                                chartHeaderRow.host.newsSource = modelData.source;
                                chartHeaderRow.newsPane.positionViewAtBeginning();
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.alignment: Qt.AlignVCenter
                    horizontalAlignment: Text.AlignRight
                    text: host.newsHeaderText
                    textFormat: Text.PlainText
                    color: host.newsHeaderWarning ? applet.warningTextColor
                                                             : applet.secondaryTextColor
                    font.pixelSize: 9
                    elide: Text.ElideRight
                }

                PlasmaCore.ToolTipArea {
                    id: newsRefreshButton
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 18
                    mainText: i18n("Refresh news")

                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: newsRefreshMouse.containsMouse ? host.selectedTint : "transparent"
                    }
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 14
                        height: 14
                        source: "view-refresh"
                        isMask: true
                        color: applet.secondaryTextColor
                        opacity: host.newsEntry && host.newsEntry.pending ? 0.5 : 1
                    }
                    MouseArea {
                        id: newsRefreshMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: applet.requestNews(applet.singleTicker, true)
                    }
                }
            }
        }
    }
    // Chart type selector, same look as the range buttons. It writes the same
    // setting as the Chart & News page.
    Row {
        id: chartStyleButtons
        objectName: "chartStyleButtons"
        visible: applet.showChartStyleButtons
        opacity: host.newsMode ? 0 : 1
        enabled: !host.newsMode
        Layout.minimumWidth: implicitWidth
        Layout.alignment: Qt.AlignTop | Qt.AlignRight
        spacing: 3
        Repeater {
            model: [
                { style: 0, label: i18nc("@item:chart style", "Line") },
                { style: 1, label: i18nc("@item:chart style", "Candles") }
            ]
            delegate: PillButton {
                id: styleButton
                objectName: "chartStyleButton_" + modelData.style
                required property var modelData
                applet: chartHeaderRow.applet
                text: modelData.label
                selected: modelData.style === applet.chartStyle
                onClicked: applet.setChartStyle(modelData.style)
            }
        }
    }
