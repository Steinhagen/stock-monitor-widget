#!/bin/sh
# Fail on QML syntax errors. qmllint's unresolved-member warnings are expected for the
# Plasma/Kirigami imports, so only [syntax] diagnostics are treated as fatal.
set -eu

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$DIR/.." && pwd)
QMLLINT=${QMLLINT:-qmllint}

failed=0
for file in $(git -C "$ROOT" ls-files '*.qml'); do
    output=$("$QMLLINT" "$ROOT/$file" 2>&1 || true)
    if printf '%s\n' "$output" | grep -q '\[syntax\]'; then
        printf '%s\n' "$output" | grep '\[syntax\]'
        failed=1
    fi
done

if [ "$failed" -ne 0 ]; then
    exit 1
fi
echo "QML syntax: OK"
