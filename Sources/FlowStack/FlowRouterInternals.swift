import Foundation

@MainActor
extension FlowRouter {
    func apply(
        _ operation: FlowOperation<Route>,
        precondition: Precondition?,
        mutation: () -> FlowOperationOutcome
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
        let outcome = mutation()
        record(operation, previousStacks: previousStacks, outcome: outcome)
        if outcome == .applied {
            didApplyOperation?(operation, previousStacks)
        }
        return outcome == .applied
    }

    func asyncConditionAllows(
        _ operation: FlowOperation<Route>,
        explicit: AsyncPrecondition?
    ) async -> Bool {
        let previousStacks = stacks
        let selectedPrecondition = explicit ?? defaultAsyncPreconditions[operation.kind]
        let allowed = await selectedPrecondition?(operation, previousStacks) ?? true
        if Task.isCancelled {
            record(operation, previousStacks: previousStacks, outcome: .cancelled)
            return false
        }
        if !allowed {
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

        trimOperationHistory()
    }

    func trimOperationHistory() {
        if maximumOperationHistoryCount > 0, operationHistory.count > maximumOperationHistoryCount {
            operationHistory.removeFirst(operationHistory.count - maximumOperationHistoryCount)
        }
    }

    func dismissStack(at index: Int) {
        FlowNavigationReducer.dismissStack(at: index, stacks: &stacks)
    }
}
