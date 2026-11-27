/// Product signature the firmware reports; the Windows driver checks it against Cfg `PSD`.
public struct PSD: Equatable, Sendable {
    public let first: UInt8
    public let second: UInt8

    public init(_ first: UInt8, _ second: UInt8) {
        self.first = first
        self.second = second
    }
}

public enum KeyboardSessionError: Error, Equatable {
    case noAcknowledgement(command: UInt8)
}

/// Sends commands one at a time and waits for the reply whose first byte echoes the command.
public actor KeyboardSession {
    private let transport: KeyboardTransport
    private let acknowledgementTimeout: Duration
    private let pauseAfterChunk: Duration
    private let pauseAfterOperation: Duration
    private var pendingReply: PendingReply?
    private var lastExchangeID = 0
    private var listener: Task<Void, Never>?

    /// Defaults match the Windows driver: about 2 s per acknowledgement, 30 ms between chunks,
    /// up to 100 ms between the operations of one Apply.
    public init(
        transport: KeyboardTransport,
        acknowledgementTimeout: Duration = .seconds(2),
        pauseAfterChunk: Duration = .milliseconds(30),
        pauseAfterOperation: Duration = .milliseconds(100)
    ) {
        self.transport = transport
        self.acknowledgementTimeout = acknowledgementTimeout
        self.pauseAfterChunk = pauseAfterChunk
        self.pauseAfterOperation = pauseAfterOperation
    }

    deinit {
        listener?.cancel()
    }

    public func readPSD() async throws -> PSD {
        let reply = try await exchange(.getPSD)
        return PSD(reply[4], reply[5])
    }

    /// Writes the normal-layer key matrix, then the Fn layer on its defaults: the firmware ignores
    /// the normal table until the Fn table follows, so Apply always sends both, like the Windows driver.
    /// Keys missing from `actions` revert to the firmware default. Macro keys first get their macros uploaded.
    public func applyKeymap(_ layout: KeyLayout, actions: [Int: KeyAction]) async throws {
        try await uploadMacros(MacroBuffer.assign(layout, actions: actions))
        try await sendOperation(Packet.keyMatrix(layout, actions: actions))
        try await sendChunks(Packet.defaultFnKeyMatrix(layout))
    }

    public func applyLighting(_ lighting: Lighting) async throws {
        try await sendChunks(Packet.lighting(lighting))
    }

    /// Like the Windows driver, sends no macro command at all when no key plays a macro.
    private func uploadMacros(_ buffers: [MacroBuffer]) async throws {
        guard !buffers.isEmpty else { return }
        try await sendOperation([.freeMacroBuffers])
        for buffer in buffers {
            try await sendOperation(Packet.macroUpload(buffer.macro, bufferID: buffer.id))
        }
    }

    private func sendOperation(_ packets: [Packet]) async throws {
        try await sendChunks(packets)
        try await Task.sleep(for: pauseAfterOperation)
    }

    private func sendChunks(_ packets: [Packet]) async throws {
        for packet in packets {
            _ = try await exchange(packet)
            try await Task.sleep(for: pauseAfterChunk)
        }
    }

    private func exchange(_ packet: Packet) async throws -> [UInt8] {
        startListeningIfNeeded()
        lastExchangeID += 1
        let exchangeID = lastExchangeID
        return try await withCheckedThrowingContinuation { continuation in
            // Registered before sending: the device may answer before `send` returns.
            pendingReply = PendingReply(id: exchangeID, command: packet.command, continuation: continuation)
            do {
                try transport.send(packet.bytes)
                expireReply(of: exchangeID, after: acknowledgementTimeout)
            } catch {
                resolvePendingReply(with: .failure(error))
            }
        }
    }

    private func startListeningIfNeeded() {
        guard listener == nil else { return }
        let replies = transport.incomingReports
        listener = Task { [weak self] in
            for await reply in replies {
                await self?.receive(reply)
            }
        }
    }

    private func expireReply(of exchangeID: Int, after timeout: Duration) {
        Task { [weak self] in
            try? await Task.sleep(for: timeout)
            await self?.failIfStillPending(exchangeID)
        }
    }

    private func failIfStillPending(_ exchangeID: Int) {
        guard let pendingReply, pendingReply.id == exchangeID else { return }
        resolvePendingReply(with: .failure(KeyboardSessionError.noAcknowledgement(command: pendingReply.command)))
    }

    private func receive(_ reply: [UInt8]) {
        guard let pendingReply, reply.first == pendingReply.command else { return }
        resolvePendingReply(with: .success(reply))
    }

    private func resolvePendingReply(with result: Result<[UInt8], any Error>) {
        pendingReply?.continuation.resume(with: result)
        pendingReply = nil
    }
}

private struct PendingReply {
    let id: Int
    let command: UInt8
    let continuation: CheckedContinuation<[UInt8], any Error>
}
