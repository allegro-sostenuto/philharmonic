#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v xcodebuild >/dev/null; then
    echo 'Xcode on macOS is required for iOS builds.' >&2
    exit 1
fi
swift test
xcodebuild -project Philharmonic.xcodeproj -scheme Philharmonic-17 -configuration Debug \
    -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
# To run the hosted tests: xcodebuild -project Philharmonic.xcodeproj -scheme Philharmonic-SE \
#   -destination 'platform=iOS Simulator,name=<installed iPhone simulator>' test
