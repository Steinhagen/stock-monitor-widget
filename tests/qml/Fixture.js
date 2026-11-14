.pragma library
// Test helper: read a fixture synchronously. The URL is resolved by the caller with
// Qt.resolvedUrl(), relative to the test file.
function read(url) {
    var xhr = new XMLHttpRequest();
    xhr.open("GET", url, false);
    xhr.send();
    return xhr.responseText || "";
}
