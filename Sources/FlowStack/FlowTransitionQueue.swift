import Foundation

/// Owns FIFO turns and continuation lifecycle. Only the holder releases a turn.
@MainActor
internal final class FlowTransitionQueue {
    private struct Waiter {
        let id: UUID
        let continuation: CheckedContinuation<Bool, Never>
    }

    let id = UUID()
    private var occupied = false
    private var waiters: [Waiter] = []

    func acquire() async -> Bool {
        guard !Task.isCancelled else { return false }
        guard occupied else {
            occupied = true
            return true
        }
        let id = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if Task.isCancelled {
                    continuation.resume(returning: false)
                } else {
                    waiters.append(Waiter(id: id, continuation: continuation))
                }
            }
        } onCancel: {
            Task { @MainActor in self.cancel(id) }
        }
    }

    func release() {
        if waiters.isEmpty {
            occupied = false
        } else {
            waiters.removeFirst().continuation.resume(returning: true)
        }
    }

    private func cancel(_ id: UUID) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
        waiters.remove(at: index).continuation.resume(returning: false)
    }
}

/// Task-local ownership prevents a gate from waiting on its own queue turn.
internal enum FlowTransitionContext {
    @TaskLocal static var activeTurns: [FlowTransitionTurn] = []
}

/// Child tasks inherit context, so the token must expire when its actual turn ends.
@MainActor
internal final class FlowTransitionTurn {
    let queueID: UUID
    var isActive = true

    init(queueID: UUID) { self.queueID = queueID }
}
