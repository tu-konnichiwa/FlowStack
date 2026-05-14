import Foundation
import SwiftUI

@MainActor
public protocol FlowRouting: AnyObject, ObservableObject {
    associatedtype Route: Hashable
    associatedtype Dialog

    var stacks: [FlowStackState<Route>] { get }
    var globalDialog: Dialog? { get }
    var rootID: UUID { get }
}

@MainActor
public final class FlowRouter<Route: Hashable, Dialog>: FlowRouting {
    public typealias Guard = @MainActor (FlowOperation<Route>) -> Bool
    public typealias Precondition = @MainActor (FlowOperation<Route>, [FlowStackState<Route>]) -> Bool
    public typealias AsyncPrecondition = @MainActor (FlowOperation<Route>, [FlowStackState<Route>]) async -> Bool
    public typealias Observer = @MainActor (FlowOperation<Route>, [FlowStackState<Route>]) -> Void

    @Published public internal(set) var stacks: [FlowStackState<Route>]
    @Published public internal(set) var globalDialog: Dialog?
    @Published public internal(set) var rootID = UUID()
    @Published public internal(set) var operationHistory: [FlowOperationRecord<Route>] = []

    public var guardOperation: Guard?
    public var didApplyOperation: Observer?
    public var maximumOperationHistoryCount = 200
    public var queuedTransitionDelayNanoseconds: UInt64 = 0

    var defaultPreconditions: [FlowOperationKind: Precondition] = [:]
    var defaultAsyncPreconditions: [FlowOperationKind: AsyncPrecondition] = [:]
    var dialogQueue: [Dialog] = []
    var isRunningQueuedTransition = false

    public init(root: Route) {
        self.stacks = [FlowStackState(root: root)]
    }

    public init(root: Route, path: [Route]) {
        self.stacks = [FlowStackState(root: root, path: path)]
    }

    public var rootStack: FlowStackState<Route> {
        stacks[0]
    }

    public var activeStack: FlowStackState<Route> {
        stacks[activeIndex]
    }

    public var activeIndex: Int {
        max(stacks.count - 1, 0)
    }

    public var isPresenting: Bool {
        stacks.count > 1
    }

    public var queuedGlobalDialogCount: Int {
        dialogQueue.count
    }

    public var topRoute: Route {
        activeStack.topRoute
    }

    public func containsStack(id: UUID) -> Bool {
        stacks.contains { $0.id == id }
    }

    public func setDefaultPrecondition(
        for kind: FlowOperationKind,
        _ precondition: Precondition?
    ) {
        defaultPreconditions[kind] = precondition
    }

    public func setDefaultAsyncPrecondition(
        for kind: FlowOperationKind,
        _ precondition: AsyncPrecondition?
    ) {
        defaultAsyncPreconditions[kind] = precondition
    }

    public func clearDefaultPreconditions() {
        defaultPreconditions.removeAll()
        defaultAsyncPreconditions.removeAll()
    }

    public func clearOperationHistory() {
        operationHistory.removeAll()
    }
}
