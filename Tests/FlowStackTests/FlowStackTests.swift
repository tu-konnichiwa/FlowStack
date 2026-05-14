import Testing
@testable import FlowStack

private enum TestRoute: Hashable {
    case splash
    case home
    case detail(Int)
    case settings
    case paywall
    case editor
    case picker
}

private struct TestDialog: Equatable, Identifiable {
    let id: String
}

private final class NonHashablePayload {
    let id: String
    let onCommit: () -> Void

    init(id: String, onCommit: @escaping () -> Void = {}) {
        self.id = id
        self.onCommit = onCommit
    }
}

private final class CustomPayloadRoute: RouteHashable {
    let id: String
    let payload: NonHashablePayload

    init(payload: NonHashablePayload) {
        self.payload = payload
        self.id = "customPayload_\(payload.id)"
    }
}

private enum EnumClosureRoute: RouteHashable {
    case home
    case colorPicker(initialHex: String, didPick: (String) -> Void)
}

@MainActor
@Suite("FlowStack")
struct FlowStackTests {
    @Test func initializesWithRootStack() {
        let router = FlowRouter<TestRoute, TestDialog>(root: .splash)

        #expect(router.stacks.count == 1)
        #expect(router.rootStack.root == .splash)
        #expect(router.activeStack.style == .root)
        #expect(router.topRoute == .splash)
        #expect(!router.isPresenting)
    }

    @Test func setRootClearsPresentedStacksAndPath() {
        let router = FlowRouter<TestRoute, TestDialog>(root: .splash)
        router.push(.detail(1))
        router.sheet(.picker)

        router.setRoot(.home)

        #expect(router.stacks.count == 1)
        #expect(router.rootStack.root == .home)
        #expect(router.rootStack.path.isEmpty)
    }

    @Test func setRootRefreshesIdentityWhenRouteAndPathAreSame() {
        let router = FlowRouter<TestRoute, TestDialog>(root: .home)
        let oldID = router.rootID

        router.setRoot(.home)

        #expect(router.rootID != oldID)
    }

    @Test func setRootRefreshesIdentityWhenRootRouteIsSameEvenWithDifferentPath() {
        let router = FlowRouter<TestRoute, TestDialog>(root: .home)
        let oldID = router.rootID

        router.setRoot(.home, path: [.detail(1)])

        #expect(router.rootID != oldID)
        #expect(router.rootStack.path == [.detail(1)])
    }

    @Test func pushAndPopOnActiveStack() {
        let router = FlowRouter<TestRoute, TestDialog>(root: .home)

        router.push(.detail(1))
        router.push(.detail(2))
        router.pop()

        #expect(router.activeStack.path == [.detail(1)])
        #expect(router.topRoute == .detail(1))
    }

    @Test func pushingSameRouteTwiceCreatesDistinctPathIdentities() {
        let router = FlowRouter<TestRoute, TestDialog>(root: .home)

        router.push(.detail(1))
        router.push(.detail(1))

        #expect(router.activeStack.path == [.detail(1), .detail(1)])
        #expect(router.activeStack.navigationPath[0].id != router.activeStack.navigationPath[1].id)
    }

    @Test func routeHashableUsesOnlyIDForEqualityAndHashing() {
        let first = CustomPayloadRoute(payload: NonHashablePayload(id: "1"))
        let second = CustomPayloadRoute(payload: NonHashablePayload(id: "1"))
        let third = CustomPayloadRoute(payload: NonHashablePayload(id: "2"))

        #expect(first == second)
        #expect(first != third)
        #expect(Set([first, second, third]).count == 2)
    }

    @Test func routeHashableSupportsNavigationWithNonHashablePayload() {
        let root = CustomPayloadRoute(payload: NonHashablePayload(id: "root"))
        let detail = CustomPayloadRoute(payload: NonHashablePayload(id: "detail") {})
        let replacement = CustomPayloadRoute(payload: NonHashablePayload(id: "detail") {})
        let router = FlowRouter<CustomPayloadRoute, TestDialog>(root: root)

        router.push(detail)
        let oldNodeID = router.activeStack.navigationPath[0].id
        router.replaceCurrent(with: replacement)

        #expect(router.rootStack.root.id == "customPayload_root")
        #expect(router.activeStack.path.map(\.id) == ["customPayload_detail"])
        #expect(router.activeStack.navigationPath[0].id != oldNodeID)
    }

    @Test func enumRouteHashableHandlesClosureAssociatedValuesWithoutManualHashing() {
        let first = EnumClosureRoute.colorPicker(initialHex: "#FFFFFF") { _ in }
        let second = EnumClosureRoute.colorPicker(initialHex: "#FFFFFF") { _ in }
        let third = EnumClosureRoute.colorPicker(initialHex: "#000000") { _ in }
        let router = FlowRouter<EnumClosureRoute, TestDialog>(root: .home)

        router.push(first)
        router.replaceCurrent(with: second)

        #expect(first == second)
        #expect(first != third)
        #expect(Set([first, second, third]).count == 2)
        #expect(router.activeStack.path == [second])
    }

    @Test func pushRemovingPreviousRemovesRouteBeforeNewRoute() {
        let router = FlowRouter<TestRoute, TestDialog>(root: .home)
        router.push(contentsOf: [.detail(1), .detail(2)])

        router.pushRemovingPrevious(.settings)

        #expect(router.rootStack.root == .home)
        #expect(router.activeStack.path == [.detail(1), .settings])
        #expect(router.topRoute == .settings)
    }

    @Test func pushRemovingPreviousOnEmptyPathReplacesStackRoot() {
        let router = FlowRouter<TestRoute, TestDialog>(root: .home)

        router.pushRemovingPrevious(.settings)

        #expect(router.rootStack.root == .settings)
        #expect(router.rootStack.path.isEmpty)
        #expect(router.topRoute == .settings)
    }

    @Test func pushRemovingPreviousCanTargetSpecificModalStack() {
        let router = FlowRouter<TestRoute, TestDialog>(root: .home)
        router.sheet(.picker, path: [.detail(1)])
        let sheetID = router.activeStack.id

        router.pushRemovingPrevious(.settings, on: .stack(sheetID))

        #expect(router.rootStack.root == .home)
        #expect(router.activeStack.root == .picker)
        #expect(router.activeStack.path == [.settings])
    }

    @Test func popBeyondEmptyPresentedStackDismissesIt() {
        let router = FlowRouter<TestRoute, TestDialog>(root: .home)
        router.sheet(.picker)

        router.pop()

        #expect(router.stacks.count == 1)
        #expect(router.topRoute == .home)
    }

    @Test func replaceCurrentReplacesTopPathRoute() {
        let router = FlowRouter<TestRoute, TestDialog>(root: .home)
        router.push(.detail(1))

        router.replaceCurrent(with: .settings)

        #expect(router.activeStack.root == .home)
        #expect(router.activeStack.path == [.settings])
    }

    @Test func replaceCurrentWithSameRouteCreatesNewPathIdentity() {
        let router = FlowRouter<TestRoute, TestDialog>(root: .home)
        router.push(.detail(1))
        let oldNodeID = router.activeStack.navigationPath[0].id

        router.replaceCurrent(with: .detail(1))

        #expect(router.activeStack.path == [.detail(1)])
        #expect(router.activeStack.navigationPath[0].id != oldNodeID)
    }

    @Test func replaceCurrentOnEmptyStackReplacesRoot() {
        let router = FlowRouter<TestRoute, TestDialog>(root: .home)

        router.replaceCurrent(with: .settings)

        #expect(router.rootStack.root == .settings)
        #expect(router.rootStack.path.isEmpty)
    }

    @Test func replaceCurrentWithSameRootRouteRefreshesStackRootIdentity() {
        let router = FlowRouter<TestRoute, TestDialog>(root: .home)
        let oldRootID = router.rootStack.rootID

        router.replaceCurrent(with: .home)

        #expect(router.rootStack.root == .home)
        #expect(router.rootStack.rootID != oldRootID)
    }

    @Test func replacePathSupportsDeepLinkState() {
        let router = FlowRouter<TestRoute, TestDialog>(root: .splash)

        router.replacePath(root: .home, path: [.detail(10), .settings])

        #expect(router.rootStack.root == .home)
        #expect(router.rootStack.path == [.detail(10), .settings])
        #expect(router.topRoute == .settings)
    }

    @Test func popToRouteExclusiveKeepsMatchedRoute() {
        let router = FlowRouter<TestRoute, TestDialog>(root: .home)
        router.push(contentsOf: [.detail(1), .detail(2), .settings])

        let didPop = router.popTo(.detail(1))

        #expect(didPop)
        #expect(router.activeStack.path == [.detail(1)])
    }

    @Test func popToRouteInclusiveRemovesMatchedRoute() {
        let router = FlowRouter<TestRoute, TestDialog>(root: .home)
        router.push(contentsOf: [.detail(1), .detail(2), .settings])

        let didPop = router.popTo(.detail(2), match: .inclusive)

        #expect(didPop)
        #expect(router.activeStack.path == [.detail(1)])
    }

    @Test func popToMissingRouteReturnsFalseAndKeepsPath() {
        let router = FlowRouter<TestRoute, TestDialog>(root: .home)
        router.push(contentsOf: [.detail(1), .settings])

        let didPop = router.popTo(.detail(99))

        #expect(!didPop)
        #expect(router.activeStack.path == [.detail(1), .settings])
    }

    @Test func presentSheetCreatesNewActiveStack() {
        let router = FlowRouter<TestRoute, TestDialog>(root: .home)

        router.sheet(.picker, path: [.detail(1)])

        #expect(router.isPresenting)
        #expect(router.stacks.count == 2)
        #expect(router.activeStack.root == .picker)
        #expect(router.activeStack.path == [.detail(1)])
        #expect(router.activeStack.style == .sheet)
    }

    @Test func presentFullScreenCreatesNewActiveStack() {
        let router = FlowRouter<TestRoute, TestDialog>(root: .home)

        router.fullScreenCover(.editor)

        #expect(router.activeStack.root == .editor)
        #expect(router.activeStack.style == .fullScreenCover)
    }

    @Test func dismissActiveRemovesOnlyTopPresentation() {
        let router = FlowRouter<TestRoute, TestDialog>(root: .home)
        router.sheet(.picker)
        router.fullScreenCover(.editor)

        router.dismiss()

        #expect(router.stacks.count == 2)
        #expect(router.activeStack.root == .picker)
    }

    @Test func dismissSpecificStackClearsNestedPresentationsByDefault() {
        let router = FlowRouter<TestRoute, TestDialog>(root: .home)
        router.sheet(.picker)
        let sheetID = router.activeStack.id
        router.fullScreenCover(.editor)

        router.dismiss(.stack(sheetID))

        #expect(router.stacks.count == 1)
        #expect(router.topRoute == .home)
    }

    @Test func dismissSpecificStackCanPreserveNestedPresentations() {
        let router = FlowRouter<TestRoute, TestDialog>(root: .home)
        router.sheet(
            .picker,
            options: FlowPresentationOptions(clearsNestedPresentationOnDismiss: false)
        )
        let sheetID = router.activeStack.id
        router.fullScreenCover(.editor)

        router.dismiss(.stack(sheetID))

        #expect(router.stacks.count == 2)
        #expect(router.activeStack.root == .editor)
    }

    @Test func dismissAllKeepsRootStackAndItsPath() {
        let router = FlowRouter<TestRoute, TestDialog>(root: .home)
        router.push(.detail(1), on: .root)
        router.sheet(.picker)

        router.dismissAll()

        #expect(router.stacks.count == 1)
        #expect(router.rootStack.path == [.detail(1)])
    }

    @Test func targetedPushUsesRequestedStack() {
        let router = FlowRouter<TestRoute, TestDialog>(root: .home)
        let rootID = router.rootStack.id
        router.sheet(.picker)

        router.push(.settings, on: .stack(rootID))

        #expect(router.rootStack.path == [.settings])
        #expect(router.activeStack.path.isEmpty)
    }

    @Test func guardCanBlockOperation() {
        let router = FlowRouter<TestRoute, TestDialog>(root: .home)
        router.guardOperation = { operation in
            operation != .push(.paywall, target: .active)
        }

        let didPush = router.push(.paywall)

        #expect(!didPush)
        #expect(router.activeStack.path.isEmpty)
    }

    @Test func guardCanBlockPushRemovingPreviousOperation() {
        let router = FlowRouter<TestRoute, TestDialog>(root: .home)
        router.push(.detail(1))
        router.guardOperation = { operation in
            operation != .pushRemovingPrevious(.settings, target: .active)
        }

        let didPush = router.pushRemovingPrevious(.settings)

        #expect(!didPush)
        #expect(router.activeStack.path == [.detail(1)])
    }

    @Test func guardCanBlockPopToOperation() {
        let router = FlowRouter<TestRoute, TestDialog>(root: .home)
        router.push(contentsOf: [.detail(1), .settings])
        router.guardOperation = { operation in
            operation != .popTo(.detail(1), match: .exclusive, target: .active)
        }

        let didPop = router.popTo(.detail(1))

        #expect(!didPop)
        #expect(router.activeStack.path == [.detail(1), .settings])
    }

    @Test func defaultConditionCanBlockActionKind() {
        let router = FlowRouter<TestRoute, TestDialog>(root: .home)
        router.setDefaultPrecondition(for: .push) { operation, previousStacks in
            #expect(operation == .push(.settings, target: .active))
            #expect(previousStacks[0].path.isEmpty)
            return false
        }

        let didPush = router.push(.settings)

        #expect(!didPush)
        #expect(router.activeStack.path.isEmpty)
    }

    @Test func explicitConditionOverridesDefaultCondition() {
        let router = FlowRouter<TestRoute, TestDialog>(root: .home)
        router.setDefaultPrecondition(for: .push) { _, _ in false }

        let didPush = router.push(.settings) { operation, previousStacks in
            #expect(operation == .push(.settings, target: .active))
            #expect(previousStacks[0].root == .home)
            return true
        }

        #expect(didPush)
        #expect(router.activeStack.path == [.settings])
    }

    @Test func explicitConditionCanBlockEvenWhenDefaultAllows() {
        let router = FlowRouter<TestRoute, TestDialog>(root: .home)
        router.setDefaultPrecondition(for: .present) { _, _ in true }

        let didPresent = router.sheet(.picker) { operation, previousStacks in
            #expect(operation == .present(.picker, style: .sheet))
            #expect(previousStacks.count == 1)
            return false
        }

        #expect(!didPresent)
        #expect(!router.isPresenting)
    }

    @Test func defaultConditionsAreScopedByOperationKind() {
        let router = FlowRouter<TestRoute, TestDialog>(root: .home)
        router.setDefaultPrecondition(for: .present) { _, _ in false }

        let didPush = router.push(.settings)
        let didPresent = router.sheet(.picker)

        #expect(didPush)
        #expect(!didPresent)
        #expect(router.activeStack.path == [.settings])
        #expect(router.stacks.count == 1)
    }

    @Test func asyncDefaultConditionCanBlockQueuedPush() async {
        let router = FlowRouter<TestRoute, TestDialog>(root: .home)
        router.setDefaultAsyncPrecondition(for: .push) { operation, previousStacks in
            #expect(operation == .push(.settings, target: .active))
            #expect(previousStacks[0].root == .home)
            return false
        }

        let didPush = await router.pushAsync(.settings)

        #expect(!didPush)
        #expect(router.activeStack.path.isEmpty)
        #expect(router.operationHistory.last?.outcome == .blockedByPrecondition)
    }

    @Test func explicitAsyncConditionOverridesDefaultAsyncCondition() async {
        let router = FlowRouter<TestRoute, TestDialog>(root: .home)
        router.setDefaultAsyncPrecondition(for: .present) { _, _ in false }

        let didPresent = await router.sheetAsync(.picker) { operation, previousStacks in
            #expect(operation == .present(.picker, style: .sheet))
            #expect(previousStacks.count == 1)
            return true
        }

        #expect(didPresent)
        #expect(router.activeStack.root == .picker)
    }

    @Test func queuedActionsRunSerially() async {
        let router = FlowRouter<TestRoute, TestDialog>(root: .home)
        router.queuedTransitionDelayNanoseconds = 1_000

        async let first = router.pushAsync(.detail(1))
        async let second = router.pushAsync(.detail(2))
        let result = await (first, second)

        #expect(result.0)
        #expect(result.1)
        #expect(router.activeStack.path == [.detail(1), .detail(2)])
    }

    @Test func operationHistoryRecordsAppliedAndBlockedOperations() {
        let router = FlowRouter<TestRoute, TestDialog>(root: .home)
        router.setDefaultPrecondition(for: .push) { operation, _ in
            operation != .push(.paywall, target: .active)
        }

        router.push(.settings)
        router.push(.paywall)

        #expect(router.operationHistory.map(\.outcome) == [.applied, .blockedByPrecondition])
        #expect(router.operationHistory[0].previousStacks[0].path.isEmpty)
        #expect(router.operationHistory[0].newStacks[0].path == [.settings])
    }

    @Test func operationHistoryCanBeCappedAndCleared() {
        let router = FlowRouter<TestRoute, TestDialog>(root: .home)
        router.maximumOperationHistoryCount = 1

        router.push(.detail(1))
        router.push(.detail(2))

        #expect(router.operationHistory.count == 1)
        #expect(router.operationHistory.last?.operation == .push(.detail(2), target: .active))

        router.clearOperationHistory()

        #expect(router.operationHistory.isEmpty)
    }

    @Test func observerReceivesAppliedOperations() {
        let router = FlowRouter<TestRoute, TestDialog>(root: .home)
        var operations: [FlowOperation<TestRoute>] = []
        router.didApplyOperation = { operation, _ in
            operations.append(operation)
        }

        router.push(.settings)
        router.sheet(.picker)

        #expect(operations == [
            .push(.settings, target: .active),
            .present(.picker, style: .sheet)
        ])
    }

    @Test func dialogReplacePolicyReplacesVisibleDialog() {
        let router = FlowRouter<TestRoute, TestDialog>(root: .home)

        router.showGlobalDialog(TestDialog(id: "a"))
        router.showGlobalDialog(TestDialog(id: "b"))

        #expect(router.globalDialog == TestDialog(id: "b"))
    }

    @Test func dialogReplacePolicyClearsQueuedDialogs() {
        let router = FlowRouter<TestRoute, TestDialog>(root: .home)

        router.showGlobalDialog(TestDialog(id: "a"), policy: .queue)
        router.showGlobalDialog(TestDialog(id: "b"), policy: .queue)
        router.showGlobalDialog(TestDialog(id: "urgent"), policy: .replace)
        router.hideGlobalDialog()

        #expect(router.globalDialog == nil)
        #expect(router.queuedGlobalDialogCount == 0)
    }

    @Test func dialogReplaceKeepingQueuePreservesQueuedDialogs() {
        let router = FlowRouter<TestRoute, TestDialog>(root: .home)

        router.showGlobalDialog(TestDialog(id: "a"), policy: .queue)
        router.showGlobalDialog(TestDialog(id: "b"), policy: .queue)
        router.showGlobalDialog(TestDialog(id: "urgent"), policy: .replaceKeepingQueue)
        router.hideGlobalDialog()

        #expect(router.globalDialog == TestDialog(id: "b"))
        #expect(router.queuedGlobalDialogCount == 0)
    }

    @Test func dialogQueuePolicyShowsNextDialogWhenCurrentIsHidden() {
        let router = FlowRouter<TestRoute, TestDialog>(root: .home)

        router.showGlobalDialog(TestDialog(id: "a"), policy: .queue)
        router.showGlobalDialog(TestDialog(id: "b"), policy: .queue)
        router.hideGlobalDialog()

        #expect(router.globalDialog == TestDialog(id: "b"))
    }

    @Test func dialogIgnorePolicyKeepsVisibleDialog() {
        let router = FlowRouter<TestRoute, TestDialog>(root: .home)

        router.showGlobalDialog(TestDialog(id: "a"))
        router.showGlobalDialog(TestDialog(id: "b"), policy: .ignoreIfVisible)

        #expect(router.globalDialog == TestDialog(id: "a"))
    }

    @Test func clearGlobalDialogsRemovesVisibleAndQueuedDialogs() {
        let router = FlowRouter<TestRoute, TestDialog>(root: .home)
        router.showGlobalDialog(TestDialog(id: "a"), policy: .queue)
        router.showGlobalDialog(TestDialog(id: "b"), policy: .queue)

        router.clearGlobalDialogs()
        router.hideGlobalDialog()

        #expect(router.globalDialog == nil)
        #expect(router.queuedGlobalDialogCount == 0)
    }
}
