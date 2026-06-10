import SwiftUI

public struct FlowTabStackView<
    Tab: Hashable,
    Route: Hashable,
    Dialog: Identifiable,
    Screen: View,
    Label: View
>: View {
    @ObservedObject private var router: FlowTabRouter<Tab, Route, Dialog>
    private let style: FlowNavigationStyle
    private let screen: (Route) -> Screen
    private let label: (Tab) -> Label
    private let dialog: ((Binding<Dialog?>) -> AnyView)?

    public init(
        router: FlowTabRouter<Tab, Route, Dialog>,
        style: FlowNavigationStyle = .default,
        @ViewBuilder screen: @escaping (Route) -> Screen,
        @ViewBuilder label: @escaping (Tab) -> Label,
        dialog: ((Binding<Dialog?>) -> AnyView)? = nil
    ) {
        self.router = router
        self.style = style
        self.screen = screen
        self.label = label
        self.dialog = dialog
    }

    public var body: some View {
        TabView(selection: router.bindingForSelectedTab()) {
            ForEach(router.tabs) { tab in
                FlowStackView(
                    router: router.router(for: tab.id),
                    style: style,
                    screen: screen
                )
                .tag(tab.id)
                .tabItem {
                    label(tab.id)
                }
            }
        }
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
