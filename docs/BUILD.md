# Run the planning prototype

On a Mac with Xcode command line tools:

```sh
swift test
swift run WeekPactApp
```

The app lets you type a limited set of rules, edit them, inspect the week, and save the plan locally. Try the example prompt supplied in the editor. For an arbitrary site, enter `Block example.com`; edit the days, hours, and daily allowance in the resulting rule.

**This prototype does not block websites.** Its saved plans are ordinary files in Application Support and can be changed outside the app. Do not rely on them as an irreversible commitment. The next engineering milestone is a signed macOS Network Extension and a Mac test of domain coverage, permissions, and disable behavior. Daily usage budgets also require validated foreground measurement; the planner currently models budgets but does not measure usage.

The current interpreter accepts known service names (YouTube, Netflix, Reddit, Instagram, Facebook, TikTok, X) and literal domains, plus simple requests such as `Block Reddit`, `YouTube 30 minutes after 6 PM`, and `Netflix 2 hours on Friday and Saturday`. It lists clauses it cannot parse; those must be resolved before saving.
