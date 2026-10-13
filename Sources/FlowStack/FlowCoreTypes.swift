import Foundation

/// Uninhabited dialog model for apps that only need navigation.
/// Use `FlowRouter<AppRoute, FlowNoDialog>` and omit the host's dialog builder.
public enum FlowNoDialog: Identifiable, Sendable {
    /// An impossible ID because no dialog value can exist.
    public var id: Never { switch self {} }
}

/// Presentation kind; root is for stack state, not a valid modal request.
public enum FlowPresentationStyle: Hashable, Sendable {
    case root
    case sheet
    case fullScreenCover
}

/// Command destination: root, current active stack, or a captured stack identity.
public enum FlowStackTarget: Hashable, Sendable {
    case root
    case active
    case stack(UUID)
}

/// Whether popTo keeps (exclusive) or removes (inclusive) its last matching pushed route.
public enum FlowPopMatch: Hashable, Sendable {
    case exclusive
    case inclusive
}

/// Scheduling policy for one visible dialog and its FIFO queue.
public enum FlowDialogPolicy: Hashable, Sendable {
    /// Replace the visible dialog and clear any queued dialogs.
    case replace
    /// Replace the visible dialog while preserving dialogs already waiting in the queue.
    case replaceKeepingQueue
    /// Show immediately when no dialog is visible, otherwise append to the end of the queue.
    case queue
    /// Show immediately and move the visible dialog to the front of the queue.
    case interrupt
    /// Keep the visible dialog and drop the new dialog when one is already visible.
    case ignoreIfVisible
}

/// Navigation policy for a modal. Visual presentation modifiers belong to SwiftUI screens.
public struct FlowPresentationOptions: Hashable, Sendable {
    /// Allows native modal dismissal by default. Command-based dismissal is unaffected.
    public var allowsInteractiveDismiss: Bool
    /// When true (default), dismissing this modal also removes all modals above it.
    public var clearsNestedPresentationOnDismiss: Bool

    public init(
        allowsInteractiveDismiss: Bool = true,
        clearsNestedPresentationOnDismiss: Bool = true
    ) {
        self.allowsInteractiveDismiss = allowsInteractiveDismiss
        self.clearsNestedPresentationOnDismiss = clearsNestedPresentationOnDismiss
    }
}

/// One screen instance. Equality/hashing use UUID only, allowing repeated equal route values.
public struct FlowRouteNode<Route: Hashable>: Identifiable, Hashable {
    /// Unique identity for this screen instance; independent of the route value.
    public let id: UUID
    /// Payload for this screen instance; changing it does not change node identity.
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

/// Read-only router snapshot of a root screen and its pushed path. Route payloads must have stable hashing.
public struct FlowStackState<Route: Hashable>: Identifiable, Hashable {
    /// Unique identity for this stack lifetime.
    public let id: UUID
    /// The first screen in this stack.
    public internal(set) var root: Route
    /// Identity of the root screen; replacements can deliberately recreate local view state.
    public internal(set) var rootID: UUID
    internal var navigationPath: [FlowRouteNode<Route>]
    /// How this stack was presented.
    public internal(set) var style: FlowPresentationStyle
    /// Dismissal policy for this stack.
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

    /// Pushed route values in bottom-to-top order; UUID screen identities are hidden.
    public var path: [Route] {
        navigationPath.map(\.route)
    }

    /// Last pushed route, or root when the path is empty.
    public var topRoute: Route {
        path.last ?? root
    }

    /// Whether this is a root-style stack.
    public var isRoot: Bool {
        style == .root
    }
}
