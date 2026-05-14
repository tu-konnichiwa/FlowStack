import Foundation

@MainActor
public extension FlowRouter {
    @discardableResult
    func queued(_ action: @escaping @MainActor () -> Bool) async -> Bool {
        while isRunningQueuedTransition {
            await Task.yield()
        }

        isRunningQueuedTransition = true
        let didRun = action()

        if queuedTransitionDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: queuedTransitionDelayNanoseconds)
        }

        isRunningQueuedTransition = false
        return didRun
    }

    @discardableResult
    func pushAsync(
        _ route: Route,
        on target: FlowStackTarget = .active,
        condition: AsyncPrecondition? = nil
    ) async -> Bool {
        let operation = FlowOperation.push(route, target: target)
        guard await asyncConditionAllows(operation, explicit: condition) else { return false }
        return await queued {
            self.push(route, on: target, condition: { _, _ in true })
        }
    }

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

    @discardableResult
    func popAsync(
        count: Int = 1,
        on target: FlowStackTarget = .active,
        condition: AsyncPrecondition? = nil
    ) async -> Bool {
        let operation = FlowOperation<Route>.pop(count: count, target: target)
        guard await asyncConditionAllows(operation, explicit: condition) else { return false }
        return await queued {
            self.pop(count: count, on: target, condition: { _, _ in true })
        }
    }

    @discardableResult
    func dismissAsync(
        _ target: FlowStackTarget = .active,
        condition: AsyncPrecondition? = nil
    ) async -> Bool {
        let operation = FlowOperation<Route>.dismiss(target: target)
        guard await asyncConditionAllows(operation, explicit: condition) else { return false }
        return await queued {
            self.dismiss(target, condition: { _, _ in true })
        }
    }
}
