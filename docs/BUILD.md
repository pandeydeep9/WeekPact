# Run the planning prototype

On a Mac with Xcode command line tools:

```sh
swift test
swift run WeekPactApp
```

The app's **Today / Plan / Report** screens let you inspect local website time, type and edit rules, and generate a seven-day report on demand. Try the example prompt in **Plan**. For an arbitrary site, enter `Block example.com`; edit the days, hours, and daily allowance in the resulting rule. See [usage and privacy](USAGE.md) for tracking coverage and limitations.

To test a real five-minute YouTube redirect in Safari or Chrome, follow the [trial guide](TRIAL.md). The trial uses browser Automation while the app is running and is separate from weekly commitments.

**This prototype does not block websites.** Its saved plans are ordinary files in Application Support and can be changed outside the app. Do not rely on them as an irreversible commitment. A Network Extension provider is present as a compile-time feasibility spike, but the app does not activate it. To generate the signed-app project, install [XcodeGen](https://github.com/yonaskolb/XcodeGen) and run `xcodegen generate`. Signing requires an Apple Developer team, the Network Extension and System Extension capabilities, and an App Group matching `project.yml`. A real Mac must validate activation, browser coverage, clock behavior, and deactivation before this becomes a usable blocker.

The experimental provider reads a shared, editable policy snapshot. It blocks a budgeted domain entirely because foreground time is not measured. If it cannot read a policy or determine a host, it allows that flow. These limits are why it is not connected to the planner as a commitment mechanism.

The current interpreter accepts known service names (YouTube, Netflix, Reddit, Instagram, Facebook, TikTok, X) and literal domains, plus simple requests such as `Block Reddit`, `YouTube 30 minutes after 6 PM`, and `Netflix 2 hours on Friday and Saturday`. It lists clauses it cannot parse; those must be resolved before saving.
