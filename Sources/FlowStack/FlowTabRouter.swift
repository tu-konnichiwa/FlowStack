import Combine
import Foundation
import SwiftUI

/// Tab configuration with an initial root/path. Tab IDs must be unique and stable.
public struct FlowTab<Tab: Hashable, Route: Hashable>: Identifiable, Hashable {
    /// Stable tab-selection identity; must be unique in a router's configuration.
    public let id: Tab
    /// Initial root route for this tab's child stack.
    public var root: Route
    /// Initial pushed route path; live path state belongs to the child router.
    public var path: [Route]

    public init(_ id: Tab, root: Route, path: [Route] = []) {
        self.id = id
        self.root = root
        self.path = path
    }
}

/// Owns independent child flows, selected tab, and app-wide dialogs on MainActor.
/// Configure a nonempty list with unique IDs. Retain it with StateObject.
/// Child navigation is observed; global dialogs belong to this router, not its children.
/// Use child routers for async guards, history, or commands beyond the forwarding API.
@MainActor
public final class FlowTabRouter<Tab: Hashable, Route: Hashable, Dialog: Identifiable>: ObservableObject {
    /// A child router that owns navigation, guards, and operation history for one tab.
    public typealias Router = FlowRouter<Route, Dialog>
    /// Sync gate accepted by the tab router's forwarding commands.
    public typealias Precondition = Router.Precondition

    /// Initial configuration in display order; current paths live in the child routers.
    public let tabs: [FlowTab<Tab, Route>]
    /// Selected configured ID. Assigning an unknown ID is a programmer error; use selectTabIfPresent for external data.
    @Published public var selectedTab: Tab {
        willSet {
            precondition(routers[newValue] != nil, "selectedTab must be included in tabs. Use selectTabIfPresent for external input.")
        }
    }
    /// Visible app-wide dialog; render with FlowTabStackView.
    @Published public internal(set) var globalDialog: Dialog?
    /// Published waiting dialogs, excluding globalDialog.
    @Published var dialogQueue: [Dialog] = []

    private var routers: [Tab: Router]
    private var childCancellables: [AnyCancellable] = []

    /// Creates tabs and selects the supplied ID or first tab. Empty/duplicate/unknown configuration fails a precondition.
    public init(
        tabs: [FlowTab<Tab, Route>],
        selectedTab: Tab? = nil
    ) {
        precondition(!tabs.isEmpty, "FlowTabRouter requires at least one tab.")

        precondition(Set(tabs.map(\.id)).count == tabs.count, "FlowTabRouter tab IDs must be unique.")
        self.tabs = tabs
        self.selectedTab = selectedTab ?? tabs[0].id
        self.routers = Dictionary(
            uniqueKeysWithValues: tabs.map { tab in
                (tab.id, Router(root: tab.root, path: tab.path))
            }
        )

        precondition(self.routers[self.selectedTab] != nil, "selectedTab must be included in tabs.")
        observeChildRouters()
    }

    /// Child router for the selected tab.
    public var activeRouter: Router {
        router(for: selectedTab)
    }

    /// Waiting dialogs, excluding the visible one.
    public var queuedGlobalDialogCount: Int {
        dialogQueue.count
    }

    /// Returns nil for an unknown tab, suitable for parsed deep links or external input.
    public func routerIfPresent(for tab: Tab) -> Router? {
        routers[tab]
    }

    /// Selects a configured tab, returning false without changing selection for unknown IDs.
    @discardableResult
    public func selectTabIfPresent(_ tab: Tab) -> Bool {
        guard routers[tab] != nil else { return false }
        selectedTab = tab
        return true
    }

    /// Returns a configured child. Unknown IDs fail a precondition; use routerIfPresent for external input.
    public func router(for tab: Tab) -> Router {
        guard let router = routers[tab] else {
            preconditionFailure("Unknown FlowTabRouter tab: \(tab)")
        }
        return router
    }

    /// Selects a configured ID without resetting navigation; unknown IDs fail a precondition.
    public func selectTab(_ tab: Tab) {
        guard routers[tab] != nil else {
            preconditionFailure("Unknown FlowTabRouter tab: \(tab)")
        }
        selectedTab = tab
    }

    /// SwiftUI selection adapter that validates configured IDs.
    public func bindingForSelectedTab() -> Binding<Tab> {
        Binding(
            get: { self.selectedTab },
            set: { self.selectTab($0) }
        )
    }

    /// Forwards setRoot to the specified tab, or selected tab by default; selection is unchanged.
    /// Shares FlowRouter command semantics. Unknown tab IDs are programmer errors.
    @discardableResult
    public func setRoot(
        _ route: Route,
        path: [Route] = [],
        refreshIfSameRoute: Bool = true,
        on tab: Tab? = nil,
        condition: Precondition? = nil
    ) -> Bool {
        router(for: tab ?? selectedTab).setRoot(
            route,
            path: path,
            refreshIfSameRoute: refreshIfSameRoute,
            condition: condition
        )
    }

    /// Forwards push to the specified tab, or selected tab by default; selection is unchanged.
    /// Shares FlowRouter command semantics. Unknown tab IDs are programmer errors.
    @discardableResult
    public func push(
        _ route: Route,
        on tab: Tab? = nil,
        target: FlowStackTarget = .active,
        condition: Precondition? = nil
    ) -> Bool {
        router(for: tab ?? selectedTab).push(route, on: target, condition: condition)
    }

    /// Forwards push to the specified tab, or selected tab by default; selection is unchanged.
    /// Shares FlowRouter command semantics. Unknown tab IDs are programmer errors.
    @discardableResult
    public func push(
        contentsOf routes: [Route],
        on tab: Tab? = nil,
        target: FlowStackTarget = .active,
        condition: Precondition? = nil
    ) -> Bool {
        router(for: tab ?? selectedTab).push(contentsOf: routes, on: target, condition: condition)
    }

    /// Forwards pushRemovingPrevious to the specified tab, or selected tab by default; selection is unchanged.
    /// Shares FlowRouter command semantics. Unknown tab IDs are programmer errors.
    @discardableResult
    public func pushRemovingPrevious(
        _ route: Route,
        on tab: Tab? = nil,
        target: FlowStackTarget = .active,
        condition: Precondition? = nil
    ) -> Bool {
        router(for: tab ?? selectedTab).pushRemovingPrevious(route, on: target, condition: condition)
    }

    /// Forwards replaceCurrent to the specified tab, or selected tab by default; selection is unchanged.
    /// Shares FlowRouter command semantics. Unknown tab IDs are programmer errors.
    @discardableResult
    public func replaceCurrent(
        with route: Route,
        on tab: Tab? = nil,
        target: FlowStackTarget = .active,
        condition: Precondition? = nil
    ) -> Bool {
        router(for: tab ?? selectedTab).replaceCurrent(with: route, on: target, condition: condition)
    }

    /// Forwards replacePath to the specified tab, or selected tab by default; selection is unchanged.
    /// Shares FlowRouter command semantics. Unknown tab IDs are programmer errors.
    @discardableResult
    public func replacePath(
        root: Route,
        path: [Route] = [],
        on tab: Tab? = nil,
        target: FlowStackTarget = .active,
        condition: Precondition? = nil
    ) -> Bool {
        router(for: tab ?? selectedTab).replacePath(root: root, path: path, on: target, condition: condition)
    }

    /// Forwards pop to the specified tab, or selected tab by default; selection is unchanged.
    /// Shares FlowRouter command semantics. Unknown tab IDs are programmer errors.
    @discardableResult
    public func pop(
        count: Int = 1,
        on tab: Tab? = nil,
        target: FlowStackTarget = .active,
        condition: Precondition? = nil
    ) -> Bool {
        router(for: tab ?? selectedTab).pop(count: count, on: target, condition: condition)
    }

    /// Forwards popToRoot to the specified tab, or selected tab by default; selection is unchanged.
    /// Shares FlowRouter command semantics. Unknown tab IDs are programmer errors.
    @discardableResult
    public func popToRoot(
        on tab: Tab? = nil,
        target: FlowStackTarget = .active,
        condition: Precondition? = nil
    ) -> Bool {
        router(for: tab ?? selectedTab).popToRoot(on: target, condition: condition)
    }

    /// Forwards popTo to the specified tab, or selected tab by default; selection is unchanged.
    /// Shares FlowRouter command semantics. Unknown tab IDs are programmer errors.
    @discardableResult
    public func popTo(
        _ route: Route,
        match: FlowPopMatch = .exclusive,
        on tab: Tab? = nil,
        target: FlowStackTarget = .active,
        condition: Precondition? = nil
    ) -> Bool {
        router(for: tab ?? selectedTab).popTo(route, match: match, on: target, condition: condition)
    }

    /// Forwards present to the specified tab, or selected tab by default; selection is unchanged.
    /// Shares FlowRouter command semantics. Unknown tab IDs are programmer errors.
    @discardableResult
    public func present(
        _ route: Route,
        style: FlowPresentationStyle = .sheet,
        path: [Route] = [],
        options: FlowPresentationOptions = .init(),
        on tab: Tab? = nil,
        condition: Precondition? = nil
    ) -> Bool {
        router(for: tab ?? selectedTab).present(
            route,
            style: style,
            path: path,
            options: options,
            condition: condition
        )
    }

    /// Forwards sheet to the specified tab, or selected tab by default; selection is unchanged.
    /// Shares FlowRouter command semantics. Unknown tab IDs are programmer errors.
    @discardableResult
    public func sheet(
        _ route: Route,
        path: [Route] = [],
        options: FlowPresentationOptions = .init(),
        on tab: Tab? = nil,
        condition: Precondition? = nil
    ) -> Bool {
        present(route, style: .sheet, path: path, options: options, on: tab, condition: condition)
    }

    /// Forwards fullScreenCover to the specified tab, or selected tab by default; selection is unchanged.
    /// Shares FlowRouter command semantics. Unknown tab IDs are programmer errors.
    @discardableResult
    public func fullScreenCover(
        _ route: Route,
        path: [Route] = [],
        options: FlowPresentationOptions = .init(),
        on tab: Tab? = nil,
        condition: Precondition? = nil
    ) -> Bool {
        present(route, style: .fullScreenCover, path: path, options: options, on: tab, condition: condition)
    }

    /// Forwards dismiss to the specified tab, or selected tab by default; selection is unchanged.
    /// Shares FlowRouter command semantics. Unknown tab IDs are programmer errors.
    @discardableResult
    public func dismiss(
        _ target: FlowStackTarget = .active,
        on tab: Tab? = nil,
        condition: Precondition? = nil
    ) -> Bool {
        router(for: tab ?? selectedTab).dismiss(target, condition: condition)
    }

    /// Forwards dismissAll to the specified tab, or selected tab by default; selection is unchanged.
    /// Shares FlowRouter command semantics. Unknown tab IDs are programmer errors.
    @discardableResult
    public func dismissAll(
        on tab: Tab? = nil,
        condition: Precondition? = nil
    ) -> Bool {
        router(for: tab ?? selectedTab).dismissAll(condition: condition)
    }

    /// Schedules an app-wide dialog. The default replace policy clears waiting dialogs.
    public func showGlobalDialog(_ dialog: Dialog, policy: FlowDialogPolicy = .replace) {
        updateDialogs { $0.show(dialog, policy: policy) }
    }

    /// Hides the visible app-wide dialog and promotes the next waiting one.
    public func hideGlobalDialog() {
        updateDialogs { $0.hide() }
    }

    /// Ignores stale IDs; nil hides unconditionally. Dialog instance IDs should be unique.
    public func hideGlobalDialog(id: Dialog.ID?) {
        if let id, globalDialog?.id != id {
            return
        }

        hideGlobalDialog()
    }

    /// Clears the visible app-wide dialog and all waiting dialogs.
    public func clearGlobalDialogs() {
        updateDialogs { $0.clear() }
    }

    private func updateDialogs(_ mutation: (inout FlowDialogState<Dialog>) -> Void) {
        var state = FlowDialogState(visible: globalDialog, queue: dialogQueue)
        mutation(&state)
        if state.didChangeQueue { dialogQueue = state.queue }
        if state.didChangeVisible { globalDialog = state.visible }
    }

    private func observeChildRouters() {
        childCancellables = routers.values.map { router in
            router.objectWillChange.sink { [weak self] _ in
                self?.objectWillChange.send()
            }
        }
    }
}
