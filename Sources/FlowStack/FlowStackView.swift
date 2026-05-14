import SwiftUI

public struct FlowStackView<Route: Hashable, Dialog: Identifiable, Root: View, Destination: View>: View {
    @ObservedObject private var router: FlowRouter<Route, Dialog>
    private let style: FlowNavigationStyle
    private let root: (Route) -> Root
    private let destination: (Route) -> Destination
    private let dialog: ((Binding<Dialog?>) -> AnyView)?

    public init(
        router: FlowRouter<Route, Dialog>,
        style: FlowNavigationStyle = .default,
        @ViewBuilder root: @escaping (Route) -> Root,
        @ViewBuilder destination: @escaping (Route) -> Destination,
        dialog: ((Binding<Dialog?>) -> AnyView)? = nil
    ) {
        self.router = router
        self.style = style
        self.root = root
        self.destination = destination
        self.dialog = dialog
    }

    public var body: some View {
        FlowStackLayer(
            router: router,
            index: 0,
            style: style,
            root: root,
            destination: destination
        )
        .id(router.rootID)
        .overlay {
            if let dialog {
                dialog(
                    Binding(
                        get: { router.globalDialog },
                        set: { newValue in
                            if newValue == nil {
                                router.hideGlobalDialog()
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

private struct FlowStackLayer<Route: Hashable, Dialog, Root: View, Destination: View>: View {
    @ObservedObject var router: FlowRouter<Route, Dialog>
    let index: Int
    let style: FlowNavigationStyle
    let root: (Route) -> Root
    let destination: (Route) -> Destination

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
                        root(stack.root)
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
                                destination(node.route)
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
                    root: root,
                    destination: destination
                )
            )
        }
    }
}

private struct FlowPresentationLayer<Route: Hashable, Dialog, Root: View, Destination: View>: ViewModifier {
    @ObservedObject var router: FlowRouter<Route, Dialog>
    let index: Int
    let style: FlowNavigationStyle
    let root: (Route) -> Root
    let destination: (Route) -> Destination

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
                    FlowStackLayer(router: router, index: index, style: style, root: root, destination: destination)
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
