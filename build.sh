#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="${INSTALL_DIR:-$ROOT_DIR/build}"
APP_PATH="$INSTALL_DIR/KeepAwake.app"

rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS"

swiftc \
    -O \
    -framework AppKit \
    "$ROOT_DIR/Sources/main.swift" \
    -o "$APP_PATH/Contents/MacOS/KeepAwake"

cp "$ROOT_DIR/Resources/Info.plist" "$APP_PATH/Contents/Info.plist"

echo "Built $APP_PATH"
