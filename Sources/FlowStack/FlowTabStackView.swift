import SwiftUI

/// SwiftUI TabView host with independent navigation per tab.
/// Render app-wide dialogs through this host; child-router dialogs are not displayed.
/// Only the selected tab's topmost presentation renders the tab router's dialogs.
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

    /// Creates route screens and tab labels; optional legacy dialog builders return AnyView.
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

    /// Accepts any dialog view; dialog state is owned by the tab router.
    public init<DialogContent: View>(
        router: FlowTabRouter<Tab, Route, Dialog>,
        style: FlowNavigationStyle = .default,
        @ViewBuilder screen: @escaping (Route) -> Screen,
        @ViewBuilder label: @escaping (Tab) -> Label,
        @ViewBuilder dialog: @escaping (Binding<Dialog?>) -> DialogContent
    ) {
        self.router = router
        self.style = style
        self.screen = screen
        self.label = label
        self.dialog = { AnyView(dialog($0)) }
    }

    public var body: some View {
        TabView(selection: router.bindingForSelectedTab()) {
            ForEach(router.tabs) { tab in
                FlowStackView(
                    router: router.router(for: tab.id),
                    style: style,
                    screen: screen,
                    dialog: tab.id == router.selectedTab ? hostedDialog : nil
                )
                .tag(tab.id)
                .tabItem { label(tab.id) }
            }
        }
    }

    private var hostedDialog: ((Binding<Dialog?>) -> AnyView)? {
        guard let dialog else { return nil }
        let visibleID = router.globalDialog?.id
        return { _ in
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
}
