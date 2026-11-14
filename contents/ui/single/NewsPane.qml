import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore

// The headline list, its rows and the context menu. The parent owns the header
// controls and decides which items are visible; this component only renders them.
Item {
    id: pane

    property var applet
    property bool active: false
    property var items: []
    property string stateText: ""
    property string moreSource: "Yahoo"
    property var sources: []

    function positionAtBeginning() {
        newsList.positionViewAtBeginning();
    }

                // --- News pane: the headline list replaces the chart. ---
                // Right click on the empty pane (loading or no headlines) opens the menu too.
                MouseArea {
                    anchors.fill: parent
                    visible: pane.active
                    acceptedButtons: Qt.RightButton
                    onClicked: newsMenu.popup()
                }

                ListView {
                    id: newsList
                    anchors.fill: parent
                    visible: pane.active && pane.items.length > 0
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: pane.items
                    // Shown whenever the headlines overflow (not only while scrolling), so
                    // the user can tell there is more below the visible rows.
                    //
                    // Do not bind this to contentHeight: a wrapped headline is taller when
                    // the rows are narrower, so overflow -> rowWidth -> contentHeight ->
                    // overflow is a binding loop. Track it imperatively instead. It settles
                    // because widening the rows can only make the content shorter.
                    property bool overflows: false
                    function refreshOverflow() {
                        if (height <= 0) return;
                        if (!overflows && contentHeight > height + 1) overflows = true;
                        else if (overflows && contentHeight <= height) overflows = false;
                    }
                    onContentHeightChanged: refreshOverflow()
                    onHeightChanged: refreshOverflow()
                    // Rows and footer end left of the scrollbar, so it never covers a
                    // separator, the hover tint or the text.
                    readonly property real rowWidth: width - (overflows ? newsScrollBar.width + 4 : 0)
                    ScrollBar.vertical: ScrollBar {
                        id: newsScrollBar
                        policy: newsList.overflows ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                    }

                    delegate: PlasmaCore.ToolTipArea {
                        id: newsRow
                        required property var modelData
                        required property int index
                        width: newsList.rowWidth
                        height: newsRowColumn.implicitHeight + 13
                        // The full title, only when the row had to shorten it.
                        mainText: newsRow.modelData.title
                        active: newsTitle.truncated

                        Rectangle {
                            anchors.fill: parent
                            anchors.bottomMargin: 1
                            radius: 4
                            visible: newsRowMouse.containsMouse
                            color: Qt.rgba(pane.applet.tickerColor.r,
                                           pane.applet.tickerColor.g,
                                           pane.applet.tickerColor.b, 0.06)
                        }

                        ColumnLayout {
                            id: newsRowColumn
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: -0.5
                            spacing: 3

                            // Plain text: a headline is never rendered as markup.
                            Text {
                                id: newsTitle
                                Layout.fillWidth: true
                                text: newsRow.modelData.title
                                textFormat: Text.PlainText
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                color: pane.applet.tickerColor
                                font.pixelSize: 11
                            }
                            Text {
                                Layout.fillWidth: true
                                readonly property string age: pane.applet.newsAge(newsRow.modelData.time)
                                text: newsRow.modelData.publisher !== ""
                                      ? (age !== "" ? newsRow.modelData.publisher + " · " + age : newsRow.modelData.publisher)
                                      : age
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                color: pane.applet.secondaryTextColor
                                font.pixelSize: 9
                            }
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 1
                            color: pane.applet.chartBaseColor
                        }

                        MouseArea {
                            id: newsRowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) newsMenu.popup();
                                else pane.applet.openNewsLink(newsRow.modelData.link);
                            }
                        }
                    }

                    footer: Item {
                        width: newsList.rowWidth
                        height: 24

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: (pane.moreSource === "BVB" ? i18n("More on BVB")
                                   : pane.moreSource === "Google" ? i18n("More on Google")
                                   : i18n("More on Yahoo Finance")) + " ›"
                            textFormat: Text.PlainText
                            color: pane.applet.secondaryTextColor
                            font.pixelSize: 9
                            font.bold: true

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (pane.moreSource === "BVB")
                                        pane.applet.openBvbNews(pane.applet.singleTicker);
                                    else if (pane.moreSource === "Google")
                                        pane.applet.openGoogleNews(pane.applet.singleTicker);
                                    else
                                        pane.applet.openYahooNews(pane.applet.singleTicker);
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 24
                    visible: pane.active && pane.stateText !== ""
                    text: pane.stateText
                    textFormat: Text.PlainText
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    color: pane.applet.secondaryTextColor
                    font.pixelSize: 10
                }

                Menu {
                    id: newsMenu

                    MenuItem {
                        text: i18n("Open on Yahoo Finance")
                        onTriggered: pane.applet.openYahooNews(pane.applet.singleTicker)
                    }
                    MenuItem {
                        text: i18n("Open on BVB")
                        visible: pane.sources.indexOf("BVB") >= 0
                        onTriggered: pane.applet.openBvbNews(pane.applet.singleTicker)
                    }
                    MenuItem {
                        text: i18n("Open on Google")
                        visible: pane.sources.indexOf("Google") >= 0
                        onTriggered: pane.applet.openGoogleNews(pane.applet.singleTicker)
                    }
                    MenuItem {
                        text: i18n("Refresh news")
                        onTriggered: pane.applet.requestNews(pane.applet.singleTicker, true)
                    }
                }
}
