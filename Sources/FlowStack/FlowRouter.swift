import Foundation
import Combine

/// Read-only observation contract for navigation presentation. All access is MainActor-isolated.
@MainActor
public protocol FlowRouting: AnyObject, ObservableObject {
    associatedtype Route: Hashable
    associatedtype Dialog

    var stacks: [FlowStackState<Route>] { get }
    var globalDialog: Dialog? { get }
    var rootID: UUID { get }
}

/// Owns one root navigation stack, nested modal stacks, and optional global dialogs.
///
/// Retain one router per flow (usually with StateObject). All commands and callbacks
/// run on MainActor. Route values should be immutable; changing their equality or
/// hashing while stored invalidates navigation matching. See Documentation/API.md
/// for command outcomes, native gestures, async ordering, and cancellation.
///
/// Stored callbacks are retained. Capture owners weakly if they also retain this router.
@MainActor
public final class FlowRouter<Route: Hashable, Dialog>: FlowRouting {
    /// Final synchronous veto for every router command, including async commands.
    public typealias Guard = @MainActor (FlowOperation<Route>) -> Bool
    /// Synchronous command condition, receiving the state before validation.
    public typealias Precondition = @MainActor (FlowOperation<Route>, [FlowStackState<Route>]) -> Bool
    /// Async gate evaluated inside a FIFO turn. Honor cancellation and avoid nested queued commands.
    public typealias AsyncPrecondition = @MainActor (FlowOperation<Route>, [FlowStackState<Route>]) async -> Bool
    /// Applied command callback. Its second argument is the state BEFORE the command.
    public typealias Observer = @MainActor (FlowOperation<Route>, [FlowStackState<Route>]) -> Void

    /// Read-only snapshots, root first and active modal last; there is always a root.
    @Published public internal(set) var stacks: [FlowStackState<Route>]
    /// Visible dialog, rendered by the host; nil means no visible dialog.
    @Published public internal(set) var globalDialog: Dialog?
    /// Host identity refreshed by setRoot when the same root is explicitly refreshed.
    @Published public internal(set) var rootID = UUID()
    /// Recent command snapshots and outcomes. Records retain route payloads until removed.
    @Published public internal(set) var operationHistory: [FlowOperationRecord<Route>] = []

    /// Optional final veto, after the chosen precondition. Do not recursively route from a guard.
    public var guardOperation: Guard?
    /// Observer called after successful commands, including valid no-ops; receives previous stacks.
    public var didApplyOperation: Observer?
    /// Positive limits retain the newest records and trim immediately. Zero/negative means unlimited.
    public var maximumOperationHistoryCount = 200 {
        didSet { trimOperationHistory() }
    }
    /// Spacing after successful queued actions in nanoseconds; default zero. Not an animation-completion signal.
    public var queuedTransitionDelayNanoseconds: UInt64 = 0

    var defaultPreconditions: [FlowOperationKind: Precondition] = [:]
    var defaultAsyncPreconditions: [FlowOperationKind: AsyncPrecondition] = [:]
    @Published var dialogQueue: [Dialog] = []
    let transitionQueue = FlowTransitionQueue()

    /// Creates a root flow with an empty path and no modal or dialog.
    public init(root: Route) {
        self.stacks = [FlowStackState(root: root)]
    }

    /// Creates a root flow with an initial pushed path, useful for app-owned restoration.
    public init(root: Route, path: [Route]) {
        self.stacks = [FlowStackState(root: root, path: path)]
    }

    /// Snapshot of the bottom/root stack.
    public var rootStack: FlowStackState<Route> {
        stacks[0]
    }

    /// Snapshot of the topmost stack, or the root when no modal is presented.
    public var activeStack: FlowStackState<Route> {
        stacks[activeIndex]
    }

    /// Index of activeStack in stacks.
    public var activeIndex: Int {
        max(stacks.count - 1, 0)
    }

    /// Whether at least one modal stack exists.
    public var isPresenting: Bool {
        stacks.count > 1
    }

    /// Number of waiting dialogs, excluding the visible dialog.
    public var queuedGlobalDialogCount: Int {
        dialogQueue.count
    }

    /// Top pushed route of the active stack, falling back to its root.
    public var topRoute: Route {
        activeStack.topRoute
    }

    /// Checks whether a stack ID is still valid. IDs become stale after dismissal or root reset.
    public func containsStack(id: UUID) -> Bool {
        stacks.contains { $0.id == id }
    }

    /// Sets or removes a synchronous default for one operation kind. A per-call condition overrides it.
    public func setDefaultPrecondition(
        for kind: FlowOperationKind,
        _ precondition: Precondition?
    ) {
        defaultPreconditions[kind] = precondition
    }

    /// Sets or removes an async default. Async commands use this instead of synchronous defaults.
    public func setDefaultAsyncPrecondition(
        for kind: FlowOperationKind,
        _ precondition: AsyncPrecondition?
    ) {
        defaultAsyncPreconditions[kind] = precondition
    }

    /// Removes both synchronous and asynchronous defaults; the final guard is unchanged.
    public func clearDefaultPreconditions() {
        defaultPreconditions.removeAll()
        defaultAsyncPreconditions.removeAll()
    }

    /// Releases retained operation records without changing navigation state.
    public func clearOperationHistory() {
        operationHistory.removeAll()
    }
}
