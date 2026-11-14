#!/bin/sh
#
# Run the QML unit/controller tests.
#
#   ./tests/run.sh
#
# Requires qmltestrunner from Qt 6 (qtdeclarative). No network access is needed: the
# tests read fixtures from tests/fixtures.

set -eu

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

# Ubuntu and Debian install the Qt tools outside PATH.
if ! command -v qmltestrunner >/dev/null 2>&1; then
    for dir in /usr/lib/qt6/bin /usr/lib/x86_64-linux-gnu/qt6/bin /usr/lib64/qt6/bin; do
        if [ -x "$dir/qmltestrunner" ]; then
            PATH="$dir:$PATH"
            export PATH
            break
        fi
    done
fi

if ! command -v qmltestrunner >/dev/null 2>&1; then
    echo "[tests] Error: qmltestrunner not found in PATH." >&2
    echo "[tests] Install the Qt 6 declarative tools, e.g." >&2
    echo "[tests]   nix shell nixpkgs#qt6.qtdeclarative -c ./tests/run.sh" >&2
    exit 1
fi

# The fixture loader reads local files through XMLHttpRequest; Qt refuses file://
# requests unless this is set.
export QML_XHR_ALLOW_FILE_READ=1

exec qmltestrunner -platform offscreen -input "$DIR/qml" "$@"
