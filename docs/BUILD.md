# Build and verify WeekPact on macOS

## Tracking-only run

`swift test` and `swift run WeekPactApp` start the local usage tracker and old YouTube browser trial. This Swift package executable cannot install the macOS system extension. It cannot commit a locked limit.

## Signed filter setup

1. Install Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen). Run `xcodegen generate` in the repository and open `WeekPact.xcodeproj`.
2. In Xcode, choose your Apple Developer signing team for **WeekPactMac** and **WeekPactFilter**. Both targets need matching App Group entitlements; the app and extension need the Network Extension capability, and the app needs System Extension installation. Adjust the bundle IDs and App Group in `project.yml` if they belong to another team, then regenerate the project.
3. Build and run **WeekPactMac** on your Mac. In **Lock → macOS filter setup**, click **Enable filter**. Approve the extension and network filter in macOS System Settings if prompted, then click **Refresh status**. If macOS requires a restart, do it and reopen the app.
4. Click **Test example.com · 60s**. In a fresh tab, confirm `example.com` is blocked in Safari, Chrome, and another browser. After 60 seconds, confirm it opens again. Repeat after a restart. **Do not commit a real limit until this test works across browsers on your Mac.**
5. Select services, 30 minutes/1 hour/2 hours/3 hours per day, and the end day. The chosen day means **12:00 AM at the start of that day** in your current time zone. WeekPact displays the exact date before confirmation. It starts the rule immediately and registers the main app to start at login. Active rules cannot be loosened through the UI.

The filter drops traffic for a selected service if the active browser's foreground URL is unreadable, if its usage heartbeat is stale, if a different app/browser creates the flow, or if the day's allowance is spent. The foreground sampler supports Safari and Chrome; other browsers and native clients get no allowance while a rule is active. The provider checks chunks on established flows as data arrives, and the app also redirects an over-limit foreground Safari/Chrome tab to `about:blank`.

**This still needs real-Mac validation.** Signing, macOS approvals, domain resolution, already-open flows, Firefox, private windows, native apps, reboot, app removal, and clock changes cannot be proven by CI's unsigned build. A flow with no usable hostname may be invisible to domain filtering. An administrator can disable the filter, change shared local state, alter the clock, or uninstall software. A personally administered Mac cannot guarantee that uninstalling WeekPact leaves the lock intact. For stronger resistance, use separate administrator or device management controls outside WeekPact.

See [usage and privacy](USAGE.md), [design](DESIGN.md), and the [old trial guide](TRIAL.md).
