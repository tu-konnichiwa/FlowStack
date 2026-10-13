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

project="Examples/Example/Example.xcodeproj"
scheme="Example"
example_common=( -project "$project" -scheme "$scheme"
    -derivedDataPath "$validation_root/example-derived"
    -clonedSourcePackagesDirPath "$validation_root/packages"
    -packageCachePath "$validation_root/package-cache"
    CODE_SIGNING_ALLOWED=NO )
xcodebuild build "${example_common[@]}" -destination 'generic/platform=iOS Simulator'
