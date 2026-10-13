import SwiftUI

/// Value configuration for SwiftUI rendering. Transforms are UI details and run during rendering.
/// Defaults hide the iOS navigation bar and use leading text alignment for compatibility.
/// Call navigationBarHidden(false) to retain native back/title affordances.
public struct FlowNavigationStyle {
    /// Read-only presentation context for route-aware styling; depth zero is the stack root.
    public struct Context {
        /// Root-first index of the stack in the router snapshot.
        public let stackIndex: Int
        /// Stable stack identity, distinct from screen identity.
        public let stackID: UUID
        /// Root, sheet, or full-screen presentation kind.
        public let presentationStyle: FlowPresentationStyle
        /// True for the bottom/root stack.
        public let isRootStack: Bool
        /// Type-erased root payload for this stack.
        public let rootRoute: AnyHashable
        /// Type-erased payload for the current screen.
        public let screenRoute: AnyHashable
        /// Number of pushed nodes through this screen; root depth is zero.
        public let screenDepth: Int
        /// True when styling a stack root screen.
        public let isRootScreen: Bool

        /// Creates a styling context. Depth is zero for the root; stack index zero is the app root.
        public init(
            stackIndex: Int,
            stackID: UUID,
            presentationStyle: FlowPresentationStyle,
            rootRoute: AnyHashable,
            screenRoute: AnyHashable,
            screenDepth: Int
        ) {
            self.stackIndex = stackIndex
            self.stackID = stackID
            self.presentationStyle = presentationStyle
            self.isRootStack = stackIndex == 0
            self.rootRoute = rootRoute
            self.screenRoute = screenRoute
            self.screenDepth = screenDepth
            self.isRootScreen = screenDepth == 0
        }

        /// Returns the typed route, or nil if its type differs from the requested type.
        public func rootRoute<Route>(as type: Route.Type = Route.self) -> Route? {
            rootRoute.base as? Route
        }

        /// Returns the typed route, or nil if its type differs from the requested type.
        public func screenRoute<Route>(as type: Route.Type = Route.self) -> Route? {
            screenRoute.base as? Route
        }
    }

    /// Hides the iOS navigation bar; does not change macOS toolbar visibility.
    public var hidesNavigationBar: Bool
    /// Default screen text alignment, or nil to inherit the caller environment.
    public var multilineTextAlignment: TextAlignment?
    /// Transform applied to each NavigationStack.
    public var stack: (AnyView, Context) -> AnyView
    /// Transform applied to each root or pushed screen.
    public var screen: (AnyView, Context) -> AnyView
    /// Transform applied to each presented stack boundary.
    public var modal: (AnyView, Context) -> AnyView

    /// Creates identity transforms by default. Newer SwiftUI modifiers need app-owned availability checks.
    public init(
        hidesNavigationBar: Bool = false,
        multilineTextAlignment: TextAlignment? = .leading,
        stack: @escaping (AnyView, Context) -> AnyView = { view, _ in view },
        screen: @escaping (AnyView, Context) -> AnyView = { view, _ in view },
        modal: @escaping (AnyView, Context) -> AnyView = { view, _ in view }
    ) {
        self.hidesNavigationBar = hidesNavigationBar
        self.multilineTextAlignment = multilineTextAlignment
        self.stack = stack
        self.screen = screen
        self.modal = modal
    }

    /// Compatibility defaults: hidden iOS navigation bar, leading text, and identity transforms.
    public static var `default`: FlowNavigationStyle {
        FlowNavigationStyle()
    }

    /// Returns a copy with the chosen iOS navigation bar visibility.
    public func navigationBarHidden(_ hidden: Bool) -> Self {
        var copy = self
        copy.hidesNavigationBar = hidden
        return copy
    }

    /// Returns a copy with the chosen text alignment.
    public func multilineTextAlignment(_ alignment: TextAlignment?) -> Self {
        var copy = self
        copy.multilineTextAlignment = alignment
        return copy
    }

    /// Returns a copy replacing the stack transform; repeated calls replace rather than compose.
    public func stackStyle(@ViewBuilder _ transform: @escaping (AnyView) -> some View) -> Self {
        var copy = self
        copy.stack = { view, _ in AnyView(transform(view)) }
        return copy
    }

    /// Replaces this transform with a context-aware renderer.
    public func stackStyle(@ViewBuilder _ transform: @escaping (AnyView, Context) -> some View) -> Self {
        var copy = self
        copy.stack = { view, context in AnyView(transform(view, context)) }
        return copy
    }

    /// Returns a copy replacing the screen transform; repeated calls replace rather than compose.
    public func screenStyle(@ViewBuilder _ transform: @escaping (AnyView) -> some View) -> Self {
        var copy = self
        copy.screen = { view, _ in AnyView(transform(view)) }
        return copy
    }

    /// Replaces this transform with a context-aware renderer.
    public func screenStyle(@ViewBuilder _ transform: @escaping (AnyView, Context) -> some View) -> Self {
        var copy = self
        copy.screen = { view, context in AnyView(transform(view, context)) }
        return copy
    }

    /// Returns a copy replacing the modal transform; repeated calls replace rather than compose.
    public func modalStyle(@ViewBuilder _ transform: @escaping (AnyView) -> some View) -> Self {
        var copy = self
        copy.modal = { view, _ in AnyView(transform(view)) }
        return copy
    }

    /// Replaces this transform with a context-aware renderer.
    public func modalStyle(@ViewBuilder _ transform: @escaping (AnyView, Context) -> some View) -> Self {
        var copy = self
        copy.modal = { view, context in AnyView(transform(view, context)) }
        return copy
    }
}

struct FlowScreenDefaultStyle: ViewModifier {
    let style: FlowNavigationStyle
    let context: FlowNavigationStyle.Context

    func body(content: Content) -> some View {
        var view = AnyView(content)

        if let alignment = style.multilineTextAlignment {
            view = AnyView(view.multilineTextAlignment(alignment))
        }

        if style.hidesNavigationBar {
            #if os(iOS)
            view = AnyView(view.toolbar(.hidden, for: .navigationBar))
            #endif
        }

        return style.screen(view, context)
    }
}
