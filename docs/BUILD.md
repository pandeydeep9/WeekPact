# Run WeekPact on a Mac

There is **no ready-to-install locked-mode app yet**. `swift run WeekPactApp` runs the usage tracker and old browser trial only. For a free local blocking test, follow the [README](../README.md#test-a-free-local-block). The original signed filter below requires an enrolled Apple Developer Program team because a free Personal Team cannot provision Network Extensions, even for a personal build. You do not need to pay to run the tracker or the local blocking test.

To try the signed filter from source:

1. Install full [Xcode from the Mac App Store](https://developer.apple.com/xcode/resources/) and open it once to finish setup. Command Line Tools alone are insufficient. Check with `xcodebuild -version`.
2. If you have Homebrew, run `brew install xcodegen` (no Mint needed). In the repository run `xcodegen generate`, then open `WeekPact.xcodeproj`.
3. Set your enrolled Developer Program team on both **WeekPactMac** and **WeekPactFilter**. Build and run **WeekPactMac** in Xcode. If signing fails, the bundle IDs and App Group in `project.yml` may need to match your team.
4. In **Lock**, click **Enable filter** and approve the macOS prompts. Click **Test example.com · 60s**. Check a fresh tab in Safari, Chrome, and another browser. Wait a minute and check that it opens again.
5. Only after the test works, select services, daily time, and an end day. The displayed end date is midnight at the **start** of that day.

If `swift test` reports `no such module 'XCTest'`, select full Xcode in **Xcode → Settings → Locations → Command Line Tools**, or run the following **after installing Xcode in `/Applications`**:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/swift test
```

This source build has not been validated as a blocker on your Mac. An administrator can still remove or disable it; a separate administrator or device management is needed for uninstall resistance.
