# WeekPact

Plan next week's internet rules, review them, and commit. You may tighten a committed rule immediately; a request to loosen it waits at least seven days and cannot alter an already committed week.

WeekPact is a macOS planning prototype for user-defined websites and services. It has a native SwiftUI editor, a policy engine, local persistence, tests, and an unactivated Network Extension feasibility prototype. A separate [five-minute YouTube trial](docs/TRIAL.md) uses Safari or Chrome Automation to redirect the tab at its limit. **This trial is bypassable; committed weekly website blocking is not active yet.**

The trial's five minutes reset at local midnight every day. To get YouTube back now, click **End test now** in the app (or quit an older app with ⌘Q). A future committed rule would keep its schedule across daily resets and weeks until an eligible scheduled relaxation takes effect. The app's [design](docs/DESIGN.md#status-when-i-open-the-app) specifies per-service status and countdowns.

On a Mac with Xcode command line tools, run `swift test` and `swift run WeekPactApp`. See [build instructions](docs/BUILD.md) and the [design](docs/DESIGN.md). Enforcement requires a signed and activated macOS Network Extension and testing on a real Mac.
