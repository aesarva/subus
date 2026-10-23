#!/bin/bash
# Печатает ленту обновлений Sparkle (appcast.xml) для одного релиза.
#
#   scripts/make-appcast.sh dist/Subus-1.0.0.dmg 1.0.0 120 > dist/appcast.xml
#   FEED_BASE=http://127.0.0.1:8000 scripts/make-appcast.sh …  — лента для сквозной проверки с локального сервера
#
# DMG подписывается ключом EdDSA Subus из связки ключей (sign_update из Sparkle). Файл прикрепляется к релизу
# на GitHub рядом с DMG: приложение читает его по ссылке releases/latest/download/appcast.xml.
set -euo pipefail
cd "$(dirname "$0")/.."

DMG="${1:?Использование: scripts/make-appcast.sh <dmg> <версия> <номер сборки>}"
VERSION="${2:?нет версии}"
BUILD="${3:?нет номера сборки}"

SIGN_UPDATE=build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update
if [ ! -x "$SIGN_UPDATE" ]; then
    echo "Нет $SIGN_UPDATE: сначала scripts/build-app.sh" >&2
    exit 1
fi
# Печатает атрибуты sparkle:edSignature="…" length="…" для <enclosure>.
SIG_ATTRS="$("$SIGN_UPDATE" --account io.github.aesarva.Subus "$DMG")"

REPO=https://github.com/aesarva/subus
DOWNLOAD="${FEED_BASE:-$REPO/releases/download/v$VERSION}/$(basename "$DMG")"
PUB_DATE="$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")"

cat <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Subus</title>
    <link>$REPO</link>
    <item>
      <title>Subus $VERSION</title>
      <pubDate>$PUB_DATE</pubDate>
      <link>$REPO/releases/tag/v$VERSION</link>
      <sparkle:version>$BUILD</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <enclosure url="$DOWNLOAD" type="application/octet-stream" $SIG_ATTRS/>
    </item>
  </channel>
</rss>
XML
