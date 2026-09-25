# WeekPact design

WeekPact is a macOS app for deciding how you may use distracting online services **next week**, then committing to that decision. You can describe the rules in a chat box or set them in a weekly calendar. Both produce the same schedule for you to review before you lock it.

The scope is any sites and groups you define: video, social media, shopping, news, gaming, or something else. The first release is for one person on one Mac.

## A week with WeekPact

On Friday, I type: “Next week, YouTube for 30 minutes a day after 6 PM. Netflix for two hours on Friday and Saturday. Block Reddit.”

WeekPact shows **Monday, September 28 – Sunday, October 4** in my time zone:

| Service | Monday–Thursday | Friday | Saturday | Sunday |
|---|---|---|---|---|
| YouTube | 30 min, 6–10 PM | 30 min, 6–10 PM | 30 min, 6–10 PM | 30 min, 6–10 PM |
| Netflix | Blocked | 2 hr | 2 hr | Blocked |
| Reddit | Blocked | Blocked | Blocked | Blocked |
| Other sites | Allowed | Allowed | Allowed | Allowed |

I can click a cell to correct the plan. I review the covered domains and press **Commit week**. On Wednesday I may cut YouTube to 15 minutes immediately, but a request to increase it to an hour waits. Quitting the planner or restarting the Mac should not end an active restriction. At the end of the week, my next committed schedule begins; if I made none, the existing rules carry forward.

## Rules of commitment

- A week runs Monday 00:00 to the next Monday 00:00 in the selected time zone. The app always displays dates, not just day names.
- A daily allowance refills at 00:00 in the rule's committed time zone, even on days when the service is blocked. Unused minutes do not carry over. Midnight refills minutes; it does not remove or weaken a rule.
- A time window opens and closes at its scheduled local times. If the daily allowance was used up, the next window that day does not refill it.
- Drafts can be edited. Committing freezes the week's maximum access. A change that only reduces access takes effect immediately.
- A weaker change is scheduled for **at least seven days later** and cannot alter an already committed week. Show its earliest effective date before accepting it.
- If no new plan is committed, carry forward the current restrictions. Never revert to unlimited access by omission.
- A rule can block a service, set available hours, set a daily allowance, or combine hours and an allowance. Groups of sites may share one allowance. When rules overlap, the stricter result applies.
- The app treats a change as “stricter” only if it grants no additional access across domains, hours, and allowances. Ambiguous changes are queued for later.

### Status when I open the app

Show the current state of each service and a countdown to the next relevant change. Keep **allowance reset**, **window opening**, and **rule change** separate, since a reset does not necessarily grant access.

| Field | Example for a spent YouTube allowance at 8 PM |
|---|---|
| Current access | Blocked: today's 30 minutes used |
| Next allowance reset | Tomorrow 12:00 AM, in 4 hours |
| Next permitted window | Tomorrow 6:00 PM, if allowance remains |
| Active rule | 30 minutes/day, 6–10 PM; carries forward after Sunday |
| Pending relaxation | Effective Monday, October 12, if one was requested |

The status screen also shows the date and time zone, actual minutes used and remaining, coverage health, and the exact date of the next committed weekly plan. For a service blocked every day, say **Blocked until a future relaxation takes effect**; do not display midnight as an unblock time. Countdowns recompute after sleep, reboot, or a time-zone change. If clock integrity is uncertain, retain the restriction and show that time verification is needed.

The fixed-service lock now has a signed-filter implementation path, separate from the old browser trial. It requires user approval and real-Mac coverage testing. An unsigned `swift run` cannot enable it. Its per-service countdown appears in Today; the old generic weekly plan is no longer the primary UI.

**Planning cutoff to decide:** This draft lets me commit the coming Monday–Sunday week any time before it starts. It does not require committing a full seven days before Monday. That is a product choice to confirm.

## Screens

1. **Today:** Show active fixed-service limits, end countdowns and today's local website time. Keep the old trial visibly distinct from committed enforcement.
2. **Lock:** Pick fixed services, one daily allowance for each, and an end day at midnight. Start now, show the exact end date, and require confirmation. The generic weekly planner is a later expansion.
3. **Report:** Generate a local report on demand, showing the past seven days by site and service. Track the named set (YouTube, Netflix, Facebook, Messenger, Instagram, Reddit, Quora) plus other visited sites, with a clear coverage status.
4. **Setup:** Install the required macOS component, verify that blocking works, and run a short test before the first real commitment. Clearly report if protection becomes inactive.

The usage prototype stores only hostnames, service names, browser names, day, time and session counts locally. It does not store full URLs or browsing content. Private/incognito tab access must be validated for each browser. When a tab cannot be observed, its time must be reported as missing, never inferred from an unrelated network flow. The filter denies a selected service if the sampler is missing or stale. Reliable reports while the app process is gone need a separate background helper; the login registration for the main app does not make reporting continuous if someone quits it.

## How enforcement could work

A SwiftUI app handles planning. A separate Swift policy engine checks schedules, budgets, and whether a change grants more access. A macOS Network Extension content filter is the proposed layer for blocking domains across browsers. A browser-aware usage adapter plus foreground and idle signals would count *active viewing time* for daily allowances. Network traffic alone cannot measure that. Apple's [content filter documentation](https://developer.apple.com/documentation/networkextension/content-filter-providers) and [filter data provider API](https://developer.apple.com/documentation/networkextension/nefilterdataprovider) are starting points; the behavior needs testing on a real Mac.

If WeekPact cannot measure a budgeted service in a particular browser, it should block that service there and explain why. The first version should store rules and usage locally. A later optional service could strengthen trusted time and authorization for weaker changes without collecting browsing history.

**Honest limit:** On a Mac I own and administer, I can ultimately disable software or erase the machine. WeekPact aims to withstand impulsive changes, ordinary app removal, browser switching, and rebooting where the macOS prototype proves it can. It must never claim that administrator or Recovery access is impossible to use. Clock changes, new domains, proxies, VPNs, and use on another device also need explicit coverage tests. If the clock becomes untrustworthy, keep the restriction in place until time can be verified.

## Build order

1. **Mac feasibility test:** Verify a signed filter can enforce a sample domain in Safari, Chrome, and Firefox; test reboot, extension disable, clock changes, and blocking an already open session. Check macOS permissions and signing requirements.
2. **Planner:** Build the weekly grid, chat-to-draft mapping, validator, review screen, and pure Swift policy engine. Never let generated text write directly to enforcement.
3. **Committed alpha:** Add the installed filter, policy persistence, carry-forward rules, and clear failure reporting. Ship daily allowances only after foreground counting and mid-session cutoffs are reliable.

**First milestone:** I can commit next week's block and time-window rules for arbitrary named services. The rules survive a reboot on validated browsers, and I cannot loosen them during the week. Daily allowances join this milestone only if their usage measurement passes the Mac feasibility test.
