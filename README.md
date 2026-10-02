# TimeTool

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

1. Grab the latest `TimeTool-x.y.z.dmg` from [Releases](../../releases/latest)
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
./build.sh && open build/TimeTool.app
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
TimeTool, and click **Open Anyway**.

**Terminal**:

```bash
xattr -dr com.apple.quarantine /Applications/TimeTool.app
```

---

## First run

The app asks for calendar access on launch (full access). It reads event
**titles and start/end times** to work out the countdown, never goes online, and
never uploads anything. It never modifies or deletes any event you already have.
Once you grant access the countdown appears immediately.

Only if you turn on **Add focus sessions to Calendar** in the Focus tab of
Settings does the app add events: one event marked *Free* for each finished
focus session, in a new "Focus" calendar by default. Those events carry a
marker, so the countdown never mistakes them for your schedule.

### What about Google Calendar

You don't need to authorize Google, and you don't need to import a file.
Open **System Settings → Internet Accounts**, add your Google account, and
tick "Calendars." macOS syncs it into the system calendar, and this app
reads from there.

The same goes for iCloud, a school Exchange calendar, or any subscribed
`.ics` timetable. If it shows up in the system Calendar app, it works here.

### Focus and statistics

The bottom card of the stack is the **focus card**, a Pomodoro-style timer:
25 minutes of focus, a 5 minute break and a 15 minute long break by default,
with a long break after every 4 sessions. Four dots show your progress through
the round, and the button at the bottom right follows the state (Start, Pause,
Resume, Skip). You can't pause a break.

- Timing keeps running while the lid is closed or the Mac sleeps. If the lid
  stays closed for more than 15 minutes, that session ends at the moment you closed it
- If the app dies unexpectedly, the next launch records what it can, conservatively
- The chart icon on the card or in the pill opens the **statistics window**:
  day, week, month and year bar charts, total or daily average, compared with
  the previous period, with paging
- Only focus time is counted. Breaks aren't, and there are no counts or categories
- Records live in `~/Library/Application Support/com.carson.classcountdown/focus.json`

### Settings

Right-click the menu bar item and choose **Settings…**, or use the gear in the pill at the top right of the cards (or press
Command-comma). It is a regular window with four tabs:

- **General**: language (11, applied immediately), open at login; Appearance: Auto, Light or Dark, plus a *Glass* slider from clear, smooth glass to frosted; menu bar style
  (ring or badge), what to show, the separator, and whether to show the next event when idle
- **Calendars**: which calendars count; all-day events (off by default); the
  ending-soon alert (5 minutes by default)
- **Focus**: the three durations, two auto-start switches, keep the screen awake
  while focusing, a notification when a session ends, and *Add focus sessions to
  Calendar* with its target calendar
- **About**: version and quit

### Gestures

| Gesture | What happens |
| --- | --- |
| Click the menu bar item | The stack flies out of the icon; click again to send it back |
| Right-click the menu bar item | Open Calendar, Settings, About, Quit |
| Click a card | Expand the stack, click again to collapse |
| Drag any card (when expanded) | Move it within the stack; the order is remembered |
| Drag a card (when collapsed) | Place the whole stack anywhere on screen; it then stays open until you click the menu bar icon. Settings can put it back under the menu bar |
| Hover the small circle at a card's top right | It opens into an icon bar: focus, statistics, calendar, settings |
| Force click a card (trackpad) | The card sinks, Calendar opens, the panel retracts |

---

## What it deliberately doesn't do

- The countdown itself never notifies or rings; only the end of a focus session or a break sends one notification (optional)
- Records focus only: no categories, no counts
- Never edits or deletes an event you already have (with *Add focus sessions to Calendar* on, it only adds its own focus events)
- No network access at all

---

## Project layout

| File | Responsibility |
| --- | --- |
| `Sources/App.swift` | Entry point and app delegate |
| `Sources/PanelController.swift` | Status item, the transparent panel, show/hide animation |
| `Sources/DesignTokens.swift` | Every number the design settled on, plus the glass material |
| `Sources/CalendarService.swift` | EventKit wrapper: access, 48-hour window, change notifications |
| `Sources/ScheduleModel.swift` | State machine: which events are running, seconds left, progress |
| `Sources/CardStack.swift` | The popover: Wallet-style stack, expand, drag to reorder and to move |
| `Sources/Interaction.swift` | Click and force click on one card, in a single NSView |
| `Sources/Localization.swift` | Runtime string table, 11 languages, switches without a relaunch |
| `Sources/AppState.swift` | Shared holder for the services |
| `Sources/EventCard.swift` | One 340×160 card. Information only, no controls |
| `Sources/TickEngine.swift` | One-second heartbeat, drives display refresh only |
| `Sources/SettingsWindowController.swift` | The settings window: regular window, toolbar tabs, remembers position and size |
| `Sources/SettingsView.swift` | Contents of each settings tab |
| `Sources/AppWindowTracker.swift` | Switches to the regular activation policy while settings or statistics are open |
| `Sources/FlowCard.swift` | The focus card |
| `Sources/QuickPill.swift` | The pill at a card's top right |
| `Sources/GlassButton.swift` | Capsule button, icon button, the four dots |
| `Sources/FocusEngine.swift` | Focus state machine, pure logic, time injected by the caller |
| `Sources/FocusStore.swift` | JSON storage of focus records and crash recovery |
| `Sources/FocusController.swift` | Connects the engine to the tick, sleep and wake, storage, screen awake, notifications and Calendar |
| `Sources/FocusCalendarWriter.swift` | Writes focus sessions into Calendar, marked |
| `Sources/FocusCalendarMarker.swift` | The marker on those events, used to filter and de-duplicate |
| `Sources/FocusNotifier.swift` | End-of-session notifications |
| `Sources/ScreenAwake.swift` | Keep the screen awake while focusing |
| `Sources/StatsAggregator.swift` | Statistics aggregation, pure functions |
| `Sources/StatsView.swift`, `StatsWindowController.swift` | The statistics window |
| `Sources/BadgeIcon.swift`, `RingIcon.swift` | Menu bar badge and ring |
| `Sources/SettingsStore.swift` | Persisted user preferences |
| `Sources/LaunchAtLogin.swift` | Open-at-login toggle |
| `Sources/SystemBridges.swift` | Wake-from-sleep and time-zone change notifications |
| `Sources/TimeFormat.swift` | Countdown text formatting rules |
| `build.sh` | Compile and assemble the .app |
| `package.sh` | Package into a .dmg |
| `uninstall.sh` | Remove the app, its preferences and the login item |
| `test.sh` | Unit tests for the state machine, storage and statistics (`Tests/main.swift`, no full app needed) |

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
top and shows everything; the ones behind peek out 21pt below it, just enough
for their name and time left. Click to expand, scroll to bring another to the
front. The app menu lives on the menu bar item's right-click and in the pill at the top right of the cards.

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
