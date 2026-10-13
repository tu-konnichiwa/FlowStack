import SwiftUI

@MainActor
public extension FlowRouter {
    /// SwiftUI path adapter. Writes bypass command guards/history (including native back gestures).
    /// Preserves existing equal prefix identities. A removed stack reads empty and ignores writes.
    func bindingForPath(stackID: UUID) -> Binding<[Route]> {
        Binding(
            get: { [weak self] in
                guard let self, let index = self.stacks.firstIndex(where: { $0.id == stackID }) else { return [] }
                return self.stacks[index].path
            },
            set: { [weak self] newValue in
                guard let self, let index = self.stacks.firstIndex(where: { $0.id == stackID }) else { return }
                let oldPath = self.stacks[index].navigationPath
                self.stacks[index].navigationPath = newValue.enumerated().map { offset, route in
                    if offset < oldPath.count, oldPath[offset].route == route {
                        return oldPath[offset]
                    }
                    return FlowRouteNode(route: route)
                }
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

    /// Presentation adapter. Writing nil dismisses the stack captured when the binding was created,
    /// if it still exists. Non-nil writes are ignored; use present to create modal stacks.
    /// Native updates bypass guards/history. Recreate the binding as presentation state changes.
    func bindingForPresentedStack(style: FlowPresentationStyle) -> Binding<FlowStackState<Route>?> {
        let presentedID = stacks.last(where: { $0.style == style })?.id
        return Binding(
            get: { [weak self] in
                self?.stacks.last(where: { $0.style == style })
            },
            set: { [weak self] newValue in
                guard let self, newValue == nil, let presentedID,
                      let index = self.stacks.firstIndex(where: { $0.id == presentedID }) else { return }
                self.dismissStack(at: index)
            }
        )
    }
}
