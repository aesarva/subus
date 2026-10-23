#!/bin/bash
# Собирает build/Subus.app (Release).
#   ARCHS          архитектуры (по умолчанию "arm64 x86_64" — universal)
#   VERSION        версия для CFBundleShortVersionString (по умолчанию — MARKETING_VERSION из project.yml)
#   SIGN_IDENTITY  сертификат подписи, например "Developer ID Application: Имя (TEAMID)";
#                  по умолчанию "-" — подпись ad-hoc для локального запуска
#   BUILD_NUMBER   CFBundleVersion (по умолчанию — число коммитов); для сквозной проверки обновления
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -z "${DEVELOPER_DIR:-}" ] && [ -d /Applications/Xcode.app ]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

ARCHS="${ARCHS:-arm64 x86_64}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
# Номер сборки растёт с каждым коммитом — macOS сравнивает версии по нему.
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"

XCODE_ARGS=(
    -project Subus.xcodeproj -scheme Subus -configuration Release
    -derivedDataPath build/DerivedData
    ARCHS="$ARCHS" ONLY_ACTIVE_ARCH=NO
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER"
)
if [ -n "${VERSION:-}" ]; then XCODE_ARGS+=(MARKETING_VERSION="$VERSION"); fi

xcodegen generate --quiet
xcodebuild "${XCODE_ARGS[@]}" build -quiet

APP=build/Subus.app
rm -rf "$APP"
ditto build/DerivedData/Build/Products/Release/Subus.app "$APP"

# Переподписываем готовый бандл нужным сертификатом. Hardened runtime обязателен для нотаризации.
# В ad-hoc сборке его нет: у ad-hoc подписи нет Team ID, и library validation не даёт загрузить
# Sparkle.framework («different Team IDs»).
SIGN_FLAGS=(--force --sign "$SIGN_IDENTITY")
if [ "$SIGN_IDENTITY" != "-" ]; then SIGN_FLAGS+=(--options runtime --timestamp); fi

# Sparkle (автообновления). Downloader.xpc не нужен: у Subus есть network.client, и Sparkle скачивает
# в процессе приложения. Удаляется до подписи фреймворка. Installer.xpc нужен — через него ставится
# обновление из песочницы. Вложенный код подписывается изнутри наружу (порядок из документации Sparkle).
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
rm -rf "$SPARKLE/Versions/B/XPCServices/Downloader.xpc"
codesign "${SIGN_FLAGS[@]}" "$SPARKLE/Versions/B/XPCServices/Installer.xpc"
codesign "${SIGN_FLAGS[@]}" "$SPARKLE/Versions/B/Autoupdate"
codesign "${SIGN_FLAGS[@]}" "$SPARKLE/Versions/B/Updater.app"
codesign "${SIGN_FLAGS[@]}" "$SPARKLE"

# Entitlements передаём явно: без них переподпись снимает песочницу.
codesign "${SIGN_FLAGS[@]}" --entitlements App/Resources/Subus.entitlements "$APP"
codesign --verify --deep --strict "$APP"
echo "$(pwd)/$APP"
