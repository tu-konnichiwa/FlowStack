import Foundation

/// Command description used by guards and history. setRoot/present describe the root
/// route, not every path/option; inspect resulting stack snapshots for complete state.
public enum FlowOperation<Route: Hashable>: Hashable {
    case setRoot(Route)
    case push(Route, target: FlowStackTarget)
    case pushRemovingPrevious(Route, target: FlowStackTarget)
    case replaceCurrent(Route, target: FlowStackTarget)
    case replacePath(root: Route, path: [Route], target: FlowStackTarget)
    case pop(count: Int, target: FlowStackTarget)
    case popToRoot(target: FlowStackTarget)
    case popTo(Route, match: FlowPopMatch, target: FlowStackTarget)
    case present(Route, style: FlowPresentationStyle)
    case dismiss(target: FlowStackTarget)
    case dismissAll
}

/// Command category for registering default conditions.
public enum FlowOperationKind: Hashable, Sendable {
    case setRoot
    case push
    case pushRemovingPrevious
    case replaceCurrent
    case replacePath
    case pop
    case popToRoot
    case popTo
    case present
    case dismiss
    case dismissAll
}

public extension FlowOperation {
    /// Category used to select a default condition.
    var kind: FlowOperationKind {
        switch self {
        case .setRoot:
            return .setRoot
        case .push:
            return .push
        case .pushRemovingPrevious:
            return .pushRemovingPrevious
        case .replaceCurrent:
            return .replaceCurrent
        case .replacePath:
            return .replacePath
        case .pop:
            return .pop
        case .popToRoot:
            return .popToRoot
        case .popTo:
            return .popTo
        case .present:
            return .present
        case .dismiss:
            return .dismiss
        case .dismissAll:
            return .dismissAll
        }
    }
}

/// Diagnostic outcome for a command. Only applied returns true; valid no-ops are applied.
public enum FlowOperationOutcome: Hashable, Sendable {
    case applied
    case blockedByPrecondition
    case blockedByGuard
    /// The requested stack no longer exists. Resolve a current stack ID and retry.
    case invalidTarget
    /// popTo could not find the route in the selected stack's pushed path.
    case routeNotFound
    /// Root is not a modal presentation style. Use setRoot instead.
    case invalidPresentationStyle
    /// An async request was cancelled before it committed.
    case cancelled
    /// A queued action tried to await another queued action on the same router.
    /// Perform the follow-up after the outer action returns.
    case reentrantTransition
}

/// Retained before/after snapshots for a completed or rejected command. Dates use wall-clock time.
public struct FlowOperationRecord<Route: Hashable>: Identifiable {
    /// Unique identity of this diagnostic record.
    public let id: UUID
    /// Time this operation was recorded.
    public let date: Date
    /// Requested operation.
    public let operation: FlowOperation<Route>
    /// State captured before preconditions and mutation.
    public let previousStacks: [FlowStackState<Route>]
    /// State after mutation, or the unchanged state for rejected commands.
    public let newStacks: [FlowStackState<Route>]
    /// Applied or rejection/cancellation reason.
    public let outcome: FlowOperationOutcome

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        operation: FlowOperation<Route>,
        previousStacks: [FlowStackState<Route>],
        newStacks: [FlowStackState<Route>],
        outcome: FlowOperationOutcome
    ) {
        self.id = id
        self.date = date
        self.operation = operation
        self.previousStacks = previousStacks
        self.newStacks = newStacks
        self.outcome = outcome
    }
}
