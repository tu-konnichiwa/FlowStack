import SwiftUI

public struct FlowNavigationStyle {
    public struct Context {
        public let stackIndex: Int
        public let stackID: UUID
        public let presentationStyle: FlowPresentationStyle
        public let isRootStack: Bool
        public let rootRoute: AnyHashable
        public let screenRoute: AnyHashable
        public let screenDepth: Int
        public let isRootScreen: Bool

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

        public func rootRoute<Route>(as type: Route.Type = Route.self) -> Route? {
            rootRoute.base as? Route
        }

        public func screenRoute<Route>(as type: Route.Type = Route.self) -> Route? {
            screenRoute.base as? Route
        }
    }

    public var hidesNavigationBar: Bool
    public var multilineTextAlignment: TextAlignment?
    public var stack: (AnyView, Context) -> AnyView
    public var screen: (AnyView, Context) -> AnyView
    public var modal: (AnyView, Context) -> AnyView

    public init(
        hidesNavigationBar: Bool = true,
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

    public static var `default`: FlowNavigationStyle {
        FlowNavigationStyle()
    }

    public func navigationBarHidden(_ hidden: Bool) -> Self {
        var copy = self
        copy.hidesNavigationBar = hidden
        return copy
    }

    public func multilineTextAlignment(_ alignment: TextAlignment?) -> Self {
        var copy = self
        copy.multilineTextAlignment = alignment
        return copy
    }

    public func stackStyle(@ViewBuilder _ transform: @escaping (AnyView) -> some View) -> Self {
        var copy = self
        copy.stack = { view, _ in AnyView(transform(view)) }
        return copy
    }

    public func stackStyle(@ViewBuilder _ transform: @escaping (AnyView, Context) -> some View) -> Self {
        var copy = self
        copy.stack = { view, context in AnyView(transform(view, context)) }
        return copy
    }

    public func screenStyle(@ViewBuilder _ transform: @escaping (AnyView) -> some View) -> Self {
        var copy = self
        copy.screen = { view, _ in AnyView(transform(view)) }
        return copy
    }

    public func screenStyle(@ViewBuilder _ transform: @escaping (AnyView, Context) -> some View) -> Self {
        var copy = self
        copy.screen = { view, context in AnyView(transform(view, context)) }
        return copy
    }

    public func modalStyle(@ViewBuilder _ transform: @escaping (AnyView) -> some View) -> Self {
        var copy = self
        copy.modal = { view, _ in AnyView(transform(view)) }
        return copy
    }

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
