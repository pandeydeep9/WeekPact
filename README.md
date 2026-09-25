# WeekPact

Plan next week's internet rules, review them, and commit. You may tighten a committed rule immediately; a request to loosen it waits at least seven days and cannot alter an already committed week.

WeekPact is a macOS planning prototype for user-defined websites and services. It has a native SwiftUI editor, a policy engine, local persistence, tests, and an unactivated Network Extension feasibility prototype. A separate [five-minute YouTube trial](docs/TRIAL.md) uses Safari or Chrome Automation to redirect the tab at its limit. **This trial is bypassable; committed weekly website blocking is not active yet.**

On a Mac with Xcode command line tools, run `swift test` and `swift run WeekPactApp`. See [build instructions](docs/BUILD.md) and the [design](docs/DESIGN.md). Enforcement requires a signed and activated macOS Network Extension and testing on a real Mac.
