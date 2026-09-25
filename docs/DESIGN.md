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
- Drafts can be edited. Committing freezes the week's maximum access. A change that only reduces access takes effect immediately.
- A weaker change is scheduled for **at least seven days later** and cannot alter an already committed week. Show its earliest effective date before accepting it.
- If no new plan is committed, carry forward the current restrictions. Never revert to unlimited access by omission.
- A rule can block a service, set available hours, set a daily allowance, or combine hours and an allowance. Groups of sites may share one allowance. When rules overlap, the stricter result applies.
- The app treats a change as “stricter” only if it grants no additional access across domains, hours, and allowances. Ambiguous changes are queued for later.

**Planning cutoff to decide:** This draft lets me commit the coming Monday–Sunday week any time before it starts. It does not require committing a full seven days before Monday. That is a product choice to confirm.

## Screens

1. **Plan:** Type a request or edit a weekly grid. The chat proposes concrete rules; it never commits them. Ask follow-up questions for phrases such as “after dinner” or “social media.”
2. **Review:** Show the actual dates, time zone, limits, domains covered, and any unsupported coverage. A deterministic validator checks the proposed rules. Commitment requires an explicit confirmation.
3. **This week:** Show access status and time remaining. Offer “Tighten now” and “Request a later change,” with the earliest effective date visible.
4. **Setup:** Install the required macOS component, verify that blocking works, and run a short test before the first real commitment. Clearly report if protection becomes inactive.

## How enforcement could work

A SwiftUI app handles planning. A separate Swift policy engine checks schedules, budgets, and whether a change grants more access. A macOS Network Extension content filter is the proposed layer for blocking domains across browsers. A browser-aware usage adapter plus foreground and idle signals would count *active viewing time* for daily allowances. Network traffic alone cannot measure that. Apple's [content filter documentation](https://developer.apple.com/documentation/networkextension/content-filter-providers) and [filter data provider API](https://developer.apple.com/documentation/networkextension/nefilterdataprovider) are starting points; the behavior needs testing on a real Mac.

If WeekPact cannot measure a budgeted service in a particular browser, it should block that service there and explain why. The first version should store rules and usage locally. A later optional service could strengthen trusted time and authorization for weaker changes without collecting browsing history.

**Honest limit:** On a Mac I own and administer, I can ultimately disable software or erase the machine. WeekPact aims to withstand impulsive changes, ordinary app removal, browser switching, and rebooting where the macOS prototype proves it can. It must never claim that administrator or Recovery access is impossible to use. Clock changes, new domains, proxies, VPNs, and use on another device also need explicit coverage tests. If the clock becomes untrustworthy, keep the restriction in place until time can be verified.

## Build order

1. **Mac feasibility test:** Verify a signed filter can enforce a sample domain in Safari, Chrome, and Firefox; test reboot, extension disable, clock changes, and blocking an already open session. Check macOS permissions and signing requirements.
2. **Planner:** Build the weekly grid, chat-to-draft mapping, validator, review screen, and pure Swift policy engine. Never let generated text write directly to enforcement.
3. **Committed alpha:** Add the installed filter, policy persistence, carry-forward rules, and clear failure reporting. Ship daily allowances only after foreground counting and mid-session cutoffs are reliable.

**First milestone:** I can commit next week's block and time-window rules for arbitrary named services. The rules survive a reboot on validated browsers, and I cannot loosen them during the week. Daily allowances join this milestone only if their usage measurement passes the Mac feasibility test.
