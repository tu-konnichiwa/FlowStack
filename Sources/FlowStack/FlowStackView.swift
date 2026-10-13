import SwiftUI

/// SwiftUI host for one router's root and nested modal stacks.
/// The consumer retains the router; this host observes it. The optional dialog
/// renderer receives the visible dialog binding on the topmost presentation layer.
/// Clearing that binding promotes queued dialogs. Native gestures bypass guards;
/// use explicit controls for confirmation-before-leave flows.
public struct FlowStackView<Route: Hashable, Dialog: Identifiable, Screen: View>: View {
    @ObservedObject private var router: FlowRouter<Route, Dialog>
    private let style: FlowNavigationStyle
    private let screen: (Route) -> Screen
    private let dialog: ((Binding<Dialog?>) -> AnyView)?

    /// Hosts route screens with optional legacy AnyView dialog rendering.
    public init(
        router: FlowRouter<Route, Dialog>,
        style: FlowNavigationStyle = .default,
        @ViewBuilder screen: @escaping (Route) -> Screen,
        dialog: ((Binding<Dialog?>) -> AnyView)? = nil
    ) {
        self.router = router
        self.style = style
        self.screen = screen
        self.dialog = dialog
    }

    /// Accepts any dialog view without requiring consumers to erase it to AnyView.
    public init<DialogContent: View>(
        router: FlowRouter<Route, Dialog>,
        style: FlowNavigationStyle = .default,
        @ViewBuilder screen: @escaping (Route) -> Screen,
        @ViewBuilder dialog: @escaping (Binding<Dialog?>) -> DialogContent
    ) {
        self.router = router
        self.style = style
        self.screen = screen
        self.dialog = { AnyView(dialog($0)) }
    }

    public var body: some View {
        FlowStackLayer(
            router: router,
            index: 0,
            style: style,
            screen: screen,
            dialog: dialog
        )
        .id(router.rootID)
    }
}

private struct FlowStackLayer<Route: Hashable, Dialog: Identifiable, Screen: View>: View {
    @ObservedObject var router: FlowRouter<Route, Dialog>
    let index: Int
    let style: FlowNavigationStyle
    let screen: (Route) -> Screen
    let dialog: ((Binding<Dialog?>) -> AnyView)?

    var body: some View {
        if router.stacks.indices.contains(index) {
            let stack = router.stacks[index]
            let context = FlowNavigationStyle.Context(
                stackIndex: index,
                stackID: stack.id,
                presentationStyle: stack.style,
                rootRoute: AnyHashable(stack.root),
                screenRoute: AnyHashable(stack.root),
                screenDepth: 0
            )
            style.stack(
                AnyView(
                    NavigationStack(path: router.bindingForNavigationPath(stackID: stack.id)) {
                        screen(stack.root)
                            .id(stack.rootID)
                            .modifier(FlowScreenDefaultStyle(style: style, context: context))
                            .navigationDestination(for: FlowRouteNode<Route>.self) { node in
                                let destinationContext = FlowNavigationStyle.Context(
                                    stackIndex: index,
                                    stackID: stack.id,
                                    presentationStyle: stack.style,
                                    rootRoute: AnyHashable(stack.root),
                                    screenRoute: AnyHashable(node.route),
                                    screenDepth: (stack.navigationPath.firstIndex(of: node) ?? 0) + 1
                                )
                                screen(node.route)
                                    .modifier(FlowScreenDefaultStyle(style: style, context: destinationContext))
                            }
                    }
                ),
                context
            )
            .overlay {
                if index == router.activeIndex, let dialog {
                    let visibleID = router.globalDialog?.id
                    dialog(Binding(
                        get: { router.globalDialog },
                        set: { value in
                            if let value {
                                router.showGlobalDialog(value)
                            } else if let visibleID {
                                router.hideGlobalDialog(id: visibleID)
                            }
                        }
                    ))
                }
            }
            .modifier(
                FlowPresentationLayer(
                    router: router,
                    index: index + 1,
                    style: style,
                    screen: screen,
                    dialog: dialog
                )
            )
        }
    }
}

private struct FlowPresentationLayer<Route: Hashable, Dialog: Identifiable, Screen: View>: ViewModifier {
    @ObservedObject var router: FlowRouter<Route, Dialog>
    let index: Int
    let style: FlowNavigationStyle
    let screen: (Route) -> Screen
    let dialog: ((Binding<Dialog?>) -> AnyView)?

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: isPresentedBinding(for: .sheet)) {
                presentedLayer
            }
            #if os(iOS)
            .fullScreenCover(isPresented: isPresentedBinding(for: .fullScreenCover)) {
                presentedLayer
            }
            #else
            .sheet(isPresented: isPresentedBinding(for: .fullScreenCover)) {
                presentedLayer
            }
            #endif
    }

    @ViewBuilder
    private var presentedLayer: some View {
        if router.stacks.indices.contains(index) {
            let stack = router.stacks[index]
            let context = FlowNavigationStyle.Context(
                stackIndex: index,
                stackID: stack.id,
                presentationStyle: stack.style,
                rootRoute: AnyHashable(stack.root),
                screenRoute: AnyHashable(stack.root),
                screenDepth: 0
            )
            style.modal(
                AnyView(
                    FlowStackLayer(router: router, index: index, style: style, screen: screen, dialog: dialog)
                        .interactiveDismissDisabled(!stack.options.allowsInteractiveDismiss)
                ),
                context
            )
        }
    }

    private func isPresentedBinding(for style: FlowPresentationStyle) -> Binding<Bool> {
        // Capture identity, not an array index: a stale host must not dismiss its successor.
        let stackID = router.stacks.indices.contains(index) ? router.stacks[index].id : nil
        return Binding(
            get: {
                guard let stackID else { return false }
                return router.stacks.contains { $0.id == stackID && $0.style == style }
            },
            set: { isPresented in
                guard !isPresented, let stackID,
                      let currentIndex = router.stacks.firstIndex(where: { $0.id == stackID }) else { return }
                router.dismissStack(at: currentIndex)
            }
        )
    }
}
