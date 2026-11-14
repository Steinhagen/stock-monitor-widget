import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Month-grid date picker for the purchase date. The parent owns the current date and
// updates it from the picked signal.
Popup {
    id: datePopup
    property date selectedDate: new Date()
    signal picked(var chosen)

    readonly property real cellSize: Kirigami.Units.gridUnit * 2
    property int shownMonth: selectedDate.getMonth()
    property int shownYear: selectedDate.getFullYear()

    padding: Kirigami.Units.largeSpacing
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    onAboutToShow: {
        shownMonth = selectedDate.getMonth();
        shownYear = selectedDate.getFullYear();
        syncHeader();
    }

    function syncHeader() {
        monthCombo.currentIndex = shownMonth;
        yearSpin.value = shownYear;
    }

    function shiftMonth(delta) {
        var d = new Date(shownYear, shownMonth + delta, 1);
        shownMonth = d.getMonth();
        shownYear = d.getFullYear();
        syncHeader();
    }

    function pick(d) {
        datePopup.picked(d);
        close();
    }

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true

            ToolButton {
                icon.name: "go-previous"
                onClicked: datePopup.shiftMonth(-1)
            }
            ComboBox {
                id: monthCombo
                Layout.fillWidth: true
                model: Array.from({ length: 12 }, (_, i) => Qt.locale().monthName(i, Locale.LongFormat))
                currentIndex: datePopup.shownMonth
                onActivated: (index) => datePopup.shownMonth = index
            }
            SpinBox {
                id: yearSpin
                from: 1900
                to: 2100
                editable: true
                value: datePopup.shownYear
                textFromValue: (v) => String(v)
                valueFromText: (t) => parseInt(t) || datePopup.shownYear
                onValueModified: datePopup.shownYear = value
            }
            ToolButton {
                icon.name: "go-next"
                onClicked: datePopup.shiftMonth(1)
            }
        }

        DayOfWeekRow {
            locale: dateGrid.locale
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: datePopup.cellSize * 7
            Layout.preferredHeight: datePopup.cellSize * 0.8
            delegate: Label {
                text: model.shortName
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 11
                opacity: 0.7
            }
        }

        MonthGrid {
            id: dateGrid
            month: datePopup.shownMonth
            year: datePopup.shownYear
            locale: Qt.locale()
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: datePopup.cellSize * 7
            Layout.preferredHeight: datePopup.cellSize * 0.8 * 6

            delegate: Label {
                readonly property bool isSelected: model.date.getFullYear() === selectedDate.getFullYear()
                                                   && model.date.getMonth() === selectedDate.getMonth()
                                                   && model.date.getDate() === selectedDate.getDate()
                text: model.day
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                opacity: model.month === dateGrid.month ? 1.0 : 0.3
                font.bold: isSelected || model.today
                color: isSelected ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor

                background: Rectangle {
                    radius: Kirigami.Units.smallSpacing
                    color: isSelected ? Kirigami.Theme.highlightColor : "transparent"
                    border.width: model.today && !isSelected ? 1 : 0
                    border.color: Kirigami.Theme.highlightColor
                }
            }

            onClicked: (date) => datePopup.pick(date)
        }

        Button {
            Layout.alignment: Qt.AlignHCenter
            text: i18n("Today")
            onClicked: datePopup.pick(new Date())
        }
    }
}
