import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../../domain/currencies.js" as Currency

// The add/edit lot form: ticker, shares, average cost, currency, purchase date and an
// optional details line. The page validates and saves; this dialog owns the fields.
Dialog {
    id: editor
    property bool editing: false
    property real hostWidth: 900
    property alias ticker: portfolioTickerField.text
    property alias shares: portfolioSharesSpin.value
    property alias costText: portfolioCostField.text
    property alias details: portfolioDetailsField.text
    property alias currencyIndex: lotCurrencyCombo.currentIndex
    property date purchaseDate: new Date()
    property string formError: ""

    signal saveRequested()
    signal closedByUser()

    function resetFields() {
        ticker = "";
        shares = 0;
        costText = "";
        currencyIndex = 0; // USD
        details = "";
        purchaseDate = new Date();
        formError = "";
    }

    function load(lot, index) {
        ticker = lot.ticker || "";
        shares = Number(lot.shares) || 0;
        costText = String(Number(lot.averageCost) || 0);
        currencyIndex = index;
        purchaseDate = lot.addedDate ? new Date(lot.addedDate) : new Date();
        details = lot.details || "";
        formError = "";
    }
    title: editor.editing ? i18n("Edit Lot") : i18n("Add Lot")
    modal: true
    width: Math.max(360, Math.min(540, editor.hostWidth - Kirigami.Units.largeSpacing * 2))
    closePolicy: Popup.CloseOnEscape
    onClosed: {
        resetFields();
        closedByUser();
    }

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.FormLayout {
            Layout.fillWidth: true

            TextField {
                id: portfolioTickerField
                Kirigami.FormData.label: i18n("Ticker:")
                placeholderText: i18n("e.g., AAPL")
                Layout.fillWidth: true
            }

            SpinBox {
                id: portfolioSharesSpin
                Kirigami.FormData.label: i18n("Shares:")
                from: 0
                to: 999999
                editable: true
            }

            TextField {
                id: portfolioCostField
                Kirigami.FormData.label: i18n("Average Cost:")
                placeholderText: "0.00"
                validator: RegularExpressionValidator { regularExpression: /^\d*[.,]?\d*$/ }
                Layout.fillWidth: true
            }

            ComboBox {
                id: lotCurrencyCombo
                Kirigami.FormData.label: i18n("Currency:")
                model: Currency.LABELS
                currentIndex: 0
                Layout.preferredWidth: Kirigami.Units.gridUnit * 18
            }

            Button {
                id: purchaseDateButton
                Kirigami.FormData.label: i18n("Purchase Date:")
                icon.name: "view-calendar"
                text: Qt.formatDate(editor.purchaseDate, "dd MMM yyyy")
                onClicked: datePopup.open()

                DatePicker {
                    id: datePopup
                    y: purchaseDateButton.height + Kirigami.Units.smallSpacing
                    selectedDate: editor.purchaseDate
                    onPicked: function(chosen) { editor.purchaseDate = chosen; }
                }
            }

            TextField {
                id: portfolioDetailsField
                Kirigami.FormData.label: i18n("Details (optional):")
                placeholderText: i18n("e.g., E*TRADE - 8122")
                Layout.fillWidth: true
            }
        }

        Label {
            Layout.fillWidth: true
            visible: editor.formError !== ""
            text: editor.formError
            color: Kirigami.Theme.negativeTextColor
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true

            Item { Layout.fillWidth: true }

            Button {
                text: i18n("Cancel")
                onClicked: editor.close()
            }

            Button {
                text: editor.editing ? i18n("Save Lot") : i18n("Add Lot")
                highlighted: true
                onClicked: editor.saveRequested()
            }
        }
    }
}
