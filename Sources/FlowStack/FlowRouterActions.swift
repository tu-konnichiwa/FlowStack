import Foundation

@MainActor
public extension FlowRouter {
    /// Replaces the root and path and dismisses every modal. Dialogs are retained.
    /// If the root is unchanged and refreshIfSameRoute is false, preserves root/stack identity.
    /// Otherwise creates fresh screen identities. Returns false when blocked.
    @discardableResult
    func setRoot(
        _ route: Route,
        path: [Route] = [],
        refreshIfSameRoute: Bool = true,
        condition: Precondition? = nil
    ) -> Bool {
        let previousRoot = rootStack.root
        let result = apply(.setRoot(route), precondition: condition) {
            let outcome = FlowNavigationReducer.reduce(.setRoot(route), stacks: &stacks, path: path,
                                                        refreshIfSameRoute: refreshIfSameRoute)
            if refreshIfSameRoute, previousRoot == route { rootID = UUID() }
            return outcome
        }
        return result
    }

    /// Appends a fresh screen instance on the selected stack (active by default).
    /// Repeated equal route values remain distinct screens. Missing targets return false.
    @discardableResult
    func push(
        _ route: Route,
        on target: FlowStackTarget = .active,
        condition: Precondition? = nil
    ) -> Bool {
        apply(.push(route, target: target), precondition: condition) {
            FlowNavigationReducer.reduce(.push(route, target: target), stacks: &stacks)
        }
    }

    /// Pushes each route in order; continues after a rejected route and returns aggregate success.
    /// This is not atomic. An empty list succeeds without guards or a history record.
    @discardableResult
    func push(
        contentsOf routes: [Route],
        on target: FlowStackTarget = .active,
        condition: Precondition? = nil
    ) -> Bool {
        guard !routes.isEmpty else { return true }
        var applied = true
        for route in routes {
            applied = push(route, on: target, condition: condition) && applied
        }
        return applied
    }

    /// Replaces the last pushed screen, or the stack root when its path is empty.
    /// The new screen receives a fresh identity; missing targets return false.
    @discardableResult
    func pushRemovingPrevious(
        _ route: Route,
        on target: FlowStackTarget = .active,
        condition: Precondition? = nil
    ) -> Bool {
        apply(.pushRemovingPrevious(route, target: target), precondition: condition) {
            FlowNavigationReducer.reduce(.pushRemovingPrevious(route, target: target), stacks: &stacks)
        }
    }

    /// Replaces the top screen without changing depth; refreshes identity even for an equal route.
    @discardableResult
    func replaceCurrent(
        with route: Route,
        on target: FlowStackTarget = .active,
        condition: Precondition? = nil
    ) -> Bool {
        apply(.replaceCurrent(route, target: target), precondition: condition) {
            FlowNavigationReducer.reduce(.replaceCurrent(route, target: target), stacks: &stacks)
        }
    }

    /// Replaces one stack's root and pushed path with fresh screen identities.
    /// Other stacks remain unchanged. Use setRoot to also dismiss all modal stacks.
    @discardableResult
    func replacePath(
        root: Route,
        path: [Route] = [],
        on target: FlowStackTarget = .active,
        condition: Precondition? = nil
    ) -> Bool {
        apply(.replacePath(root: root, path: path, target: target), precondition: condition) {
            FlowNavigationReducer.reduce(.replacePath(root: root, path: path, target: target), stacks: &stacks, path: path)
        }
    }

    /// Removes up to count pushed screens. Excess count dismisses the selected modal,
    /// but never removes the root stack. Nonpositive counts are successful no-ops.
    @discardableResult
    func pop(
        count: Int = 1,
        on target: FlowStackTarget = .active,
        condition: Precondition? = nil
    ) -> Bool {
        guard count > 0 else { return true }
        return apply(.pop(count: count, target: target), precondition: condition) {
            FlowNavigationReducer.reduce(.pop(count: count, target: target), stacks: &stacks)
        }
    }

    /// Clears the selected pushed path while keeping that stack presented.
    @discardableResult
    func popToRoot(
        on target: FlowStackTarget = .active,
        condition: Precondition? = nil
    ) -> Bool {
        apply(.popToRoot(target: target), precondition: condition) {
            FlowNavigationReducer.reduce(.popToRoot(target: target), stacks: &stacks)
        }
    }

    /// Finds the LAST equal route in the pushed path. Exclusive keeps it; inclusive removes it.
    /// Does not match the stack root. A missing route returns false and records routeNotFound.
    @discardableResult
    func popTo(
        _ route: Route,
        match: FlowPopMatch = .exclusive,
        on target: FlowStackTarget = .active,
        condition: Precondition? = nil
    ) -> Bool {
        return apply(.popTo(route, match: match, target: target), precondition: condition) {
            FlowNavigationReducer.reduce(.popTo(route, match: match, target: target), stacks: &stacks)
        }
    }

    /// Appends a modal stack with its own root and path. Root style returns false;
    /// use setRoot for root replacement. Options govern native dismissal behavior.
    @discardableResult
    func present(
        _ route: Route,
        style: FlowPresentationStyle = .sheet,
        path: [Route] = [],
        options: FlowPresentationOptions = .init(),
        condition: Precondition? = nil
    ) -> Bool {
        return apply(.present(route, style: style), precondition: condition) {
            FlowNavigationReducer.reduce(.present(route, style: style), stacks: &stacks, path: path, options: options)
        }
    }

    /// Presents a sheet stack. Configure SwiftUI detents/backgrounds on the screen or modal style.
    @discardableResult
    func sheet(
        _ route: Route,
        path: [Route] = [],
        options: FlowPresentationOptions = .init(),
        condition: Precondition? = nil
    ) -> Bool {
        present(route, style: .sheet, path: path, options: options, condition: condition)
    }

    /// Presents a full-screen stack on iOS; uses a sheet fallback on macOS.
    @discardableResult
    func fullScreenCover(
        _ route: Route,
        path: [Route] = [],
        options: FlowPresentationOptions = .init(),
        condition: Precondition? = nil
    ) -> Bool {
        present(route, style: .fullScreenCover, path: path, options: options, condition: condition)
    }

    /// Dismisses the selected modal and, by default, its nested presentations.
    /// Dismissing the root is a successful no-op; a stale stack ID returns false.
    @discardableResult
    func dismiss(
        _ target: FlowStackTarget = .active,
        condition: Precondition? = nil
    ) -> Bool {
        apply(.dismiss(target: target), precondition: condition) {
            FlowNavigationReducer.reduce(.dismiss(target: target), stacks: &stacks)
        }
    }

    /// Dismisses every modal, preserving the root's path and all global dialogs.
    @discardableResult
    func dismissAll(condition: Precondition? = nil) -> Bool {
        apply(.dismissAll, precondition: condition) {
            FlowNavigationReducer.reduce(.dismissAll, stacks: &stacks)
        }
    }
}
