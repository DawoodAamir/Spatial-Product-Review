#!/bin/bash
set -euo pipefail
mkdir -p build
result="build/Workflow-$(date +%s).xcresult"
xcodebuild -project 'Spatial Product Review.xcodeproj' -scheme 'Spatial Product Review' -destination 'platform=macOS' -derivedDataPath build/DerivedData test -collect-test-diagnostics never -resultBundlePath "$result"
xcrun xcresulttool export attachments --path "$result" --output-path build/Screenshots
