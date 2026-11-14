import QtQuick

// The colour system: the Application/Plasma preset, the light/dark palette and the
// contrast helpers. The system palette is injected by the applet, so this component
// stays free of Plasma/Kirigami and can be tested with plain values.
QtObject {
    id: theme

    // Typed configuration (AppConfig) and the host palette.
    property var config: null
    property color hostTextColor: "#ffffff"
    property color systemBackgroundColor: "#1a1a1a"
    property color hostDisabledTextColor: "#888888"
    // Edit mode can hand the widget a text colour that matches the background (Plasma
    // switches the scheme for the toolbox); fall back to readable black or white.
    readonly property color systemTextColor: readableText(hostTextColor, surfaceBackground)

    // The disabled/secondary colour can come from the same mismatched palette.
    readonly property color systemDisabledTextColor: readableSecondary(hostDisabledTextColor, surfaceBackground, systemTextColor)


    // Preset: 0 = Application, 1 = Plasma. -1 is the "not migrated yet" sentinel.
    readonly property int themePreset: config && config.themePreset === 0 ? 0 : 1
    // Colors: 0 = Light, 1 = Dark, 2 = System (Application only).
    readonly property int themeColors: !config ? 2
                                      : (config.themeColors === 0 ? 0
                                         : (config.themeColors === 1 ? 1 : 2))

    readonly property bool usesPlasmaSurface: themePreset === 1
    readonly property bool appDrawnSurface: themePreset === 0
    // The host palette (SystemPalette) follows the colour scheme, so the injected
    // background updates when the system theme changes.
    readonly property bool systemLightColors: systemBackgroundColor.hslLightness > 0.5
    readonly property color surfaceBackground: systemBackgroundColor
    readonly property bool surfaceLightColors: surfaceBackground.hslLightness > 0.5
    readonly property bool appLightPalette: themeColors === 0
                                            || (themeColors === 2 && systemLightColors)
    // Effective lightness of the surface on screen; the chart and the views use it for
    // their own light/dark details.
    readonly property bool isLightTheme: usesPlasmaSurface ? surfaceLightColors : appLightPalette

    // The panel indicator always uses the panel's own palette, independent of the
    // widget theme.
    // The panel host can report a broken palette (black on black when no Kirigami
    // theme is inherited); then trust the configured Light/Dark choice instead.
    readonly property bool panelPaletteValid: contrastRatio(hostTextColor, systemBackgroundColor) >= 2
    readonly property bool panelLightFallback: themeColors === 0 ? true : (themeColors === 1 ? false : true)
    readonly property color panelBackground: panelPaletteValid ? systemBackgroundColor
                                              : (panelLightFallback ? "#ffffff" : "#1a1a1a")
    readonly property color panelTextColor: panelPaletteValid
                                            ? readableText(hostTextColor, panelBackground)
                                            : (panelLightFallback ? "#000000" : "#ffffff")
    readonly property color panelPositiveColor: withContrast(config ? config.positiveColor : "#4cd964", panelBackground)
    readonly property color panelNegativeColor: withContrast(config ? config.negativeColor : "#FF3B30", panelBackground)

    // Colour the gain/loss text is measured against: the cards' base colour, otherwise
    // the Plasma surface. The configured gain/loss colours are adjusted only as far as
    // needed to stay readable (WCAG AA, 4.5:1).
    readonly property color contrastBackground: usesPlasmaSurface
        ? surfaceBackground
        : (appLightPalette ? "#ffffff" : "#1a1a1a")
    readonly property color positiveColor: withContrast(config ? config.positiveColor : "#4cd964", contrastBackground, 5.0)
    readonly property color negativeColor: withContrast(config ? config.negativeColor : "#FF3B30", contrastBackground, 5.0)

    readonly property color tickerColor: getThemeColor("ticker")
    readonly property color priceColor: getThemeColor("price")
    readonly property int tickerOpacity: config ? config.tickerOpacity : 100
    readonly property int priceOpacity: config ? config.priceOpacity : 100
    readonly property int bgOpacity: config ? config.bgOpacity : 100

    // Amber that stays readable on light and dark cards, used while data is cached.
    readonly property color warningTextColor: isLightTheme ? "#8a5a00" : "#e0b25a"
    readonly property color bgColor: getThemeColor("background")
    readonly property color chartBaseColor: getThemeColor("chart")
    readonly property color secondaryTextColor: getThemeColor("text")

    // WCAG relative luminance of a colour and the contrast ratio between two colours.
    function luminance(c) {
        function channel(v) { return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); }
        return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
    }
    function contrastRatio(a, b) {
        var la = luminance(a), lb = luminance(b);
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
    }

    function readableText(color, bg) {
        if (contrastRatio(color, bg) >= 3) return color;
        return bg.hslLightness > 0.5 ? "#000000" : "#ffffff";
    }

    function blend(fg, bg, amount) {
        return Qt.rgba(fg.r * amount + bg.r * (1 - amount),
                       fg.g * amount + bg.g * (1 - amount),
                       fg.b * amount + bg.b * (1 - amount));
    }

    function readableSecondary(color, bg, textColor) {
        if (contrastRatio(color, bg) >= 2.5) return color;
        return Qt.rgba(textColor.r, textColor.g, textColor.b, 0.65);
    }

    // Returns the colour unchanged when it already reads well on bg. Otherwise keeps the
    // hue and saturation and moves only the lightness until the contrast is enough.
    function withContrast(color, bg, minimum) {
        var target = minimum || 4.5;
        var c = Qt.color(color);
        var b = Qt.color(bg);
        if (contrastRatio(c, b) >= target) return c;
        var darken = luminance(b) > 0.18;
        var hue = c.hslHue < 0 ? 0 : c.hslHue;
        var l = c.hslLightness;
        var out = c;
        for (var i = 0; i < 100; i++) {
            l += darken ? -0.01 : 0.01;
            if (l < 0 || l > 1) break;
            out = Qt.hsla(hue, c.hslSaturation, l, 1);
            if (contrastRatio(out, b) >= target) break;
        }
        return out;
    }

    function getThemeColor(what) {
        if (what === "ticker") {
            if (usesPlasmaSurface) return systemTextColor;
            return Qt.colorEqual(config ? config.tickerColor : "#ffffff", "#ffffff") && appLightPalette
                   ? "#000000" : (config ? config.tickerColor : "#ffffff");
        } else if (what === "price") {
            if (usesPlasmaSurface) return systemTextColor;
            return Qt.colorEqual(config ? config.priceColor : "#ffffff", "#ffffff") && appLightPalette
                   ? "#000000" : (config ? config.priceColor : "#ffffff");
        } else if (what === "background") {
            // Plasma paints the surface behind the views; the Application preset draws
            // its own forced light/dark card.
            if (usesPlasmaSurface) return "transparent";
            var c = Qt.color(appLightPalette ? "#ffffff" : "#1a1a1a");
            return Qt.rgba(c.r, c.g, c.b, bgOpacity / 100);
        } else if (what === "chart") {
            if (usesPlasmaSurface) return systemDisabledTextColor;
            return appLightPalette ? "#e0e0e0" : "#333333";
        } else if (what === "text") {
            if (usesPlasmaSurface)
                return blend(systemTextColor, surfaceBackground, 0.8);
            return appLightPalette ? "#555555" : "#888888";
        }
        return "";
    }
}
