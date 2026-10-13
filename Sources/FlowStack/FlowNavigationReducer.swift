import Foundation

/// Navigation invariants belong here; this value transformation has no UI or I/O dependency.
internal enum FlowNavigationReducer {
    static func reduce<Route: Hashable>(
        _ operation: FlowOperation<Route>,
        stacks: inout [FlowStackState<Route>],
        path: [Route] = [],
        options: FlowPresentationOptions = .init(),
        refreshIfSameRoute: Bool = true
    ) -> FlowOperationOutcome {
        switch operation {
        case .setRoot(let route):
            if !refreshIfSameRoute, stacks[0].root == route {
                var root = stacks[0]
                root.navigationPath = path.map { FlowRouteNode(route: $0) }
                stacks = [root]
            } else {
                stacks = [FlowStackState(root: route, path: path)]
            }
            return .applied
        case .present(let route, let style):
            guard style != .root else { return .invalidPresentationStyle }
            stacks.append(FlowStackState(root: route, path: path, style: style, options: options))
            return .applied
        case .dismissAll:
            stacks = [stacks[0]]
            return .applied
        default:
            break
        }

        let target: FlowStackTarget
        switch operation {
        case .push(_, let value), .pushRemovingPrevious(_, let value),
             .replaceCurrent(_, let value), .replacePath(_, _, let value),
             .pop(_, let value), .popToRoot(let value), .popTo(_, _, let value),
             .dismiss(let value):
            target = value
        default:
            return .invalidTarget
        }
        let index: Int
        switch target {
        case .root: index = 0
        case .active: index = stacks.count - 1
        case .stack(let id):
            guard let found = stacks.firstIndex(where: { $0.id == id }) else { return .invalidTarget }
            index = found
        }

        switch operation {
        case .push(let route, _):
            stacks[index].navigationPath.append(FlowRouteNode(route: route))
        case .pushRemovingPrevious(let route, _), .replaceCurrent(let route, _):
            if stacks[index].navigationPath.isEmpty {
                stacks[index].root = route
                stacks[index].rootID = UUID()
            } else {
                stacks[index].navigationPath[stacks[index].navigationPath.count - 1] = FlowRouteNode(route: route)
            }
        case .replacePath(let root, let path, _):
            stacks[index].root = root
            stacks[index].rootID = UUID()
            stacks[index].navigationPath = path.map { FlowRouteNode(route: $0) }
        case .pop(let count, _):
            guard count > 0 else { return .applied }
            let removable = min(count, stacks[index].navigationPath.count)
            stacks[index].navigationPath.removeLast(removable)
            if removable < count { dismissStack(at: index, stacks: &stacks) }
        case .popToRoot:
            stacks[index].navigationPath.removeAll()
        case .popTo(let route, let match, _):
            guard let found = stacks[index].navigationPath.lastIndex(where: { $0.route == route }) else {
                return .routeNotFound
            }
            let keptCount = match == .inclusive ? found : found + 1
            stacks[index].navigationPath = Array(stacks[index].navigationPath.prefix(keptCount))
        case .dismiss:
            dismissStack(at: index, stacks: &stacks)
        default:
            break
        }
        return .applied
    }

    static func dismissStack<Route: Hashable>(at index: Int, stacks: inout [FlowStackState<Route>]) {
        guard index > 0, stacks.indices.contains(index) else { return }
        if stacks[index].options.clearsNestedPresentationOnDismiss {
            stacks.removeSubrange(index...)
        } else {
            stacks.remove(at: index)
        }
    }
}
