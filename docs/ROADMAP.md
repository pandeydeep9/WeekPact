# WeekPact build plan

## The product

A personal Mac app built by us. Select from **YouTube, Netflix, Facebook, Messenger, Instagram, Reddit, Quora**; choose **30 minutes, 1 hour, 2 hours, or 3 hours per day**; and choose the day whose **12:00 AM** ends the lock. The rule starts immediately. Daily time refills at local midnight; the commitment stays in force until its end date. The app shows time left, the next reset, the end countdown, and a local usage report on request.

**Success:** After I use YouTube for my chosen daily time, it becomes unavailable on my Mac through the rest of that day, including in private browsing. Quitting the UI or restarting the Mac does not reset it. The allowance returns at midnight; the rule ends only at the date I chose.

This is for one person on one Mac. No distribution setup, paid Apple membership, or other blocking app should be required for the chosen implementation. A Mac administrator can ultimately remove local controls; we will say exactly what the app withstands after testing it.

## What we know now

- The Today / Lock / Report app and fixed-service policy exist as prototypes. Usage is measured in the frontmost Safari/Chrome tab **only while the app runs**. The current locked mode depends on an Apple entitlement a free Personal Team cannot use.
- WeekPact's own `/etc/hosts` test blocked `example.com` in Chrome and removed the block after two minutes on Deep's Mac. The YouTube trial blocked a direct connection and Chrome showed its offline screen ([coverage #15](https://github.com/pandeydeep9/WeekPact/issues/15)). Deep reports inconsistent browser access while the trial is pending; playback and timing need a controlled check. Safari, private windows, other browsers, native apps, and reboot behavior remain unverified.
- A hosts-file block cannot itself measure time, cover every service hostname, or promise protection against private DNS and VPNs. It is an experiment, not proof of the finished lock.

## Building blocks

| Order | Block | Done when | Now |
| --- | --- | --- | --- |
| 1 | **Prove enforcement** | A two-minute YouTube block stops new and already-open access in the browsers/modes Deep uses, then expires correctly. Test reboot, app quit, DNS settings, and native clients. Decide the enforcement method from results; do not build a weekly lock on an unproven blocker. | Example.com in Chrome passed; YouTube Chrome offline screen observed ([#15](https://github.com/pandeydeep9/WeekPact/issues/15)). |
| 2 | **Measure daily use** | Foreground viewing time is counted once across supported browsers, private windows, idle/sleep, and service domains; unsupported cases are shown and do not silently get unlimited time. | Safari/Chrome app-open prototype. |
| 3 | **Make rules durable** | A confirmed rule and usage ledger survive UI quit and restart; selected sites, daily allowance, local midnight reset, and the exact end date are consistent. The UI cannot loosen an active rule. | Policy logic prototype; persistent helper incomplete. |
| 4 | **Connect time to blocking** | Each service works until its allowance is spent, then blocks promptly; midnight restores only that day's allowance. Test two services with different usage on the same day. | Not built. |
| 5 | **Finish the app** | One clear Today / Lock / Report flow: choices, confirmation, remaining time, reset/end countdowns, protection status, and on-demand local report. No Terminal commands for normal use. | UI/report prototypes. |
| 6 | **Personal installation and acceptance** | Install on Deep's Mac, restart, close/delete the UI, test Safari/Chrome/Firefox and private windows, already-open tabs, native apps, clock changes and recovery. Document any unsupported route before calling the lock ready. | Not built. |

**Decision gate after block 1:** If a free, WeekPact-owned local method cannot enforce the required coverage, stop calling the rule a hard lock. Record the failing cases and choose a viable enforcement/administrator setup before building blocks 3–4 around it.

**Later:** Chat-to-plan, weekly calendar editing, and arbitrary sites come after the fixed-service daily lock works. The earlier [design exploration](DESIGN.md) describes those ideas; this page is the current build order and acceptance contract.
