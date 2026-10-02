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

print("\n\(checks) checks, \(failures) failures")
exit(failures == 0 ? 0 : 1)
