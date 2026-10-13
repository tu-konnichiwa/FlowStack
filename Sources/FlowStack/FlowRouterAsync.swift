import Foundation

// Async variants inherit the matching synchronous command's navigation semantics.
// Async conditions override async defaults; synchronous defaults are not consulted.
// The final synchronous guard still runs. See Documentation/API.md.
@MainActor
public extension FlowRouter {

    // MARK: - Async Queue

    /// Runs an action in FIFO order with other async commands. Returns false if cancelled
    /// before execution or called recursively from the same queue turn. No history is
    /// recorded for the wrapper itself. Synchronous commands are not queued.
    @discardableResult
    func queued(_ action: @escaping @MainActor () -> Bool) async -> Bool {
        await runQueued(operation: nil) { action() }
    }

    // MARK: - Push

    /// Queued variant of push with an async gate. Validation and commit share a FIFO turn.
    /// Cancellation before commit returns false; cancellation after commit does not undo it.
    @discardableResult
    func pushAsync(
        _ route: Route,
        on target: FlowStackTarget = .active,
        condition: AsyncPrecondition? = nil
    ) async -> Bool {
        let operation = FlowOperation.push(route, target: target)
        return await performAsync(operation, condition: condition) { self.push(route, on: target, condition: { _, _ in true }) }
    }

    /// Pushes sequentially with per-route gates and aggregate success; partial success is possible.
    /// Other queued calls can interleave between routes. Empty input succeeds immediately.
    @discardableResult
    func pushAsync(
        contentsOf routes: [Route],
        on target: FlowStackTarget = .active,
        condition: AsyncPrecondition? = nil
    ) async -> Bool {
        guard !routes.isEmpty else { return true }
        var applied = true
        for route in routes {
            applied = await pushAsync(route, on: target, condition: condition) && applied
        }
        return applied
    }

    // MARK: - Push Removing Previous

    /// Queued variant of pushRemovingPrevious with an async gate. Validation and commit share a FIFO turn.
    /// Cancellation before commit returns false; cancellation after commit does not undo it.
    @discardableResult
    func pushRemovingPreviousAsync(
        _ route: Route,
        on target: FlowStackTarget = .active,
        condition: AsyncPrecondition? = nil
    ) async -> Bool {
        let operation = FlowOperation.pushRemovingPrevious(route, target: target)
        return await performAsync(operation, condition: condition) { self.pushRemovingPrevious(route, on: target, condition: { _, _ in true }) }
    }

    // MARK: - Replace Current

    /// Queued variant of replaceCurrent with an async gate. Validation and commit share a FIFO turn.
    /// Cancellation before commit returns false; cancellation after commit does not undo it.
    @discardableResult
    func replaceCurrentAsync(
        with route: Route,
        on target: FlowStackTarget = .active,
        condition: AsyncPrecondition? = nil
    ) async -> Bool {
        let operation = FlowOperation.replaceCurrent(route, target: target)
        return await performAsync(operation, condition: condition) { self.replaceCurrent(with: route, on: target, condition: { _, _ in true }) }
    }

    // MARK: - Replace Path

    /// Queued variant of replacePath with an async gate. Validation and commit share a FIFO turn.
    /// Cancellation before commit returns false; cancellation after commit does not undo it.
    @discardableResult
    func replacePathAsync(
        root: Route,
        path: [Route] = [],
        on target: FlowStackTarget = .active,
        condition: AsyncPrecondition? = nil
    ) async -> Bool {
        let operation = FlowOperation.replacePath(root: root, path: path, target: target)
        return await performAsync(operation, condition: condition) { self.replacePath(root: root, path: path, on: target, condition: { _, _ in true }) }
    }

    // MARK: - Pop

    /// Queued variant of pop with an async gate. Validation and commit share a FIFO turn.
    /// Cancellation before commit returns false; cancellation after commit does not undo it.
    @discardableResult
    func popAsync(
        count: Int = 1,
        on target: FlowStackTarget = .active,
        condition: AsyncPrecondition? = nil
    ) async -> Bool {
        let operation = FlowOperation<Route>.pop(count: count, target: target)
        return await performAsync(operation, condition: condition) { self.pop(count: count, on: target, condition: { _, _ in true }) }
    }

    /// Queued variant of popToRoot with an async gate. Validation and commit share a FIFO turn.
    /// Cancellation before commit returns false; cancellation after commit does not undo it.
    @discardableResult
    func popToRootAsync(
        on target: FlowStackTarget = .active,
        condition: AsyncPrecondition? = nil
    ) async -> Bool {
        let operation = FlowOperation<Route>.popToRoot(target: target)
        return await performAsync(operation, condition: condition) { self.popToRoot(on: target, condition: { _, _ in true }) }
    }

    /// Queued variant of popTo with an async gate. Validation and commit share a FIFO turn.
    /// Cancellation before commit returns false; cancellation after commit does not undo it.
    @discardableResult
    func popToAsync(
        _ route: Route,
        match: FlowPopMatch = .exclusive,
        on target: FlowStackTarget = .active,
        condition: AsyncPrecondition? = nil
    ) async -> Bool {
        let operation = FlowOperation.popTo(route, match: match, target: target)
        return await performAsync(operation, condition: condition) { self.popTo(route, match: match, on: target, condition: { _, _ in true }) }
    }

    // MARK: - Set Root

    /// Queued variant of setRoot with an async gate. Validation and commit share a FIFO turn.
    /// Cancellation before commit returns false; cancellation after commit does not undo it.
    @discardableResult
    func setRootAsync(
        _ route: Route,
        path: [Route] = [],
        refreshIfSameRoute: Bool = true,
        condition: AsyncPrecondition? = nil
    ) async -> Bool {
        let operation = FlowOperation.setRoot(route)
        return await performAsync(operation, condition: condition) {
            self.setRoot(route, path: path, refreshIfSameRoute: refreshIfSameRoute, condition: { _, _ in true })
        }
    }

    // MARK: - Present / Sheet / FullScreenCover

    /// Queued variant of present with an async gate. Validation and commit share a FIFO turn.
    /// Cancellation before commit returns false; cancellation after commit does not undo it.
    @discardableResult
    func presentAsync(
        _ route: Route,
        style: FlowPresentationStyle = .sheet,
        path: [Route] = [],
        options: FlowPresentationOptions = .init(),
        condition: AsyncPrecondition? = nil
    ) async -> Bool {
        let operation = FlowOperation.present(route, style: style)
        return await performAsync(operation, condition: condition) {
            self.present(route, style: style, path: path, options: options, condition: { _, _ in true })
        }
    }

    /// Queued variant of sheet with an async gate. Validation and commit share a FIFO turn.
    /// Cancellation before commit returns false; cancellation after commit does not undo it.
    @discardableResult
    func sheetAsync(
        _ route: Route,
        path: [Route] = [],
        options: FlowPresentationOptions = .init(),
        condition: AsyncPrecondition? = nil
    ) async -> Bool {
        await presentAsync(route, style: .sheet, path: path, options: options, condition: condition)
    }

    /// Queued variant of fullScreenCover with an async gate. Validation and commit share a FIFO turn.
    /// Cancellation before commit returns false; cancellation after commit does not undo it.
    @discardableResult
    func fullScreenCoverAsync(
        _ route: Route,
        path: [Route] = [],
        options: FlowPresentationOptions = .init(),
        condition: AsyncPrecondition? = nil
    ) async -> Bool {
        await presentAsync(route, style: .fullScreenCover, path: path, options: options, condition: condition)
    }

    // MARK: - Dismiss

    /// Queued variant of dismiss with an async gate. Validation and commit share a FIFO turn.
    /// Cancellation before commit returns false; cancellation after commit does not undo it.
    @discardableResult
    func dismissAsync(
        _ target: FlowStackTarget = .active,
        condition: AsyncPrecondition? = nil
    ) async -> Bool {
        let operation = FlowOperation<Route>.dismiss(target: target)
        return await performAsync(operation, condition: condition) { self.dismiss(target, condition: { _, _ in true }) }
    }

    /// Queued variant of dismissAll with an async gate. Validation and commit share a FIFO turn.
    /// Cancellation before commit returns false; cancellation after commit does not undo it.
    @discardableResult
    func dismissAllAsync(condition: AsyncPrecondition? = nil) async -> Bool {
        let operation = FlowOperation<Route>.dismissAll
        return await performAsync(operation, condition: condition) { self.dismissAll(condition: { _, _ in true }) }
    }
}

// MARK: - Serialized validation and commit

@MainActor
extension FlowRouter {
    func performAsync(
        _ operation: FlowOperation<Route>,
        condition: AsyncPrecondition?,
        action: @escaping @MainActor () -> Bool
    ) async -> Bool {
        await runQueued(operation: operation) {
            guard await self.asyncConditionAllows(operation, explicit: condition) else { return false }
            return action()
        }
    }

    func runQueued(
        operation: FlowOperation<Route>?,
        action: @escaping @MainActor () async -> Bool
    ) async -> Bool {
        guard !FlowTransitionContext.activeTurns.contains(where: { $0.queueID == transitionQueue.id && $0.isActive }) else {
            if let operation { record(operation, previousStacks: stacks, outcome: .reentrantTransition) }
            return false
        }
        guard await transitionQueue.acquire() else {
            if let operation { record(operation, previousStacks: stacks, outcome: .cancelled) }
            return false
        }
        let turn = FlowTransitionTurn(queueID: transitionQueue.id)
        defer {
            turn.isActive = false
            transitionQueue.release()
        }
        guard !Task.isCancelled else {
            if let operation { record(operation, previousStacks: stacks, outcome: .cancelled) }
            return false
        }
        let result = await FlowTransitionContext.$activeTurns.withValue(
            FlowTransitionContext.activeTurns + [turn]
        ) {
            await action()
        }
        if result, queuedTransitionDelayNanoseconds > 0 {
            do {
                try await Task.sleep(nanoseconds: queuedTransitionDelayNanoseconds)
            } catch {
                // The command has committed. Cancellation ends spacing, without undoing it.
            }
        }
        return result
    }
}
