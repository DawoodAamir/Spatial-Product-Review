# Contributing

Use Xcode 27 and Swift 6. Keep UI state on the main actor and file operations in ReviewStore. Preserve original model bytes, reject stale revisions, and surface import or presentation failures without losing review notes.

Run Debug/Release package tests and the Release app build for changes. Run the native workflow when interaction changes. A successful Mac build does not verify headset discovery, transfer, reconnection, or SharePlay; describe hardware checks explicitly.

Keep sample assets original or document their redistribution license. Regenerate the sample with `python3 Scripts/GenerateSample.py` and the icon with `swift Scripts/GenerateIcon.swift "$PWD"`. Use focused Conventional Commits.
