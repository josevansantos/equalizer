#!/bin/bash
# Gera .build/Equalizer.app. O macOS só pede a permissão de captura de áudio a um app
# empacotado, com Info.plist e assinatura: um binário solto (swift run) não tem nenhum dos dois.
#
# Uso: scripts/build-app.sh [debug|release]   (padrão: release)
set -euo pipefail

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

swift build -c "$CONFIG"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

APP="$ROOT/.build/Equalizer.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_DIR/Equalizer" "$APP/Contents/MacOS/Equalizer"
cp "Sources/Equalizer/Info.plist" "$APP/Contents/Info.plist"
cp -R "$BIN_DIR/Equalizer_Equalizer.bundle" "$APP/Contents/Resources/"

# Assinatura ad hoc: o macOS trata cada build como um app novo e pode pedir a permissão de novo.
codesign --force --sign - \
    --identifier com.josevansantos.Equalizer \
    --entitlements "Sources/Equalizer/Equalizer.entitlements" \
    "$APP"

echo "$APP"
