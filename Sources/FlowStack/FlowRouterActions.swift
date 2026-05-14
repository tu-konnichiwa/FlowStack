import Foundation

@MainActor
public extension FlowRouter {
    @discardableResult
    func setRoot(
        _ route: Route,
        path: [Route] = [],
        refreshIfSameRoute: Bool = true,
        condition: Precondition? = nil
    ) -> Bool {
        apply(.setRoot(route), precondition: condition) {
            if refreshIfSameRoute, stacks.first?.root == route {
                rootID = UUID()
            }
            stacks = [FlowStackState(root: route, path: path)]
        }
    }

    @discardableResult
    func push(
        _ route: Route,
        on target: FlowStackTarget = .active,
        condition: Precondition? = nil
    ) -> Bool {
        apply(.push(route, target: target), precondition: condition) {
            guard let index = index(for: target) else { return }
            stacks[index].navigationPath.append(FlowRouteNode(route: route))
        }
    }

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

    @discardableResult
    func pushRemovingPrevious(
        _ route: Route,
        on target: FlowStackTarget = .active,
        condition: Precondition? = nil
    ) -> Bool {
        apply(.pushRemovingPrevious(route, target: target), precondition: condition) {
            guard let index = index(for: target) else { return }
            if stacks[index].navigationPath.isEmpty {
                stacks[index].root = route
                stacks[index].rootID = UUID()
            } else {
                stacks[index].navigationPath.append(FlowRouteNode(route: route))
                stacks[index].navigationPath.remove(at: stacks[index].navigationPath.count - 2)
            }
        }
    }

    @discardableResult
    func replaceCurrent(
        with route: Route,
        on target: FlowStackTarget = .active,
        condition: Precondition? = nil
    ) -> Bool {
        apply(.replaceCurrent(route, target: target), precondition: condition) {
            guard let index = index(for: target) else { return }
            if stacks[index].navigationPath.isEmpty {
                stacks[index].root = route
                stacks[index].rootID = UUID()
            } else {
                stacks[index].navigationPath[stacks[index].navigationPath.count - 1] = FlowRouteNode(route: route)
            }
        }
    }

    @discardableResult
    func replacePath(
        root: Route,
        path: [Route] = [],
        on target: FlowStackTarget = .active,
        condition: Precondition? = nil
    ) -> Bool {
        apply(.replacePath(root: root, path: path, target: target), precondition: condition) {
            guard let index = index(for: target) else { return }
            stacks[index].root = root
            stacks[index].rootID = UUID()
            stacks[index].navigationPath = path.map { FlowRouteNode(route: $0) }
        }
    }

    @discardableResult
    func pop(
        count: Int = 1,
        on target: FlowStackTarget = .active,
        condition: Precondition? = nil
    ) -> Bool {
        guard count > 0 else { return true }
        return apply(.pop(count: count, target: target), precondition: condition) {
            guard let index = index(for: target) else { return }
            let removable = min(count, stacks[index].navigationPath.count)
            stacks[index].navigationPath.removeLast(removable)
            if removable < count, index > 0 {
                dismissStack(at: index)
            }
        }
    }

    @discardableResult
    func popToRoot(
        on target: FlowStackTarget = .active,
        condition: Precondition? = nil
    ) -> Bool {
        apply(.popToRoot(target: target), precondition: condition) {
            guard let index = index(for: target) else { return }
            stacks[index].navigationPath.removeAll()
        }
    }

    @discardableResult
    func popTo(
        _ route: Route,
        match: FlowPopMatch = .exclusive,
        on target: FlowStackTarget = .active,
        condition: Precondition? = nil
    ) -> Bool {
        guard let index = index(for: target) else { return false }
        guard stacks[index].path.contains(route) else { return false }
        return apply(.popTo(route, match: match, target: target), precondition: condition) {
            guard let routeIndex = stacks[index].navigationPath.lastIndex(where: { $0.route == route }) else { return }
            let keptCount = match == .inclusive ? routeIndex : routeIndex + 1
            stacks[index].navigationPath = Array(stacks[index].navigationPath.prefix(keptCount))
        }
    }

    @discardableResult
    func present(
        _ route: Route,
        style: FlowPresentationStyle = .sheet,
        path: [Route] = [],
        options: FlowPresentationOptions = .init(),
        condition: Precondition? = nil
    ) -> Bool {
        precondition(style != .root, "Use setRoot(_:path:) for root replacement.")
        return apply(.present(route, style: style), precondition: condition) {
            stacks.append(FlowStackState(root: route, path: path, style: style, options: options))
        }
    }

    @discardableResult
    func sheet(
        _ route: Route,
        path: [Route] = [],
        options: FlowPresentationOptions = .init(),
        condition: Precondition? = nil
    ) -> Bool {
        present(route, style: .sheet, path: path, options: options, condition: condition)
    }

    @discardableResult
    func fullScreenCover(
        _ route: Route,
        path: [Route] = [],
        options: FlowPresentationOptions = .init(),
        condition: Precondition? = nil
    ) -> Bool {
        present(route, style: .fullScreenCover, path: path, options: options, condition: condition)
    }

    @discardableResult
    func dismiss(
        _ target: FlowStackTarget = .active,
        condition: Precondition? = nil
    ) -> Bool {
        apply(.dismiss(target: target), precondition: condition) {
            switch target {
            case .root:
                break
            case .active:
                guard stacks.count > 1 else { return }
                dismissStack(at: activeIndex)
            case .stack(let id):
                guard let index = stacks.firstIndex(where: { $0.id == id }), index > 0 else { return }
                dismissStack(at: index)
            }
        }
    }

    @discardableResult
    func dismissAll(condition: Precondition? = nil) -> Bool {
        apply(.dismissAll, precondition: condition) {
            guard let root = stacks.first else { return }
            stacks = [root]
        }
    }
}
