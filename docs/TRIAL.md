# Test the five-minute YouTube trial

This is a **browser-automation prototype**, not a locked commitment. It works only while WeekPact is running and only for a frontmost YouTube tab in Safari or Google Chrome. It counts foreground tab time, even if you leave the tab idle. It does not cover Firefox, embedded videos, background playback, or another device.

On your Mac, install Xcode command line tools if needed, then run:

```sh
git clone https://github.com/pandeydeep9/WeekPact.git
cd WeekPact
swift test
swift run WeekPactApp
```

In the **Try a five-minute YouTube limit today** section:

1. Keep `YouTube 5 minutes per day` in the instruction field and click **Start trial**.
2. Open YouTube in Safari or Chrome and keep that browser tab frontmost. Approve the macOS Automation prompt for browser access. If it was denied, check **System Settings → Privacy & Security → Automation**.
3. Watch the remaining seconds in WeekPact. The counter should pause when another app or site is frontmost.
4. At zero, WeekPact attempts to redirect the YouTube tab to `about:blank`. Opening YouTube again in a supported browser should cause another redirect while WeekPact keeps running. The app shows the next local midnight and a live countdown.

**Get YouTube back now:** Click **End test now** in WeekPact, then reopen YouTube. This stops redirects and clears the test counter. In an older copy of the app without this button, quit WeekPact with **⌘Q**, then reopen YouTube. The redirect happens only while the app is running.

The five-minute allowance resets at the next local midnight, and the same five-minute trial continues each day until you end it. Reopening WeekPact retains today's counter if you have not ended the test. Clicking **Start trial** while already running cannot refill it. Ending this test and starting it again does give a fresh counter: **this is a bypassable prototype, not a committed rule**. Quitting WeekPact, denying Automation, or editing local preferences can also bypass it. The system filter in the repository is still inactive. See [commitment and reset semantics](DESIGN.md#rules-of-commitment) for the intended product.

If `swift run` does not receive an Automation prompt, generate the [Xcode project](../project.yml) with XcodeGen and run the app target from Xcode with an appropriate development signing team. The app target includes the Apple Events usage description. Share the exact status text and your browser if a step fails.
