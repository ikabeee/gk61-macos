import GK61Core
import Synchronization

/// In-memory keyboard: records every sent payload and answers it with `reply`, if any.
final class FakeKeyboard: KeyboardTransport {
    let incomingReports: AsyncStream<[UInt8]>
    var sentPayloads: [[UInt8]] { sent.withLock { $0 } }

    private let continuation: AsyncStream<[UInt8]>.Continuation
    private let reply: @Sendable ([UInt8]) -> [UInt8]?
    private let sent = Mutex<[[UInt8]]>([])

    init(reply: @escaping @Sendable ([UInt8]) -> [UInt8]? = { _ in nil }) {
        (incomingReports, continuation) = AsyncStream.makeStream(of: [UInt8].self)
        self.reply = reply
    }

    func send(_ payload: [UInt8]) throws {
        sent.withLock { $0.append(payload) }
        if let answer = reply(payload) { continuation.yield(answer) }
    }
}
