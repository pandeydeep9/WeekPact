# WeekPact

Choose websites, set a daily limit, and pick the midnight when the rule ends.

WeekPact is a macOS local usage tracker with a compact **Today / Lock / Report** interface. It offers fixed website limits for YouTube, Netflix, Facebook, Messenger, Instagram, Reddit and Quora. A signed macOS system filter can apply those rules when WeekPact's window is closed. **The signed filter must be installed, approved, and tested on a real Mac before a limit can be committed.**

The older five-minute YouTube trial is still available under Today for testing; it can be ended immediately. A **locked** rule starts now and ends at the start of the selected day at 12:00 AM. The chosen daily minutes refill each local midnight, but the rule itself cannot be reset from WeekPact before its end. This is a local software lock, not a guarantee against an administrator removing or disabling macOS protection.

## Run on a Mac

To try usage tracking, install Apple's Xcode command line tools if needed (`xcode-select --install`). Then open Terminal:

```sh
git clone https://github.com/pandeydeep9/WeekPact.git
cd WeekPact
swift run WeekPactApp
```

In **Today**, WeekPact counts frontmost Safari/Chrome website time while its process runs. **Lock** selects fixed services, a daily allowance (30 minutes, 1 hour, 2 hours or 3 hours), and the midnight when the rule expires. **Report** summarizes the last seven days when you request it; typing `generate report` works too. The `swift run` command above **does not block websites**. The [signed Xcode build](docs/BUILD.md) is needed to try blocking. See [usage and privacy](docs/USAGE.md) and the [design](docs/DESIGN.md).

This is source-run code, not a signed one-click installer. Stronger uninstall resistance requires separate administrator or device management; a user who administers this Mac can ultimately turn off the filter.

### Prototype screenshot

The screen supplied during testing, before the trial status and layout update in this PR:

![WeekPact prototype on macOS before the UI update](docs/prototype-before.svg)
