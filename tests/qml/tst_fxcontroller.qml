import QtQuick
import QtTest

TestCase {
    name: "FxController"

    QtObject {
        id: fake
        property string exchangeRates: JSON.stringify({ base: "USD", rates: { USD: 1, EUR: 0.9, GBP: 0.8 } })
        property string exchangeRatesUpdated: "1700000000"
        property string exchangeRatesNext: "4102444800"
    }

    function make() {
        var component = Qt.createComponent(Qt.resolvedUrl("../../contents/ui/controllers/FxController.qml"));
        compare(component.status, Component.Ready, component.errorString());
        var controller = component.createObject(this, { "configuration": fake });
        verify(controller !== null);
        return controller;
    }

    function test_ratesAndConversion() {
        var fx = make();
        compare(fx.exchangeRates.EUR, 0.9);
        verify(Math.abs(fx.convertMoney(10, "USD", "EUR") - 9) < 1e-9);
        // Pence are converted to the major unit first.
        verify(Math.abs(fx.convertMoney(100, "GBp", "GBP") - 1) < 1e-9);
    }

    function test_notDue() {
        var fx = make();
        // The cache is fresh until its next-update timestamp.
        verify(!fx.exchangeRatesDue());
    }

    function test_saveWritesConfiguration() {
        var fx = make();
        verify(fx.saveExchangeRates("USD", { USD: 1, EUR: 0.95 }, 1700000001, 1700086401));
        var saved = JSON.parse(fake.exchangeRates);
        compare(saved.base, "USD");
        compare(saved.rates.EUR, 0.95);
        compare(fake.exchangeRatesUpdated, "1700000001");
        compare(fx.exchangeRates.EUR, 0.95);
    }
}
