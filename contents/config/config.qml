import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("General")
        icon: "configure"
        source: "settings/pages/general.qml"
    }
    ConfigCategory {
        name: i18n("Symbols & Lists")
        icon: "view-list-text"
        source: "settings/pages/symbolsLists.qml"
    }
    ConfigCategory {
        name: i18n("Chart & News")
        icon: "office-chart-line"
        source: "settings/pages/chartNews.qml"
    }
    ConfigCategory {
        name: i18n("Panel view")
        icon: "panel-fit-width"
        source: "settings/pages/panelView.qml"
    }
    ConfigCategory {
        name: i18n("Portfolio Tracking")
        icon: "view-financial-account-investment"
        source: "settings/pages/portfolio.qml"
    }
    ConfigCategory {
        name: i18n("Appearance")
        icon: "preferences-desktop-color"
        source: "settings/pages/appearance.qml"
    }
    ConfigCategory {
        name: i18n("Mouse actions")
        icon: "input-mouse"
        source: "settings/pages/mouseActions.qml"
    }
    ConfigCategory {
        name: i18n("Import / Export")
        icon: "document-swap"
        source: "settings/pages/importExport.qml"
    }
}
