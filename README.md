# WeekPact

Plan next week's internet rules, review them, and commit. You may tighten a committed rule immediately; a request to loosen it waits at least seven days and cannot alter an already committed week.

WeekPact is a macOS planning prototype for user-defined websites and services. It has a native SwiftUI editor, a policy engine, local persistence, tests, and an unactivated Network Extension feasibility prototype. **It does not block websites yet.**

On a Mac with Xcode command line tools, run `swift test` and `swift run WeekPactApp`. See [build instructions](docs/BUILD.md) and the [design](docs/DESIGN.md). Enforcement requires a signed and activated macOS Network Extension and testing on a real Mac.
