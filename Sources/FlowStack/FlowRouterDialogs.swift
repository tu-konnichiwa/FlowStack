import Foundation

@MainActor
public extension FlowRouter {
    /// Shows/schedules a dialog using the chosen policy; default replace clears the queue.
    func showGlobalDialog(_ dialog: Dialog, policy: FlowDialogPolicy = .replace) {
        updateDialogs { $0.show(dialog, policy: policy) }
    }

    /// Dismisses the visible dialog and promotes the next waiting dialog, if any.
    func hideGlobalDialog() {
        updateDialogs { $0.hide() }
    }

    /// Removes the visible dialog and all waiting dialogs.
    func clearGlobalDialogs() {
        updateDialogs { $0.clear() }
    }

    private func updateDialogs(_ mutation: (inout FlowDialogState<Dialog>) -> Void) {
        var state = FlowDialogState(visible: globalDialog, queue: dialogQueue)
        mutation(&state)
        if state.didChangeQueue { dialogQueue = state.queue }
        if state.didChangeVisible { globalDialog = state.visible }
    }
}

@MainActor
public extension FlowRouter where Dialog: Identifiable {
    /// Dismisses only if the visible ID matches; nil is an unconditional dismissal. Use unique instance IDs for repeated dialogs.
    func hideGlobalDialog(id: Dialog.ID?) {
        if let id, globalDialog?.id != id {
            return
        }

        hideGlobalDialog()
    }
}
