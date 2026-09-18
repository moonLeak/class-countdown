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

## Requirements

macOS 26 or later. The card material uses the system Liquid Glass effect,
which does not exist on earlier versions.

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

macOS 26 or later, and the Xcode Command Line Tools:

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

Right-click anywhere on the card and choose **Settings…**:

- **Language** — the app's own interface, in 11 languages. Event titles always
  stay in whatever the calendar says. Takes effect immediately, no relaunch
- **Calendars** — which calendars count toward the countdown (e.g. keep your
  class schedule, drop birthdays and holidays)
- **All-day events** — off by default, otherwise "Birthday" would occupy a
  whole day
- **Menu bar** — name and time left, or time only, and the separator between
  them (presets or your own, with a live preview)
- **Ending soon alert** — how much time left before the bar turns orange,
  5 minutes by default
- **Open at login**

### Gestures

| Gesture | What happens |
| --- | --- |
| Click the menu bar item | The stack flies out of the icon; click again to send it back |
| Click a card | Expand the stack, click again to collapse |
| Right-click a card | Open Calendar, Settings, About, Quit |
| Force click a card (trackpad) | The card sinks, Calendar opens, the panel retracts |

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
| `Sources/App.swift` | Entry point and app delegate |
| `Sources/PanelController.swift` | Status item, the transparent panel, show/hide animation, settings window |
| `Sources/DesignTokens.swift` | Every number the design settled on, plus the glass material |
| `Sources/CalendarService.swift` | EventKit wrapper: access, 48-hour window, change notifications |
| `Sources/ScheduleModel.swift` | State machine: which events are running, seconds left, progress |
| `Sources/CardStack.swift` | The popover: Wallet-style stack, expand, context menu |
| `Sources/Interaction.swift` | Click and force click on one card, in a single NSView |
| `Sources/Localization.swift` | Runtime string table, 11 languages, switches without a relaunch |
| `Sources/AppState.swift` | Shared holder for the services |
| `Sources/CountdownCard.swift` | One 340×160 card. Information only, no controls |
| `Sources/TickEngine.swift` | One-second heartbeat, drives display refresh only |
| `Sources/SettingsView.swift` | Settings panel |
| `Sources/TimeFormat.swift` | Countdown text formatting rules |
| `build.sh` | Compile and assemble the .app |
| `package.sh` | Package into a .dmg |
| `uninstall.sh` | Remove the app, its preferences and the login item |

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

**Overlapping events stack like cards in Wallet.** Each event is one card, so
nothing is summarised away into a line of small print. The front card sits on
top and shows everything; the ones behind peek out 40pt below it, just enough
for their name and percentage. Click to expand, scroll to bring another to the
front, right-click for the app menu.

**The progress bar takes its colour from the event's calendar.** Orange is
reserved for the closing-minutes warning, which is why the warning also raises
the fill opacity — a calendar that happens to be orange still reads as changed.

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
