import Foundation

@MainActor
extension FlowRouter {
    func apply(
        _ operation: FlowOperation<Route>,
        precondition: Precondition?,
        mutation: () -> Void
    ) -> Bool {
        let previousStacks = stacks
        let selectedPrecondition = precondition ?? defaultPreconditions[operation.kind]
        if selectedPrecondition?(operation, previousStacks) == false {
            record(operation, previousStacks: previousStacks, outcome: .blockedByPrecondition)
            return false
        }

        if guardOperation?(operation) == false {
            record(operation, previousStacks: previousStacks, outcome: .blockedByGuard)
            return false
        }
        mutation()
        record(operation, previousStacks: previousStacks, outcome: .applied)
        didApplyOperation?(operation, stacks)
        return true
    }

    func asyncConditionAllows(
        _ operation: FlowOperation<Route>,
        explicit: AsyncPrecondition?
    ) async -> Bool {
        let previousStacks = stacks
        let selectedPrecondition = explicit ?? defaultAsyncPreconditions[operation.kind]
        if await selectedPrecondition?(operation, previousStacks) == false {
            record(operation, previousStacks: previousStacks, outcome: .blockedByPrecondition)
            return false
        }
        return true
    }

    func record(
        _ operation: FlowOperation<Route>,
        previousStacks: [FlowStackState<Route>],
        outcome: FlowOperationOutcome
    ) {
        operationHistory.append(
            FlowOperationRecord(
                operation: operation,
                previousStacks: previousStacks,
                newStacks: stacks,
                outcome: outcome
            )
        )

        if maximumOperationHistoryCount > 0, operationHistory.count > maximumOperationHistoryCount {
            operationHistory.removeFirst(operationHistory.count - maximumOperationHistoryCount)
        }
    }

    func index(for target: FlowStackTarget) -> Int? {
        switch target {
        case .root:
            return 0
        case .active:
            return activeIndex
        case .stack(let id):
            return stacks.firstIndex { $0.id == id }
        }
    }

    func dismissStack(at index: Int) {
        guard index > 0, stacks.indices.contains(index) else { return }
        if stacks[index].options.clearsNestedPresentationOnDismiss {
            stacks.removeSubrange(index...)
        } else {
            stacks.remove(at: index)
        }
    }
}
