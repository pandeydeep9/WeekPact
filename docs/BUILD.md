# Run WeekPact on a Mac

There is **no ready-to-install locked-mode app yet**. `swift run WeekPactApp` runs the usage tracker and old browser trial only.

To try the signed filter from source:

1. Install Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen). In the repository run `xcodegen generate`, then open `WeekPact.xcodeproj`.
2. Set your signing team on both **WeekPactMac** and **WeekPactFilter**. Build and run **WeekPactMac** in Xcode. If signing fails, the bundle IDs and App Group in `project.yml` may need to match your team.
3. In **Lock**, click **Enable filter** and approve the macOS prompts. Click **Test example.com · 60s**. Check a fresh tab in Safari, Chrome, and another browser. Wait a minute and check that it opens again.
4. Only after the test works, select services, daily time, and an end day. The displayed end date is midnight at the **start** of that day.

If `swift test` reports `no such module 'XCTest'`, select full Xcode in **Xcode → Settings → Locations → Command Line Tools**, or run:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/swift test
```

This source build has not been validated as a blocker on your Mac. An administrator can still remove or disable it; a separate administrator or device management is needed for uninstall resistance.
