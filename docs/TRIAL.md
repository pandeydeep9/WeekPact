# Test the five-minute YouTube trial

This is a **browser-automation prototype**, not a locked commitment. By default, it works only while WeekPact is running and only for a frontmost YouTube tab in Safari or Google Chrome. The optional helper below tests continuation after the UI quits. It counts foreground tab time, even if you leave the tab idle. It does not cover Firefox, embedded videos, background playback, or another device.

On your Mac, install Xcode command line tools if needed, then run:

```sh
git clone https://github.com/pandeydeep9/WeekPact.git
cd WeekPact
swift test
swift run WeekPactApp
```

In **Today**, expand **Old five-minute YouTube browser trial**:

1. Click **Start browser trial**.
2. Open YouTube in Safari or Chrome and keep that browser tab frontmost. Approve the macOS Automation prompt for browser access. If it was denied, check **System Settings → Privacy & Security → Automation**.
3. Watch the remaining seconds in WeekPact. The counter should pause when another app or site is frontmost.
4. At zero, WeekPact attempts to redirect the YouTube tab to `about:blank`. Opening YouTube again in a supported browser should cause another redirect while WeekPact keeps running. The trial resets at local midnight.

**Get YouTube back now:** Click **End browser trial** in WeekPact, then reopen YouTube. This stops redirects and clears the test counter. Without the optional helper below, quitting WeekPact with **⌘Q** also stops redirects.

The five-minute allowance resets at the next local midnight, and the same five-minute trial continues each day until you end it. Reopening WeekPact retains today's counter if you have not ended the test. Clicking **Start trial** while already running cannot refill it. Ending this test and starting it again does give a fresh counter: **this is a bypassable prototype, not a committed rule**. The system filter in the repository is still inactive. See [commitment and reset semantics](DESIGN.md#rules-of-commitment) for the intended product.

### Test continuation after quitting the UI

This optional per-user helper tests whether the same Safari/Chrome redirect can continue after you quit WeekPact. On your Mac, in the repository:

```sh
bash scripts/trial-agent.sh install
bash scripts/trial-agent.sh status
```

In WeekPact, end any previous browser trial and start a fresh five-minute trial. Keep a YouTube tab frontmost for part of the allowance; then quit WeekPact with **⌘Q**, keep using YouTube, and check whether the tab redirects at five minutes total. macOS may ask separately for the helper's Safari/Chrome Automation permission. Check `~/Library/Application Support/WeekPact/trial-agent.log` for errors. Reopen WeekPact to end the trial. The helper is started again at login; confirm that behavior on your Mac before relying on it. To stop the helper, run `bash scripts/trial-agent.sh remove`.

This helper is a **feasibility test**, not a strict lock: it is removable, only sees the foreground Safari/Chrome tab, and may not receive Automation permission in the background. It does not cover Firefox, private windows without testing, native clients, or existing background video playback. Do not commit an unbreakable weekly rule based on this test.

If `swift run` does not receive an Automation prompt, generate the [Xcode project](../project.yml) with XcodeGen and run the app target from Xcode with an appropriate development signing team. The app target includes the Apple Events usage description. Share the exact status text and your browser if a step fails.
