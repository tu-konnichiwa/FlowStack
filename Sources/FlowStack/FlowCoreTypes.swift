import Foundation

public enum FlowPresentationStyle: Hashable, Sendable {
    case root
    case sheet
    case fullScreenCover
}

public enum FlowStackTarget: Hashable, Sendable {
    case root
    case active
    case stack(UUID)
}

public enum FlowPopMatch: Hashable, Sendable {
    case exclusive
    case inclusive
}

public enum FlowDialogPolicy: Hashable, Sendable {
    case replace
    case replaceKeepingQueue
    case queue
    case ignoreIfVisible
}

public struct FlowPresentationOptions: Hashable, Sendable {
    public var allowsInteractiveDismiss: Bool
    public var clearsNestedPresentationOnDismiss: Bool

    public init(
        allowsInteractiveDismiss: Bool = true,
        clearsNestedPresentationOnDismiss: Bool = true
    ) {
        self.allowsInteractiveDismiss = allowsInteractiveDismiss
        self.clearsNestedPresentationOnDismiss = clearsNestedPresentationOnDismiss
    }
}

public struct FlowRouteNode<Route: Hashable>: Identifiable, Hashable {
    public let id: UUID
    public var route: Route

    public init(id: UUID = UUID(), route: Route) {
        self.id = id
        self.route = route
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public struct FlowStackState<Route: Hashable>: Identifiable, Hashable {
    public let id: UUID
    public internal(set) var root: Route
    public internal(set) var rootID: UUID
    internal var navigationPath: [FlowRouteNode<Route>]
    public internal(set) var style: FlowPresentationStyle
    public internal(set) var options: FlowPresentationOptions

    public init(
        id: UUID = UUID(),
        rootID: UUID = UUID(),
        root: Route,
        path: [Route] = [],
        style: FlowPresentationStyle = .root,
        options: FlowPresentationOptions = .init()
    ) {
        self.id = id
        self.rootID = rootID
        self.root = root
        self.navigationPath = path.map { FlowRouteNode(route: $0) }
        self.style = style
        self.options = options
    }

    public var path: [Route] {
        navigationPath.map(\.route)
    }

    public var topRoute: Route {
        path.last ?? root
    }

    public var isRoot: Bool {
        style == .root
    }
}
