import Foundation

// 不依赖 XCTest 的小测试脚本，由 test.sh 与 FocusEngine.swift、FocusStore.swift 一起编译。

var failures = 0
var checks = 0

func expect(_ cond: Bool, _ msg: String, line: Int = #line) {
    checks += 1
    if !cond { failures += 1; print("FAIL (line \(line)): \(msg)") }
}

func test(_ name: String, _ body: () -> Void) {
    let before = failures
    body()
    print((failures == before ? "ok   " : "FAIL ") + name)
}

let t0 = Date(timeIntervalSince1970: 1_800_000_000)
func at(_ minutes: Double) -> Date { t0.addingTimeInterval(minutes * 60) }

test("开始后专注，满 25 分钟进入等待休息并记录完整块") {
    var e = FocusEngine()
    e.start(now: at(0))
    expect(e.state == .focusing, "start 后应为 focusing")
    e.tick(now: at(24))
    expect(e.state == .focusing, "24 分钟时仍在专注")
    e.tick(now: at(25))
    expect(e.state == .breakWaiting, "满 25 分钟进入 breakWaiting")
    let done = e.drainFinished()
    expect(done.count == 1 && done[0].isComplete && done[0].duration == 25 * 60, "记录一个完整的 25 分钟块")
    expect(done.first?.end == at(25), "正常结束记计划结束时间")
    expect(e.completedInRound == 1, "完成一节")
}

test("自动开始休息：直接进入休息，休息结束回到 idle") {
    var e = FocusEngine(config: FocusConfig(autoStartBreak: true))
    e.start(now: at(0))
    e.tick(now: at(25))
    expect(e.state == .breaking, "自动休息")
    expect(e.remaining(now: at(27)) == 3 * 60, "休息剩余 3 分钟")
    e.tick(now: at(30))
    expect(e.state == .idle, "休息结束回到 idle")
    expect(e.completedInRound == 1, "点数保留，等点击开始下一节")
}

test("休息不可暂停") {
    var e = FocusEngine(config: FocusConfig(autoStartBreak: true))
    e.start(now: at(0)); e.tick(now: at(25))
    e.pause(now: at(26))
    expect(e.state == .breaking, "休息中 pause 无效")
    var w = FocusEngine()
    w.start(now: at(0)); w.tick(now: at(25))
    w.pause(now: at(26))
    expect(w.state == .breakWaiting, "等待休息时 pause 无效")
}

test("暂停与继续：专注时长不含暂停") {
    var e = FocusEngine()
    e.start(now: at(0))
    e.pause(now: at(10))
    expect(e.state == .focusPaused, "进入暂停")
    e.tick(now: at(60))
    expect(e.state == .focusPaused, "暂停期间 tick 不推进")
    expect(e.remaining(now: at(60)) == 15 * 60, "暂停时剩余 15 分钟")
    e.resume(now: at(20))
    e.tick(now: at(34))
    expect(e.state == .focusing, "还差 1 分钟")
    e.tick(now: at(35))
    expect(e.state == .breakWaiting, "继续后再做满 15 分钟结束")
    let done = e.drainFinished()
    expect(done.count == 1 && done[0].duration == 25 * 60, "专注 25 分钟，不含暂停的 10 分钟")
}

test("重置：记录已做的部分，点数清零，已有记录保留") {
    var e = FocusEngine()
    e.start(now: at(0)); e.tick(now: at(25))   // 先做满一节
    _ = e.drainFinished()
    e.skipBreak(now: at(26))
    e.start(now: at(26))
    e.start(now: at(27))                        // 专注中重复 start 无副作用
    expect(e.remaining(now: at(27)) == 24 * 60, "重复 start 不重置计时")
    e.reset(now: at(36))
    expect(e.state == .idle && e.completedInRound == 0, "回到 idle 且点数清零")
    let done = e.drainFinished()
    expect(done.count == 1 && done[0].duration == 10 * 60 && !done[0].isComplete, "按手动停止记 10 分钟")
    expect(done.first?.end == at(36), "手动停止记点击时刻")
}

test("第 4 节之后进入长休息，长休息结束回到 idle 且点数清零") {
    var e = FocusEngine()
    var now = 0.0
    for i in 1...4 {
        e.start(now: at(now)); now += 25
        e.tick(now: at(now))
        if i < 4 {
            expect(e.state == .breakWaiting, "第 \(i) 节后是短休息")
            e.start(now: at(now)); now += 5
            e.tick(now: at(now))
            expect(e.state == .idle, "短休息结束回 idle")
        }
    }
    expect(e.state == .longBreakWaiting, "第 4 节后是长休息等待")
    expect(e.completedInRound == 4, "四个点满")
    e.start(now: at(now))
    expect(e.state == .longBreaking, "长休息中")
    expect(e.remaining(now: at(now + 5)) == 10 * 60, "长休息 15 分钟")
    e.tick(now: at(now + 15))
    expect(e.state == .idle && e.completedInRound == 0, "长休息结束回到 idle，点数清零")
    expect(e.drainFinished().count == 4, "共记录 4 个专注块")
}

test("跳过休息") {
    var e = FocusEngine()
    e.start(now: at(0)); e.tick(now: at(25))
    e.start(now: at(26))
    e.skipBreak(now: at(27))
    expect(e.state == .idle && e.completedInRound == 1, "跳过短休息回 idle，点数保留")
    var l = FocusEngine(config: FocusConfig(cyclesPerRound: 1))
    l.start(now: at(0)); l.tick(now: at(25))
    expect(l.state == .longBreakWaiting, "一节一轮则直接长休息")
    l.skipBreak(now: at(26))
    expect(l.state == .idle && l.completedInRound == 0, "跳过长休息点数清零")
}

test("一次心跳跨过多个状态") {
    var e = FocusEngine(config: FocusConfig(autoStartBreak: true, autoStartFocus: true))
    e.start(now: at(0))
    e.tick(now: at(70))   // 25 专注 + 5 休息 + 25 专注 + 5 休息 + 10 分钟进入第三节
    expect(e.state == .focusing, "第三节进行中")
    expect(e.completedInRound == 2, "完成两节")
    expect(e.remaining(now: at(70)) == 15 * 60, "第三节剩余 15 分钟")
    expect(e.drainFinished().count == 2, "补记两个专注块")
}

test("合盖不超过 15 分钟：计时继续") {
    var e = FocusEngine()
    e.start(now: at(0))
    e.willSleep(now: at(5))
    e.didWake(now: at(20))     // 睡了 15 分钟整，不算超过
    expect(e.state == .focusing, "恰好 15 分钟仍继续")
    expect(e.remaining(now: at(20)) == 5 * 60, "睡眠时间照常计入")
    e.tick(now: at(25))
    expect(e.drainFinished().first?.isComplete == true, "正常做满")
}

test("合盖超过 15 分钟：专注在合盖那一刻结束") {
    var e = FocusEngine()
    e.start(now: at(0))
    e.willSleep(now: at(5))
    e.didWake(now: at(21))     // 睡了 16 分钟
    expect(e.state == .idle, "回到 idle")
    let done = e.drainFinished()
    expect(done.count == 1 && done[0].end == at(5) && done[0].duration == 5 * 60 && !done[0].isComplete,
           "记到合盖那一刻，5 分钟，不完整")
    expect(e.completedInRound == 0, "不完整的块不算一节")
}

test("休息期间睡眠不受 15 分钟规则影响") {
    var e = FocusEngine(config: FocusConfig(autoStartBreak: true))
    e.start(now: at(0)); e.tick(now: at(25))
    e.willSleep(now: at(26))
    e.didWake(now: at(120))
    expect(e.state == .idle, "休息按时钟走完，回到 idle")
}

test("睡眠期间专注自然做满且睡眠不超过阈值") {
    var e = FocusEngine()
    e.start(now: at(0))
    e.willSleep(now: at(20))
    e.didWake(now: at(30))
    expect(e.state == .breakWaiting, "醒来时专注已结束")
    expect(e.drainFinished().first?.end == at(25), "结束时间是计划结束时间")
}

test("快照与意外退出补记") {
    var e = FocusEngine()
    e.start(now: at(0))
    e.pause(now: at(10))
    guard let snap = e.snapshot(now: at(12)) else { expect(false, "进行中应有快照"); return }
    expect(snap.focusedAtLastKnown == 10 * 60, "暂停后快照不再累计")
    let block = FocusEngine.recoveredBlock(from: snap)
    expect(block?.duration == 10 * 60 && block?.isComplete == false, "补记 10 分钟，不完整")
    expect(block?.end == at(12), "结束时间取上次已知时间")

    var full = snap
    full.focusedAtLastKnown = 40 * 60
    expect(FocusEngine.recoveredBlock(from: full)?.duration == 25 * 60, "不超过计划时长")
    expect(FocusEngine.recoveredBlock(from: full)?.isComplete == true, "做满则完整")
    var none = snap
    none.focusedAtLastKnown = 0.3
    expect(FocusEngine.recoveredBlock(from: none) == nil, "不足 1 秒不记")

    var idle = FocusEngine()
    expect(idle.snapshot(now: at(0)) == nil, "idle 没有快照")
    idle.start(now: at(0)); idle.tick(now: at(25))
    expect(idle.snapshot(now: at(26)) == nil, "休息中没有快照")
}

test("进度方向：专注增长，休息收缩") {
    var e = FocusEngine(config: FocusConfig(autoStartBreak: true))
    e.start(now: at(0))
    expect(abs(e.progress(now: at(5)) - 0.2) < 1e-9, "专注 5/25")
    e.tick(now: at(25))
    expect(abs(e.progress(now: at(26)) - 0.8) < 1e-9, "休息剩余 4/5")
}

test("FocusStore 读写、去重与补记") {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("timetool-test-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dir) }

    var e = FocusEngine()
    e.start(now: at(0)); e.tick(now: at(25))
    let block = e.drainFinished()[0]

    let store = FocusStore(directory: dir)
    store.append(block)
    store.append(block)
    expect(store.blocks.count == 1, "同一个块只记一次")

    e.start(now: at(30)); e.start(now: at(30))
    e.skipBreak(now: at(30)); e.start(now: at(31))
    let snap = e.snapshot(now: at(40))
    expect(snap != nil, "第二块进行中有快照")
    store.setPending(snap)

    let reopened = FocusStore(directory: dir)
    expect(reopened.blocks == [block], "重新打开后记录还在")
    expect(reopened.pending == snap, "快照也在")
    let recovered = reopened.recoverPending()
    expect(recovered?.duration == 9 * 60, "补记 9 分钟")
    expect(reopened.pending == nil && reopened.blocks.count == 2, "补记后清掉快照")
    expect(FocusStore(directory: dir).blocks.count == 2, "补记已落盘")
}

// MARK: 统计聚合

func utcCalendar(firstWeekday: Int = 2) -> Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    c.firstWeekday = firstWeekday
    return c
}

func utc(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
    let c = utcCalendar()
    return c.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
}

func block(_ start: Date, minutes: Double) -> FocusBlock {
    FocusBlock(id: UUID(), start: start, end: start.addingTimeInterval(minutes * 60),
               duration: minutes * 60, isComplete: true)
}

test("统计：周按周一起算，7 个桶，按开始时间归日") {
    let cal = utcCalendar(firstWeekday: 2)
    // 2026-09-28 是周一
    let blocks = [
        block(utc(2026, 9, 28, 9), minutes: 25),
        block(utc(2026, 9, 29, 23, 50), minutes: 25),    // 跨午夜，算周二
        block(utc(2026, 9, 29, 10), minutes: 25),
        block(utc(2026, 10, 5, 9), minutes: 25)          // 下一周
    ]
    let s = StatsAggregator.snapshot(blocks: blocks, period: .week, metric: .total,
                                     anchor: utc(2026, 10, 1), now: utc(2026, 10, 2), calendar: cal)
    expect(s.buckets.count == 7, "周有 7 个桶")
    expect(s.rangeStart == utc(2026, 9, 28), "周起点是周一")
    expect(s.buckets[0].seconds == 25 * 60, "周一 25 分钟")
    expect(s.buckets[1].seconds == 50 * 60, "周二 50 分钟，含跨午夜的那块")
    expect(s.value == 75 * 60, "总时长 75 分钟")
    let sun = StatsAggregator.snapshot(blocks: blocks, period: .week, metric: .total,
                                       anchor: utc(2026, 10, 1), now: utc(2026, 10, 2),
                                       calendar: utcCalendar(firstWeekday: 1))
    expect(sun.rangeStart == utc(2026, 9, 27), "周起始跟随区域设置：周日起算")
}

test("统计：日 24 桶，月按日，年 12 桶") {
    let cal = utcCalendar()
    let blocks = [block(utc(2026, 10, 2, 9, 30), minutes: 25), block(utc(2026, 10, 2, 14), minutes: 40)]
    let d = StatsAggregator.snapshot(blocks: blocks, period: .day, metric: .total,
                                     anchor: utc(2026, 10, 2, 12), now: utc(2026, 10, 2, 20), calendar: cal)
    expect(d.buckets.count == 24 && d.buckets[9].seconds == 25 * 60 && d.buckets[14].seconds == 40 * 60, "日按小时")
    let m = StatsAggregator.snapshot(blocks: blocks, period: .month, metric: .total,
                                     anchor: utc(2026, 10, 15), now: utc(2026, 10, 20), calendar: cal)
    expect(m.buckets.count == 31 && m.buckets[1].seconds == 65 * 60, "10 月 31 天，2 号 65 分钟")
    let y = StatsAggregator.snapshot(blocks: blocks, period: .year, metric: .total,
                                     anchor: utc(2026, 6, 1), now: utc(2026, 10, 20), calendar: cal)
    expect(y.buckets.count == 12 && y.buckets[9].seconds == 65 * 60, "年按月，10 月 65 分钟")
}

test("统计：空数据与上一周期对比") {
    let cal = utcCalendar()
    let empty = StatsAggregator.snapshot(blocks: [], period: .week, metric: .total,
                                         anchor: utc(2026, 10, 1), now: utc(2026, 10, 2), calendar: cal)
    expect(empty.value == 0 && empty.delta == nil && empty.buckets.allSatisfy { $0.seconds == 0 }, "空数据为 0，没有变化比例")
    let blocks = [block(utc(2026, 9, 22, 9), minutes: 50), block(utc(2026, 9, 29, 9), minutes: 130)]
    let s = StatsAggregator.snapshot(blocks: blocks, period: .week, metric: .total,
                                     anchor: utc(2026, 10, 1), now: utc(2026, 10, 2), calendar: cal)
    expect(abs((s.delta ?? 0) - 1.6) < 1e-9, "130 对 50 分钟，涨 160%")
}

test("统计：日均按已过去的天数算") {
    let cal = utcCalendar()
    let blocks = [block(utc(2026, 9, 28, 9), minutes: 60), block(utc(2026, 9, 29, 9), minutes: 60)]
    // 周三 (9/30) 查看本周：已过 3 天（周一二三）
    let cur = StatsAggregator.snapshot(blocks: blocks, period: .week, metric: .dailyAverage,
                                       anchor: utc(2026, 9, 30), now: utc(2026, 9, 30, 12), calendar: cal)
    expect(abs(cur.value - 2400) < 1e-9, "120 分钟 / 3 天 = 40 分钟")
    // 回头看已结束的一周：除以 7
    let past = StatsAggregator.snapshot(blocks: blocks, period: .week, metric: .dailyAverage,
                                        anchor: utc(2026, 9, 30), now: utc(2026, 10, 10), calendar: cal)
    expect(abs(past.value - 120 * 60 / 7) < 1e-6, "过去的周除以 7")
}

test("统计：翻页边界") {
    let cal = utcCalendar()
    let now = utc(2026, 10, 2, 12)
    expect(!StatsAggregator.canGoNext(anchor: now, period: .week, now: now, calendar: cal), "当前周不能翻下一页")
    expect(StatsAggregator.canGoNext(anchor: utc(2026, 9, 24), period: .week, now: now, calendar: cal), "上一周可以")
    let prev = StatsAggregator.shifted(now, period: .month, by: -1, calendar: cal)
    expect(prev == utc(2026, 9, 2, 12), "上一个月")
}

test("统计：友好刻度") {
    func h(_ x: Double) -> Double { x * 3600 }
    expect(StatsAggregator.niceStep(maxSeconds: 0) == h(0.25), "空图最小步长")
    expect(StatsAggregator.niceStep(maxSeconds: 25 * 60) == h(0.25), "25 分钟，3 × 15 分钟够了")
    expect(StatsAggregator.niceStep(maxSeconds: 50 * 60) == h(0.5), "50 分钟用半小时步长")
    expect(StatsAggregator.niceStep(maxSeconds: h(5.2)) == h(2), "5.2 小时用 2 小时步长")
    expect(StatsAggregator.niceStep(maxSeconds: h(6)) == h(2), "刚好 6 小时")
    expect(StatsAggregator.niceStep(maxSeconds: h(6.1)) == h(3), "6.1 小时用 3 小时")
    expect(StatsAggregator.niceStep(maxSeconds: h(160)) == h(100) , "超出表后按 1/2/2.5/5 乘十的幂")
}

test("日历标记：能识别自己写入的专注事件，也能取回记录 ID") {
    let b = block(utc(2026, 10, 2, 9), minutes: 25)
    let notes = FocusCalendarMarker.notes(for: b)
    expect(FocusCalendarMarker.isOurs(notes: notes), "带标记的是自己的")
    expect(FocusCalendarMarker.blockID(from: notes) == b.id, "能取回记录 ID")
    expect(!FocusCalendarMarker.isOurs(notes: "EK 210 Lab"), "普通日程不是")
    expect(!FocusCalendarMarker.isOurs(notes: nil), "没有备注不是")
    expect(FocusCalendarMarker.blockID(from: "用户自己写的备注\n" + notes + "\n后面还有字") == b.id,
           "标记前后有别的文字也能识别")
}

print("\n\(checks) checks, \(failures) failures")
exit(failures == 0 ? 0 : 1)
