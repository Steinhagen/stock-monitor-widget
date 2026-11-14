import QtQuick
import "../controllers"
import "../platform"

// Non-visual composition of the widget: the typed configuration and the controllers
// that do not belong to a single view. main.qml creates this once and binds its own
// public properties to it, so the views keep their existing API.
Item {
    id: app
    visible: false

    property var configuration: null
    // Host palette, passed by main.qml from Kirigami.
    property color hostTextColor: "#ffffff"
    property color systemBackgroundColor: "#1a1a1a"
    property color systemDisabledTextColor: "#888888"

    AppConfig {
        id: configObject
        configuration: app.configuration
    }

    Theme {
        id: themeObject
        config: configObject
        hostTextColor: app.hostTextColor
        systemBackgroundColor: app.systemBackgroundColor
        systemDisabledTextColor: app.systemDisabledTextColor
    }

    FxController {
        id: fxController
        configuration: app.configuration
    }

    MarketController {
        id: marketController
        showExtendedHours: configObject.showExtendedHours
        keepExtendedAfterClose: configObject.keepExtendedAfterClose
        hideDecimals: configObject.hideDecimals
        formatPrices: configObject.formatPrices
    }

    readonly property AppConfig config: configObject
    readonly property Theme theme: themeObject
    readonly property FxController fx: fxController
    readonly property MarketController market: marketController
}
