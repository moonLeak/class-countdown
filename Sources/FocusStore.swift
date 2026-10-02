import Foundation

/// 专注记录的本地存储。一个 JSON 文件，放在
/// ~/Library/Application Support/<bundle id>/focus.json。
/// 同时存一份进行中专注块的快照，用于意外退出后补记。
final class FocusStore {

    private struct Payload: Codable {
        var blocks: [FocusBlock] = []
        var pending: FocusSnapshot?
    }

    private let fileURL: URL
    private var payload = Payload()

    var blocks: [FocusBlock] { payload.blocks }
    var pending: FocusSnapshot? { payload.pending }

    /// directory 默认指向 Application Support 下以 bundle id 命名的目录，单测里传临时目录
    init(directory: URL? = nil) {
        let dir = directory ?? Self.defaultDirectory()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("focus.json")
        load()
    }

    static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
        let id = Bundle.main.bundleIdentifier ?? "TimeTool"
        return base.appendingPathComponent(id, isDirectory: true)
    }

    func append(_ block: FocusBlock) {
        // 同一个块只记一次，补记与正常结束撞上时以先到的为准
        guard !payload.blocks.contains(where: { $0.id == block.id }) else { return }
        payload.blocks.append(block)
        save()
    }

    func setPending(_ snapshot: FocusSnapshot?) {
        payload.pending = snapshot
        save()
    }

    /// 启动时调用：有残留快照就补记成一个未必完整的专注块，并清掉快照
    @discardableResult
    func recoverPending() -> FocusBlock? {
        guard let s = payload.pending else { return nil }
        payload.pending = nil
        if let block = FocusEngine.recoveredBlock(from: s) {
            if !payload.blocks.contains(where: { $0.id == block.id }) {
                payload.blocks.append(block)
            }
            save()
            return block
        }
        save()
        return nil
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let p = try? decoder.decode(Payload.self, from: data) { payload = p }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(payload) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
