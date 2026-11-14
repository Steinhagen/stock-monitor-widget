#!/bin/sh
# Compile-load every QML file in a real import environment. This catches the errors the
# unit tests cannot see: a moved component whose import was lost, or a property that
# overrides a final property of its base type.
#
# Local only: it needs the Kirigami/Plasma QML modules, which the CI runner does not
# install. Run it from a Plasma session (or with QML2_IMPORT_PATH pointing at them):
#
#   ./tests/smoke.sh
set -eu

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$DIR/.." && pwd)
RUNNER=${QMLTESTRUNNER:-qmltestrunner}

if ! command -v "$RUNNER" >/dev/null 2>&1; then
    echo "smoke: qmltestrunner not found, skipping" >&2
    exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

{
    echo 'import QtQuick'
    echo 'import QtTest'
    echo 'TestCase {'
    echo '    name: "LoadAll"'
    index=0
    for file in $(git -C "$ROOT" ls-files '*.qml'); do
        index=$((index + 1))
        printf '    function test_load_%s() {\n' "$index"
        printf '        var c = Qt.createComponent("file://%s/%s");\n' "$ROOT" "$file"
        printf '        if (c.status !== Component.Ready) console.log("%s -> " + c.errorString());\n' "$file"
        printf '        compare(c.status, Component.Ready);\n'
        printf '    }\n'
    done
    echo '}'
} > "$TMP/tst_load_all.qml"

QML_XHR_ALLOW_FILE_READ=1 "$RUNNER" -platform offscreen -input "$TMP/tst_load_all.qml"
