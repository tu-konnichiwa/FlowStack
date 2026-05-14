import SwiftUI

@MainActor
public extension FlowRouter {
    func bindingForPath(stackID: UUID) -> Binding<[Route]> {
        Binding(
            get: { [weak self] in
                guard let self, let index = self.stacks.firstIndex(where: { $0.id == stackID }) else { return [] }
                return self.stacks[index].path
            },
            set: { [weak self] newValue in
                guard let self, let index = self.stacks.firstIndex(where: { $0.id == stackID }) else { return }
                self.stacks[index].navigationPath = newValue.map { FlowRouteNode(route: $0) }
            }
        )
    }

    internal func bindingForNavigationPath(stackID: UUID) -> Binding<[FlowRouteNode<Route>]> {
        Binding(
            get: { [weak self] in
                guard let self, let index = self.stacks.firstIndex(where: { $0.id == stackID }) else { return [] }
                return self.stacks[index].navigationPath
            },
            set: { [weak self] newValue in
                guard let self, let index = self.stacks.firstIndex(where: { $0.id == stackID }) else { return }
                self.stacks[index].navigationPath = newValue
            }
        )
    }

    func bindingForPresentedStack(style: FlowPresentationStyle) -> Binding<FlowStackState<Route>?> {
        Binding(
            get: { [weak self] in
                self?.stacks.last(where: { $0.style == style })
            },
            set: { [weak self] newValue in
                guard let self, newValue == nil else { return }
                if let index = self.stacks.lastIndex(where: { $0.style == style }) {
                    self.dismissStack(at: index)
                }
            }
        )
    }
}
