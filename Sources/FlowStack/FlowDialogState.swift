/// A single owner for dialog scheduling policy, shared by both router adapters.
internal struct FlowDialogState<Dialog> {
    var visible: Dialog? {
        didSet { didChangeVisible = true }
    }
    var queue: [Dialog] {
        didSet { didChangeQueue = true }
    }
    private(set) var didChangeVisible = false
    private(set) var didChangeQueue = false

    mutating func show(_ dialog: Dialog, policy: FlowDialogPolicy) {
        switch policy {
        case .replace:
            queue.removeAll()
            visible = dialog
        case .replaceKeepingQueue:
            visible = dialog
        case .queue:
            if visible == nil { visible = dialog } else { queue.append(dialog) }
        case .interrupt:
            if let visible { queue.insert(visible, at: 0) }
            visible = dialog
        case .ignoreIfVisible:
            if visible == nil { visible = dialog }
        }
    }

    mutating func hide() {
        visible = queue.isEmpty ? nil : queue.removeFirst()
    }

    mutating func clear() {
        queue.removeAll()
        visible = nil
    }
}
