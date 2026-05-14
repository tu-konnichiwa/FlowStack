import Foundation

@MainActor
public extension FlowRouter {
    func showGlobalDialog(_ dialog: Dialog, policy: FlowDialogPolicy = .replace) {
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
        case .ignoreIfVisible:
            if globalDialog == nil {
                globalDialog = dialog
            }
        }
    }

    func hideGlobalDialog() {
        if dialogQueue.isEmpty {
            globalDialog = nil
        } else {
            globalDialog = dialogQueue.removeFirst()
        }
    }

    func clearGlobalDialogs() {
        dialogQueue.removeAll()
        globalDialog = nil
    }
}
