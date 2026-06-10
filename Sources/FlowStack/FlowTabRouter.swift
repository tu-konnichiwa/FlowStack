import Combine
import Foundation
import SwiftUI

public struct FlowTab<Tab: Hashable, Route: Hashable>: Identifiable, Hashable {
    public let id: Tab
    public var root: Route
    public var path: [Route]

    public init(_ id: Tab, root: Route, path: [Route] = []) {
        self.id = id
        self.root = root
        self.path = path
    }
}

@MainActor
public final class FlowTabRouter<Tab: Hashable, Route: Hashable, Dialog: Identifiable>: ObservableObject {
    public typealias Router = FlowRouter<Route, Dialog>
    public typealias Precondition = Router.Precondition

    public let tabs: [FlowTab<Tab, Route>]
    @Published public var selectedTab: Tab
    @Published public internal(set) var globalDialog: Dialog?
    @Published var dialogQueue: [Dialog] = []

    private var routers: [Tab: Router]
    private var childCancellables: [AnyCancellable] = []

    public init(
        tabs: [FlowTab<Tab, Route>],
        selectedTab: Tab? = nil
    ) {
        precondition(!tabs.isEmpty, "FlowTabRouter requires at least one tab.")

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

    public var activeRouter: Router {
        router(for: selectedTab)
    }

    public var queuedGlobalDialogCount: Int {
        dialogQueue.count
    }

    public func router(for tab: Tab) -> Router {
        guard let router = routers[tab] else {
            preconditionFailure("Unknown FlowTabRouter tab: \(tab)")
        }
        return router
    }

    public func selectTab(_ tab: Tab) {
        guard routers[tab] != nil else {
            preconditionFailure("Unknown FlowTabRouter tab: \(tab)")
        }
        selectedTab = tab
    }

    public func bindingForSelectedTab() -> Binding<Tab> {
        Binding(
            get: { self.selectedTab },
            set: { self.selectTab($0) }
        )
    }

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

    @discardableResult
    public func push(
        _ route: Route,
        on tab: Tab? = nil,
        target: FlowStackTarget = .active,
        condition: Precondition? = nil
    ) -> Bool {
        router(for: tab ?? selectedTab).push(route, on: target, condition: condition)
    }

    @discardableResult
    public func push(
        contentsOf routes: [Route],
        on tab: Tab? = nil,
        target: FlowStackTarget = .active,
        condition: Precondition? = nil
    ) -> Bool {
        router(for: tab ?? selectedTab).push(contentsOf: routes, on: target, condition: condition)
    }

    @discardableResult
    public func pushRemovingPrevious(
        _ route: Route,
        on tab: Tab? = nil,
        target: FlowStackTarget = .active,
        condition: Precondition? = nil
    ) -> Bool {
        router(for: tab ?? selectedTab).pushRemovingPrevious(route, on: target, condition: condition)
    }

    @discardableResult
    public func replaceCurrent(
        with route: Route,
        on tab: Tab? = nil,
        target: FlowStackTarget = .active,
        condition: Precondition? = nil
    ) -> Bool {
        router(for: tab ?? selectedTab).replaceCurrent(with: route, on: target, condition: condition)
    }

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

    @discardableResult
    public func pop(
        count: Int = 1,
        on tab: Tab? = nil,
        target: FlowStackTarget = .active,
        condition: Precondition? = nil
    ) -> Bool {
        router(for: tab ?? selectedTab).pop(count: count, on: target, condition: condition)
    }

    @discardableResult
    public func popToRoot(
        on tab: Tab? = nil,
        target: FlowStackTarget = .active,
        condition: Precondition? = nil
    ) -> Bool {
        router(for: tab ?? selectedTab).popToRoot(on: target, condition: condition)
    }

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

    @discardableResult
    public func dismiss(
        _ target: FlowStackTarget = .active,
        on tab: Tab? = nil,
        condition: Precondition? = nil
    ) -> Bool {
        router(for: tab ?? selectedTab).dismiss(target, condition: condition)
    }

    @discardableResult
    public func dismissAll(
        on tab: Tab? = nil,
        condition: Precondition? = nil
    ) -> Bool {
        router(for: tab ?? selectedTab).dismissAll(condition: condition)
    }

    public func showGlobalDialog(_ dialog: Dialog, policy: FlowDialogPolicy = .replace) {
        switch policy {
        case .replace:
            dialogQueue.removeAll()
            globalDialog = dialog
        case .replaceKeepingQueue:
            globalDialog = dialog
        case .queue:
            if globalDialog == nil {
                globalDialog = dialog
            } else {
                dialogQueue.append(dialog)
            }
        case .interrupt:
            if let globalDialog {
                dialogQueue.insert(globalDialog, at: 0)
            }
            globalDialog = dialog
        case .ignoreIfVisible:
            if globalDialog == nil {
                globalDialog = dialog
            }
        }
    }

    public func hideGlobalDialog() {
        if dialogQueue.isEmpty {
            globalDialog = nil
        } else {
            globalDialog = dialogQueue.removeFirst()
        }
    }

    public func hideGlobalDialog(id: Dialog.ID?) {
        if let id, globalDialog?.id != id {
            return
        }

        hideGlobalDialog()
    }

    public func clearGlobalDialogs() {
        dialogQueue.removeAll()
        globalDialog = nil
    }

    private func observeChildRouters() {
        childCancellables = routers.values.map { router in
            router.objectWillChange.sink { [weak self] _ in
                self?.objectWillChange.send()
            }
        }
    }
}
