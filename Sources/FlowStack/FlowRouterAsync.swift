import Foundation

@MainActor
public extension FlowRouter {

    // MARK: - Async Queue

    @discardableResult
    func queued(_ action: @escaping @MainActor () -> Bool) async -> Bool {
        await acquireTransitionTurn()
        defer { releaseTransitionTurn() }
        let result = action()
        if queuedTransitionDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: queuedTransitionDelayNanoseconds)
        }
        return result
    }

    // MARK: - Push

    @discardableResult
    func pushAsync(
        _ route: Route,
        on target: FlowStackTarget = .active,
        condition: AsyncPrecondition? = nil
    ) async -> Bool {
        let operation = FlowOperation.push(route, target: target)
        guard await asyncConditionAllows(operation, explicit: condition) else { return false }
        return await queued { self.push(route, on: target, condition: { _, _ in true }) }
    }

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

    @discardableResult
    func pushRemovingPreviousAsync(
        _ route: Route,
        on target: FlowStackTarget = .active,
        condition: AsyncPrecondition? = nil
    ) async -> Bool {
        let operation = FlowOperation.pushRemovingPrevious(route, target: target)
        guard await asyncConditionAllows(operation, explicit: condition) else { return false }
        return await queued { self.pushRemovingPrevious(route, on: target, condition: { _, _ in true }) }
    }

    // MARK: - Replace Current

    @discardableResult
    func replaceCurrentAsync(
        with route: Route,
        on target: FlowStackTarget = .active,
        condition: AsyncPrecondition? = nil
    ) async -> Bool {
        let operation = FlowOperation.replaceCurrent(route, target: target)
        guard await asyncConditionAllows(operation, explicit: condition) else { return false }
        return await queued { self.replaceCurrent(with: route, on: target, condition: { _, _ in true }) }
    }

    // MARK: - Replace Path

    @discardableResult
    func replacePathAsync(
        root: Route,
        path: [Route] = [],
        on target: FlowStackTarget = .active,
        condition: AsyncPrecondition? = nil
    ) async -> Bool {
        let operation = FlowOperation.replacePath(root: root, path: path, target: target)
        guard await asyncConditionAllows(operation, explicit: condition) else { return false }
        return await queued { self.replacePath(root: root, path: path, on: target, condition: { _, _ in true }) }
    }

    // MARK: - Pop

    @discardableResult
    func popAsync(
        count: Int = 1,
        on target: FlowStackTarget = .active,
        condition: AsyncPrecondition? = nil
    ) async -> Bool {
        let operation = FlowOperation<Route>.pop(count: count, target: target)
        guard await asyncConditionAllows(operation, explicit: condition) else { return false }
        return await queued { self.pop(count: count, on: target, condition: { _, _ in true }) }
    }

    @discardableResult
    func popToRootAsync(
        on target: FlowStackTarget = .active,
        condition: AsyncPrecondition? = nil
    ) async -> Bool {
        let operation = FlowOperation<Route>.popToRoot(target: target)
        guard await asyncConditionAllows(operation, explicit: condition) else { return false }
        return await queued { self.popToRoot(on: target, condition: { _, _ in true }) }
    }

    @discardableResult
    func popToAsync(
        _ route: Route,
        match: FlowPopMatch = .exclusive,
        on target: FlowStackTarget = .active,
        condition: AsyncPrecondition? = nil
    ) async -> Bool {
        let operation = FlowOperation.popTo(route, match: match, target: target)
        guard await asyncConditionAllows(operation, explicit: condition) else { return false }
        return await queued { self.popTo(route, match: match, on: target, condition: { _, _ in true }) }
    }

    // MARK: - Set Root

    @discardableResult
    func setRootAsync(
        _ route: Route,
        path: [Route] = [],
        refreshIfSameRoute: Bool = true,
        condition: AsyncPrecondition? = nil
    ) async -> Bool {
        let operation = FlowOperation.setRoot(route)
        guard await asyncConditionAllows(operation, explicit: condition) else { return false }
        return await queued {
            self.setRoot(route, path: path, refreshIfSameRoute: refreshIfSameRoute, condition: { _, _ in true })
        }
    }

    // MARK: - Present / Sheet / FullScreenCover

    @discardableResult
    func presentAsync(
        _ route: Route,
        style: FlowPresentationStyle = .sheet,
        path: [Route] = [],
        options: FlowPresentationOptions = .init(),
        condition: AsyncPrecondition? = nil
    ) async -> Bool {
        let operation = FlowOperation.present(route, style: style)
        guard await asyncConditionAllows(operation, explicit: condition) else { return false }
        return await queued {
            self.present(route, style: style, path: path, options: options, condition: { _, _ in true })
        }
    }

    @discardableResult
    func sheetAsync(
        _ route: Route,
        path: [Route] = [],
        options: FlowPresentationOptions = .init(),
        condition: AsyncPrecondition? = nil
    ) async -> Bool {
        await presentAsync(route, style: .sheet, path: path, options: options, condition: condition)
    }

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

    @discardableResult
    func dismissAsync(
        _ target: FlowStackTarget = .active,
        condition: AsyncPrecondition? = nil
    ) async -> Bool {
        let operation = FlowOperation<Route>.dismiss(target: target)
        guard await asyncConditionAllows(operation, explicit: condition) else { return false }
        return await queued { self.dismiss(target, condition: { _, _ in true }) }
    }

    @discardableResult
    func dismissAllAsync(condition: AsyncPrecondition? = nil) async -> Bool {
        let operation = FlowOperation<Route>.dismissAll
        guard await asyncConditionAllows(operation, explicit: condition) else { return false }
        return await queued { self.dismissAll(condition: { _, _ in true }) }
    }
}

// MARK: - Internal queue helpers

@MainActor
extension FlowRouter {
    func acquireTransitionTurn() async {
        guard isRunningQueuedTransition else {
            isRunningQueuedTransition = true
            return
        }
        await withCheckedContinuation { continuation in
            transitionWaiters.append(continuation)
        }
    }

    func releaseTransitionTurn() {
        if transitionWaiters.isEmpty {
            isRunningQueuedTransition = false
        } else {
            transitionWaiters.removeFirst().resume()
        }
    }
}
