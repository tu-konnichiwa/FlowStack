import Foundation

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

public enum FlowOperationOutcome: Hashable, Sendable {
    case applied
    case blockedByPrecondition
    case blockedByGuard
}

public struct FlowOperationRecord<Route: Hashable>: Identifiable {
    public let id: UUID
    public let date: Date
    public let operation: FlowOperation<Route>
    public let previousStacks: [FlowStackState<Route>]
    public let newStacks: [FlowStackState<Route>]
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
