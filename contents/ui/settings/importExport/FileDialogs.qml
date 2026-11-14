import QtQuick
import QtQuick.Dialogs as QtDialogs

// The save/open backup file dialogs. The page supplies the starting folder and file
// name and handles the chosen URL.
Item {
    id: dialogs
    property string defaultFolder: ""
    property url defaultFile

    signal exportRequested(var fileUrl)
    signal importRequested(var fileUrl)

    function openExport() {
        exportDialog.currentFolder = dialogs.defaultFolder;
        exportDialog.selectedFile = dialogs.defaultFile;
        exportDialog.open();
    }

    function openImport() {
        importDialog.currentFolder = dialogs.defaultFolder;
        importDialog.open();
    }

QtDialogs.FileDialog {
    id: exportDialog
    title: i18n("Export Settings")
    fileMode: QtDialogs.FileDialog.SaveFile
    nameFilters: [
        i18nc("file filter", "JSON backup files (*.json)"),
        i18nc("file filter", "All files (*)")
    ]
    defaultSuffix: "json"
    onAccepted: dialogs.exportRequested(exportDialog.selectedFile)
}

QtDialogs.FileDialog {
    id: importDialog
    title: i18n("Import Settings")
    fileMode: QtDialogs.FileDialog.OpenFile
    nameFilters: [
        i18nc("file filter", "JSON backup files (*.json)"),
        i18nc("file filter", "All files (*)")
    ]
    onAccepted: dialogs.importRequested(importDialog.selectedFile)
}
}
