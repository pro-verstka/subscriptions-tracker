#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT="SubscriptionsTracker.xcodeproj"
SCHEME="SubscriptionsTracker"
APP_NAME="SubscriptionsTracker"
ENTITLEMENTS="SubscriptionsTracker/SubscriptionsTracker.entitlements"

BUILD_DIR="$PWD/build"
DERIVED_DATA="$BUILD_DIR/DerivedData"
APP="$BUILD_DIR/$APP_NAME.app"

rm -rf "$APP" "$DERIVED_DATA"
mkdir -p "$BUILD_DIR"

# Build unsigned with xcodebuild; we re-sign below so the same flow works both
# locally (with a developer cert) and on CI (ad-hoc, no Apple account needed).
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$DERIVED_DATA" \
    -destination 'generic/platform=macOS' \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    DEVELOPMENT_TEAM="" \
    build

cp -R "$DERIVED_DATA/Build/Products/Release/$APP_NAME.app" "$APP"

if security find-identity -v -p codesigning 2>/dev/null | grep -q "$APP_NAME Developer"; then
    codesign --force --options runtime \
        --entitlements "$ENTITLEMENTS" \
        --sign "$APP_NAME Developer" "$APP"
else
    codesign --force \
        --entitlements "$ENTITLEMENTS" \
        --sign - "$APP"
fi

echo "Built: $APP"
