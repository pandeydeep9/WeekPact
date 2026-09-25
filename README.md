# WeekPact

Choose websites, set a daily limit, and pick the midnight when the rule ends.

WeekPact is a macOS local usage tracker with a compact **Today / Lock / Report** interface. It offers fixed website limits for YouTube, Netflix, Facebook, Messenger, Instagram, Reddit and Quora. The current locked mode uses Apple's restricted Network Extension and therefore cannot be signed with a free Personal Team, even for use on your own Mac. **Paying for distribution is not a goal of this project.** A free local blocking test is below; WeekPact's daily limits are not yet connected to it.

The older five-minute YouTube trial is still available under Today for testing; it can be ended immediately. A **locked** rule starts now and ends at the start of the selected day at 12:00 AM. The chosen daily minutes refill each local midnight, but the rule itself cannot be reset from WeekPact before its end. This is a local software lock, not a guarantee against an administrator removing or disabling macOS protection.

## Run on a Mac

To try usage tracking, install Apple's Xcode command line tools if needed (`xcode-select --install`). Then open Terminal:

```sh
git clone https://github.com/pandeydeep9/WeekPact.git
cd WeekPact
swift run WeekPactApp
```

In **Today**, WeekPact counts frontmost Safari/Chrome website time while its process runs. **Lock** selects fixed services, a daily allowance (30 minutes, 1 hour, 2 hours or 3 hours), and the midnight when the rule expires. **Report** summarizes the last seven days when you request it; typing `generate report` works too. The `swift run` command above **does not block websites**. See [usage and privacy](docs/USAGE.md) and the [design](docs/DESIGN.md).

### Test a free local block

Install [SelfControl](https://selfcontrolapp.com/) in `/Applications`. In SelfControl, make a blocklist containing **only `example.com`** and choose **File → Save Blocklist**. Then run:

```sh
bash scripts/test-local-block.sh /path/to/your-saved-blocklist.selfcontrol
```

Confirm the displayed timer is about two minutes; check `example.com` in fresh Safari and Chrome tabs, restart, and check again if there is time. The block should expire without WeekPact running. This test does **not** enable WeekPact's daily allowances. SelfControl permits one active block at a time, so additional work is needed for independent daily limits. VPNs, proxies and some Firefox DNS settings can bypass its blocking; verify coverage on your Mac before relying on it.

This is source-run code, not a finished locked-mode installer. The [original signed-filter build](docs/BUILD.md) remains available for developers who already have that capability. A user who administers this Mac can ultimately disable local protections.

### Prototype screenshot

The screen supplied during testing, before the trial status and layout update in this PR:

![WeekPact prototype on macOS before the UI update](docs/prototype-before.svg)
