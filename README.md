# WeekPact

Plan next week's internet rules, review them, and commit. You may tighten a committed rule immediately; a request to loosen it waits at least seven days and cannot alter an already committed week.

WeekPact is a macOS planning prototype for user-defined websites and services. It has a native SwiftUI editor, a policy engine, local persistence, tests, and an unactivated Network Extension feasibility prototype. A separate [five-minute YouTube trial](docs/TRIAL.md) uses Safari or Chrome Automation to redirect the tab at its limit. **This trial is bypassable; committed weekly website blocking is not active yet.**

The trial's five minutes reset at local midnight every day. To get YouTube back now, click **End test now** in the app (or quit an older app with ⌘Q). A future committed rule would keep its schedule across daily resets and weeks until an eligible scheduled relaxation takes effect. The app's [design](docs/DESIGN.md#status-when-i-open-the-app) specifies per-service status and countdowns.

## Run on a Mac

Install Apple's Xcode command line tools if you do not already have them (`xcode-select --install`). Then open Terminal:

```sh
git clone https://github.com/pandeydeep9/WeekPact.git
cd WeekPact
swift run WeekPactApp
```

In WeekPact, click **Start five-minute trial**, approve macOS Automation access for Safari or Chrome, and browse YouTube. The trial card shows seconds left and the next reset. Click **End test now · allow YouTube** to stop it immediately. To try planning, click **Preview rules** under the sample instruction, review the week, then **Record plan**. Recording currently saves a preview; it does not activate blocking. Run `swift test` to check the policy engine. See [trial instructions](docs/TRIAL.md), [build details](docs/BUILD.md), and the [design](docs/DESIGN.md).

This is a source-run macOS prototype, not a signed one-click installer. Enforced weekly blocking still requires a signed and activated macOS component and real-Mac testing.

### Prototype screenshot

The screen supplied during testing, before the trial status and layout update in this PR:

![WeekPact prototype on macOS before the UI update](docs/prototype-before.svg)
