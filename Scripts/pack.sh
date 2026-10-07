#!/bin/bash
#
# pack.sh — build, sign, verify and package the Weather extension.
#
# Xcode does the building; this does what a shell script is actually good for:
# stamping the version, signing inside-out, checking the result, and producing a
# zip with a checksum.
#
# Usage:
#   Scripts/pack.sh [version] [build-number]
#
# Environment:
#   SIGN_IDENTITY   defaults to the first Apple Development identity found. For a
#                   distributable build, pass a Developer ID Application identity.

set -euo pipefail

VERSION="${1:-0.1.0}"
BUILD="${2:-$(date +%Y%m%d%H%M)}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${OUT:-$ROOT/Build}"
APP_ID="theboringteam.weather"
APPEX_ID="theboringteam.weather.tab"

identity() {
  if [[ -n "${SIGN_IDENTITY:-}" ]]; then printf '%s' "$SIGN_IDENTITY"; return; fi
  local dev dist
  dist=$(security find-identity -v -p codesigning 2>/dev/null | grep 'Developer ID Application' | head -1 | sed 's/.*"\(.*\)"/\1/') || true
  dev=$(security find-identity -v -p codesigning 2>/dev/null | grep 'Apple Development' | head -1 | sed 's/.*"\(.*\)"/\1/') || true
  if [[ -n "$dist" ]]; then printf '%s' "$dist"
  elif [[ -n "$dev" ]]; then printf '%s' "$dev"
  else echo "error: no codesigning identity found; set SIGN_IDENTITY" >&2; exit 1; fi
}

IDENTITY="$(identity)"

main() {
  cd "$ROOT"

  echo "==> building (version $VERSION, build $BUILD)"
  xcodebuild -project "Boring Weather.xcodeproj" -scheme "Boring Weather" \
    -configuration Release -derivedDataPath "$ROOT/build" \
    MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD" \
    build > /dev/null

  local app="$ROOT/build/Build/Products/Release/Boring Weather.app"
  local appex="$app/Contents/Extensions/WeatherTab.appex"
  [[ -d "$appex" ]] || { echo "error: no appex at $appex" >&2; exit 1; }

  # ExtensionKit extensions must sit in Contents/Extensions. Embedding them in
  # Contents/PlugIns builds cleanly and then never loads, with only a build
  # warning to say so.
  [[ -d "$appex" ]] || { echo "error: appex is not in Contents/Extensions" >&2; exit 1; }

  # The catalog compares the manifest's version against CFBundleShortVersionString,
  # so a mismatch is a validation failure at install time rather than a wrong-looking
  # record. Verified here instead, where it can be pointed at.
  local short
  short=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$appex/Contents/Info.plist")
  [[ "$short" == "$VERSION" ]] \
    || { echo "error: appex version is $short, expected $VERSION" >&2; exit 1; }

  # EXExtensionPrincipalClass is resolved with NSClassFromString, which only sees
  # classes the compiler emitted into __objc_classname. Xcode emits it for the
  # principal class, but a rename would still produce a pack that installs, approves,
  # registers, launches, and dies with no UI and nothing in any log.
  if ! otool -v -s __TEXT __objc_classname "$appex/Contents/MacOS/WeatherTab" 2>/dev/null \
      | awk '{print $NF}' | grep -qx 'BoringNotchWeather'; then
    echo "error: principal class 'BoringNotchWeather' is not registered in the binary." >&2
    exit 1
  fi

  # The appex's real bundle identifier has to be the one the extension declared,
  # because that is the scene identifier the host asks for and the key the catalog
  # records. An unset DEVELOPMENT_TEAM makes Xcode prefix it with the signing team,
  # which silently turns com.personalteam.Weather.WeatherTab into
  # theboringteam.weather.tab into a different identifier entirely: still
  # builds, still signs, never loads.
  local actual
  actual=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$appex/Contents/Info.plist")
  [[ "$actual" == "$APPEX_ID" ]] \
    || { echo "error: appex bundle id is '$actual', expected '$APPEX_ID'." >&2; exit 1; }
  local declared_scene
  declared_scene=$(/usr/libexec/PlistBuddy -c 'Print :EXAppExtensionAttributes:EXExtensionSceneID' "$appex/Contents/Info.plist")
  [[ "$declared_scene" == "$actual" ]] \
    || { echo "error: EXExtensionSceneID '$declared_scene' does not match bundle id '$actual'." >&2; exit 1; }

  echo "==> signing"
  local work; work="$(mktemp -d)"; trap 'rm -rf "${work:-}"' EXIT

  # Entitlements are read from the built bundle and re-applied. `codesign --force`
  # without `--entitlements` replaces the signature and drops them, and an
  # extension that loses app-sandbox is never indexed: the install reports success,
  # the record exists, and the extension never appears.
  codesign -d --entitlements :- "$appex" > "$work/appex.plist" 2>/dev/null
  plutil -lint "$work/appex.plist" > /dev/null \
    || { echo "error: appex has no entitlements; it would never register" >&2; exit 1; }

  # Inside-out: the appex is sealed first, then the app that contains it. Signing
  # the outer bundle first would invalidate the inner one.
  codesign --force --sign "$IDENTITY" --timestamp=none \
    --entitlements "$work/appex.plist" "$appex"
  codesign --force --sign "$IDENTITY" --timestamp=none "$app"
  codesign --verify --strict "$appex"
  codesign --verify --strict "$app"

  mkdir -p "$OUT"
  # ditto, not zip: an .app is a bundle whose symlinks, permissions and extended
  # attributes matter, and zip mangles them often enough that the extracted bundle
  # fails signature verification — which presents as an install failure.
  rm -f "$OUT/Weather.zip"
  ( cd "$ROOT/build/Build/Products/Release" && ditto -c -k --keepParent "Boring Weather.app" "$OUT/Weather.zip" )

  echo
  echo "appid=$APP_ID appexid=$APPEX_ID"
  echo "version=$VERSION build=$BUILD identity=$IDENTITY"
  echo "sha256=$(shasum -a 256 "$OUT/Weather.zip" | cut -d' ' -f1)"
  echo "path=$OUT/Weather.zip"
}

main "$@"