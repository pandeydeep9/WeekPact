# Local website usage prototype

WeekPact counts the frontmost HTTP(S) tab in Safari or Chrome once per second **while the WeekPact process is running**. It pauses when another app is in front. Time is grouped by local calendar day, browser, site, and service. The initial named services are YouTube, Netflix, Facebook, Messenger, Instagram, Reddit, and Quora; other sites appear by hostname. Facebook's `/messages` section is classified as Messenger, but the path itself is not saved.

**Today** shows the current total and leading sites. Click **Generate 7-day report** to take a snapshot of the past seven local days, or type `generate report` in the command field. Open **Report** and click **Generate report** again to refresh it. Reports are computed on demand from local data; no report is sent anywhere.

Data is saved in `~/Library/Application Support/WeekPact/usage.json`. Each entry contains a date, hostname, service, browser, seconds, session count, and last-seen time. WeekPact does not save page paths, search terms, page titles, or full URLs. **Pause tracking** on Today stops new samples. Existing records remain on this Mac.

## Coverage and accuracy

- Browser Automation permission is required. An unreadable tab is omitted and reported in the status line. Only foreground tab time is counted, including idle time; background audio and other devices are not counted.
- Safari Private Browsing and Chrome Incognito are **not verified yet**. The current sampler tries the frontmost URL in those windows, but macOS/browser permissions or browser behavior may prevent it. Do not treat this report as complete private-window history. Test both on a real Mac before claiming coverage. Reliable extension-based coverage would require explicit private/incognito access in each browser.
- Closing the window may leave the app process running, but quitting WeekPact or stopping its process stops tracking. A future installed background helper is required for reliable tracking without the app open. This prototype is not a hidden system-wide monitor.
- Polling once per second and capping time across sleep means totals are estimates. A tab open in the background or time when the computer sleeps is not counted. Daily totals use the current local time zone.
- Messenger on `facebook.com/messages` can be reported separately because the foreground tab URL has a path. The current host-based policy prototype cannot enforce that path separately from the rest of `facebook.com`; that needs browser-aware enforcement or a clearly broader Facebook rule.
- With a signed, enabled filter and an active fixed-service lock, an unreadable frontmost tab or stopped sampler blocks the selected service rather than granting free time. This does not prove coverage for every browser, domain, existing connection, or app. Do the [real-Mac filter test](BUILD.md#signed-filter-setup) before committing a rule.
