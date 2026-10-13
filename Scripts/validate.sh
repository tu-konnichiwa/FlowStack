#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
validation_root="$(mktemp -d "${TMPDIR:-/tmp}/flowstack-validation.XXXXXX")"
trap 'rm -rf "$validation_root"' EXIT
export CLANG_MODULE_CACHE_PATH="$validation_root/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$validation_root/module-cache"

swift test --disable-sandbox --scratch-path "$validation_root/library"
swift build -c release --disable-sandbox --scratch-path "$validation_root/release"
ios_sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
swift build --disable-sandbox --scratch-path "$validation_root/ios" \
    --sdk "$ios_sdk" --triple arm64-apple-ios16.0-simulator

project="Examples/ShopDemo/ShopDemo.xcodeproj"
scheme="ShopDemo"
common=( -project "$project" -scheme "$scheme"
    -derivedDataPath "$validation_root/shopdemo-derived"
    -clonedSourcePackagesDirPath "$validation_root/packages"
    -packageCachePath "$validation_root/package-cache"
    CODE_SIGNING_ALLOWED=NO )
xcodebuild build-for-testing "${common[@]}" -destination 'generic/platform=iOS Simulator'

simulator_id="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; data=json.load(sys.stdin); print(next((d["udid"] for ds in data["devices"].values() for d in ds if d["isAvailable"]), ""))')"
if [[ -n "$simulator_id" ]]; then
    xcodebuild test "${common[@]}" -destination "platform=iOS Simulator,id=$simulator_id"
else
    echo "No available iOS Simulator runtime; ShopDemo compiled with build-for-testing but XCTest execution was skipped."
fi
