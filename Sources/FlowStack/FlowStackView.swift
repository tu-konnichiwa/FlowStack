import SwiftUI

public struct FlowStackView<Route: Hashable, Dialog: Identifiable, Screen: View>: View {
    @ObservedObject private var router: FlowRouter<Route, Dialog>
    private let style: FlowNavigationStyle
    private let screen: (Route) -> Screen
    private let dialog: ((Binding<Dialog?>) -> AnyView)?

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

    public var body: some View {
        FlowStackLayer(
            router: router,
            index: 0,
            style: style,
            screen: screen
        )
        .id(router.rootID)
        .overlay {
            if let dialog {
                let visibleDialogID = router.globalDialog?.id
                dialog(
                    Binding(
                        get: { router.globalDialog },
                        set: { newValue in
                            if newValue == nil {
                                router.hideGlobalDialog(id: visibleDialogID)
                            } else if let newValue {
                                router.showGlobalDialog(newValue)
                            }
                        }
                    )
                )
            }
        }
    }
}

private struct FlowStackLayer<Route: Hashable, Dialog, Screen: View>: View {
    @ObservedObject var router: FlowRouter<Route, Dialog>
    let index: Int
    let style: FlowNavigationStyle
    let screen: (Route) -> Screen

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
            .modifier(
                FlowPresentationLayer(
                    router: router,
                    index: index + 1,
                    style: style,
                    screen: screen
                )
            )
        }
    }
}

private struct FlowPresentationLayer<Route: Hashable, Dialog, Screen: View>: ViewModifier {
    @ObservedObject var router: FlowRouter<Route, Dialog>
    let index: Int
    let style: FlowNavigationStyle
    let screen: (Route) -> Screen

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
                    FlowStackLayer(router: router, index: index, style: style, screen: screen)
                        .interactiveDismissDisabled(!stack.options.allowsInteractiveDismiss)
                ),
                context
            )
        }
    }

    private func isPresentedBinding(for style: FlowPresentationStyle) -> Binding<Bool> {
        Binding(
            get: {
                router.stacks.indices.contains(index) && router.stacks[index].style == style
            },
            set: { isPresented in
                guard !isPresented, router.stacks.indices.contains(index) else { return }
                let stackID = router.stacks[index].id
                router.dismiss(.stack(stackID))
            }
        )
    }
}
