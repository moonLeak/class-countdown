import Foundation
import EventKit

/// 把完成的专注块写进系统日历。
///
/// 只写 macOS 日历库（EventKit），再由目标日历所属的账号同步到云端。
/// 事件标记为空闲，不占用忙闲，notes 里带固定前缀与记录 ID，用来识别和去重。
@MainActor
final class FocusCalendarWriter {

    private let store = EKEventStore()

    enum Result: Equatable {
        case written
        case skipped(String)
        case failed(String)
    }

    /// 写一个专注块。calendarID 为空表示还没选，会新建一个专注日历并回传它的 ID。
    @discardableResult
    func write(_ block: FocusBlock, title: String, calendarID: String,
               newCalendarTitle: String) -> (result: Result, calendarID: String) {
        // 模拟模式下不碰真实日历
        guard CalendarService.mockPath == nil else { return (.skipped("mock"), calendarID) }
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
            return (.skipped("no full access"), calendarID)
        }
        guard let cal = resolveCalendar(id: calendarID, newTitle: newCalendarTitle) else {
            return (.failed("no writable calendar"), calendarID)
        }

        // 同一个块只写一次
        if alreadyWritten(block, in: cal) { return (.skipped("exists"), cal.calendarIdentifier) }

        let ev = EKEvent(eventStore: store)
        ev.calendar = cal
        ev.title = title
        ev.startDate = block.start
        ev.endDate = block.end
        ev.availability = .free
        ev.notes = FocusCalendarMarker.notes(for: block)
        do {
            try store.save(ev, span: .thisEvent, commit: true)
            return (.written, cal.calendarIdentifier)
        } catch {
            return (.failed(error.localizedDescription), cal.calendarIdentifier)
        }
    }

    /// 可选作目标的日历：必须能写。订阅日历与生日日历只读，不会出现在这里。
    func writableCalendars() -> [EKCalendar] {
        store.calendars(for: .event).filter { $0.allowsContentModifications }
    }

    // MARK: 内部

    private func resolveCalendar(id: String, newTitle: String) -> EKCalendar? {
        if !id.isEmpty, let c = store.calendar(withIdentifier: id), c.allowsContentModifications {
            return c
        }
        return createCalendar(title: newTitle)
    }

    /// 在哪个账号下新建：先试默认日历所在的账号，不行（例如 Google 账号常不允许）
    /// 再依次试 iCloud、本地。
    private func createCalendar(title: String) -> EKCalendar? {
        var sources: [EKSource] = []
        if let s = store.defaultCalendarForNewEvents?.source { sources.append(s) }
        let rest = store.sources.filter { s in !sources.contains(where: { $0.sourceIdentifier == s.sourceIdentifier }) }
        sources += rest.filter { $0.sourceType == .calDAV }
        sources += rest.filter { $0.sourceType == .local }

        for source in sources {
            let cal = EKCalendar(for: .event, eventStore: store)
            cal.title = title
            cal.source = source
            if (try? store.saveCalendar(cal, commit: true)) != nil { return cal }
        }
        return nil
    }

    private func alreadyWritten(_ block: FocusBlock, in cal: EKCalendar) -> Bool {
        let predicate = store.predicateForEvents(
            withStart: block.start.addingTimeInterval(-60),
            end: block.end.addingTimeInterval(60), calendars: [cal])
        return store.events(matching: predicate).contains {
            FocusCalendarMarker.blockID(from: $0.notes) == block.id
        }
    }
}
