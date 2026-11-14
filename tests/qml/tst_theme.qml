import QtQuick
import QtTest

TestCase {
    name: "Theme"

    QtObject {
        id: fakeConfig
        property int themePreset: 0
        property int themeColors: 0
        property string tickerColor: "#FFFFFF"
        property string priceColor: "#FFFFFF"
        property string positiveColor: "#4cd964"
        property string negativeColor: "#FF3B30"
        property int tickerOpacity: 100
        property int priceOpacity: 100
        property int bgOpacity: 100
    }

    function make(systemBackground, config) {
        var component = Qt.createComponent(Qt.resolvedUrl("../../contents/ui/platform/Theme.qml"));
        compare(component.status, Component.Ready, component.errorString());
        var theme = component.createObject(this, {
            "config": config || fakeConfig,
            "systemTextColor": "#eff0f1",
            "systemBackgroundColor": systemBackground,
            "systemDisabledTextColor": "#7f8c8d"
        });
        verify(theme !== null);
        return theme;
    }

    function test_contrastMath() {
        var theme = make("#1a1a1a");
        compare(theme.luminance(Qt.color("#000000")), 0);
        verify(Math.abs(theme.luminance(Qt.color("#ffffff")) - 1) < 1e-9);
        verify(Math.abs(theme.contrastRatio(Qt.color("#000000"), Qt.color("#ffffff")) - 21) < 0.01);
        // A colour that already reads well is returned unchanged.
        verify(Qt.colorEqual(theme.withContrast("#000000", "#ffffff"), "#000000"));
        // A weak green is darkened until it reaches 4.5:1.
        var adjusted = theme.withContrast("#4cd964", "#ffffff");
        verify(theme.contrastRatio(adjusted, Qt.color("#ffffff")) >= 4.5);
    }

    function test_applicationLight() {
        var theme = make("#ffffff");
        compare(theme.usesPlasmaSurface, false);
        compare(theme.appLightPalette, true);
        compare(theme.isLightTheme, true);
        // Default white ticker becomes black on the light card.
        verify(Qt.colorEqual(theme.tickerColor, "#000000"));
        verify(Qt.colorEqual(theme.priceColor, "#000000"));
        verify(Qt.colorEqual(theme.chartBaseColor, "#e0e0e0"));
        verify(Qt.colorEqual(theme.secondaryTextColor, "#555555"));
        verify(theme.contrastRatio(theme.positiveColor, Qt.color("#ffffff")) >= 4.5);
    }

    function test_applicationDark() {
        fakeConfig.themeColors = 1;
        var theme = make("#ffffff");
        compare(theme.appLightPalette, false);
        compare(theme.isLightTheme, false);
        verify(Qt.colorEqual(theme.tickerColor, "#FFFFFF"));
        verify(Qt.colorEqual(theme.chartBaseColor, "#333333"));
        // The card colour keeps the configured opacity.
        verify(Math.abs(theme.bgColor.a - 1) < 1e-6);
        fakeConfig.themeColors = 0;
    }

    function test_plasmaSurface() {
        fakeConfig.themePreset = 1;
        var theme = make("#ffffff");
        compare(theme.usesPlasmaSurface, true);
        compare(theme.appDrawnSurface, false);
        verify(Qt.colorEqual(theme.tickerColor, "#eff0f1"));
        verify(Qt.colorEqual(theme.bgColor, "transparent"));
        verify(Qt.colorEqual(theme.chartBaseColor, "#7f8c8d"));
        fakeConfig.themePreset = 0;
    }
}
