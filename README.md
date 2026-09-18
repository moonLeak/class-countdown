# ClassCountdown

**English** · [简体中文](README.zh-CN.md)

A macOS menu bar app that reads your calendar and shows
**how much longer the thing you're currently in has left**.

During a lecture, a meeting, or a lab session, what you actually want to know
isn't "10:10 to 12:00" — it's "how much longer." That's all this does.

The menu bar shows one line, `EK 210 Lab · 23:47`. Click it and you get a
square card whose background is a horizontal progress bar that empties as
your event runs out.

---

## Install

### Option 1: Download the DMG (recommended)

1. Grab the latest `ClassCountdown-x.y.z.dmg` from [Releases](../../releases/latest)
2. Open it and drag the app into your Applications folder
3. **macOS will block it the first time.** See "Why won't it open" below.

### Option 2: Homebrew

```bash
brew tap moonLeak/class-countdown https://github.com/moonLeak/class-countdown
brew install --cask --no-quarantine class-countdown
```

`--no-quarantine` is not optional here — without it the app won't launch.

### Option 3: Build it yourself

All you need is the Xcode Command Line Tools:

```bash
git clone https://github.com/moonLeak/class-countdown.git
cd class-countdown
./build.sh && open build/ClassCountdown.app
```

---

## Why won't it open

macOS blocks apps that haven't been notarized by Apple, with a message like
"cannot be opened because the developer cannot be verified," or sometimes
the misleading "app is damaged."

Notarization requires a $99/year Apple Developer account. This is a free
utility, so it doesn't have one. **Nothing is wrong with the app** — the
source is right here in this repo, and you're welcome to read it and build
it yourself.

Two ways through, pick either:

**GUI**: open the app once (it fails), then go to
**System Settings → Privacy & Security**, scroll down to the message about
ClassCountdown, and click **Open Anyway**.

**Terminal**:

```bash
xattr -dr com.apple.quarantine /Applications/ClassCountdown.app
```

---

## First run

The app asks for calendar access on launch. It reads only event **titles and
start/end times**. It never modifies an event, never goes online, and never
uploads anything. Once you grant access the countdown appears immediately.

### What about Google Calendar

You don't need to authorize Google, and you don't need to import a file.
Open **System Settings → Internet Accounts**, add your Google account, and
tick "Calendars." macOS syncs it into the system calendar, and this app
reads from there.

The same goes for iCloud, a school Exchange calendar, or any subscribed
`.ics` timetable. If it shows up in the system Calendar app, it works here.

### Settings

Click the menu bar item, then the gear in the card's bottom-left corner:

- **Calendars** — which calendars count toward the countdown (e.g. keep your
  class schedule, drop birthdays and holidays)
- **All-day events** — off by default, otherwise "Birthday" would occupy a
  whole day
- **Warning color** — how much time left before the digits and bar change
  color, 5 minutes by default
- **Launch at login**

---

## What it deliberately doesn't do

- No notifications, no alarms, no interruptions
- No history, no time tracking, no stats
- Never creates, edits, or deletes an event
- No network access at all

---

## Project layout

| File | Responsibility |
| --- | --- |
| `Sources/App.swift` | Entry point, MenuBarExtra scene, the menu bar line |
| `Sources/CalendarService.swift` | EventKit wrapper: access, 48-hour window, change notifications |
| `Sources/ScheduleModel.swift` | State machine: which event is "current," seconds left, progress |
| `Sources/TickEngine.swift` | One-second heartbeat, drives display refresh only |
| `Sources/CountdownCard.swift` | The 280pt square card |
| `Sources/SettingsView.swift` | Settings panel |
| `Sources/TimeFormat.swift` | Countdown text formatting rules |
| `build.sh` | Compile and assemble the .app |
| `package.sh` | Package into a .dmg |

### A few design decisions

**Two independent refresh paths.** Calendar data changes come from
`EKEventStoreChanged`, plus a 15-minute backstop poll and a re-fetch on wake.
The countdown digits run off `TickEngine`. Merge the two and you end up
querying the calendar store once a second.

**All arithmetic uses `Date`** (absolute UTC instants), converting to local
time only at render. Time zone changes and DST transitions can't corrupt the
math.

**After sleep, nothing relies on an accumulated timer value** — the app
recomputes from the current time.

**Overlapping events resolve to whichever ends first**, since that's the one
that actually releases you. The card notes how many others overlap.

**Recurring events come from `enumerateEvents`**, already expanded into
instances. Not parsing RRULE by hand is the main reason this uses EventKit
rather than reading `.ics` files directly.

---

## Roadmap

- [ ] iOS / iPadOS widgets (home screen and Today view)
- [ ] Manual `.ics` import
- [ ] Lock screen Live Activity

---

## License

MIT
