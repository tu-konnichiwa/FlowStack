import FlowStack
import SwiftUI
import Testing

private enum Route: Hashable {
    case catalog, product(Int), checkout, address, receipt
}
private enum Tab: Hashable { case shop, orders, unknown }
private struct Dialog: Identifiable, Equatable { let id: String }
private struct StructRoute: RouteHashable { let product: Int }

@MainActor
private final class WeakRouterBox<Route: Hashable> {
    weak var value: FlowRouter<Route, FlowNoDialog>?
    init(_ value: FlowRouter<Route, FlowNoDialog>) { self.value = value }
}

/// Synchronizes on events rather than sleeps or assumptions about scheduling.
@MainActor
private final class Latch {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func open() {
        isOpen = true
        let pending = waiters
        waiters.removeAll()
        pending.forEach { $0.resume() }
    }
}

@MainActor
@Suite("Public consumer behavior")
struct ConsumerBehaviorTests {
    @Test func missingTargetsFailWithDiagnosticsAndNoObserver() {
        let router = FlowRouter<Route, FlowNoDialog>(root: .catalog)
        let target = FlowStackTarget.stack(UUID())
        var observations = 0
        router.didApplyOperation = { _, _ in observations += 1 }
        #expect(!router.push(.product(1), on: target))
        #expect(!router.pushRemovingPrevious(.checkout, on: target))
        #expect(!router.replaceCurrent(with: .checkout, on: target))
        #expect(!router.replacePath(root: .checkout, on: target))
        #expect(!router.pop(on: target))
        #expect(!router.popToRoot(on: target))
        #expect(!router.popTo(.checkout, on: target))
        #expect(!router.dismiss(target))
        #expect(router.operationHistory.count == 8)
        #expect(router.operationHistory.allSatisfy { $0.outcome == .invalidTarget })
        #expect(router.topRoute == .catalog)
        #expect(observations == 0)
    }

    @Test func invalidModalStyleIsRecoverable() {
        let router = FlowRouter<Route, FlowNoDialog>(root: .catalog)
        #expect(!router.present(.checkout, style: .root))
        #expect(router.operationHistory.last?.outcome == .invalidPresentationStyle)
        #expect(router.stacks.count == 1)
    }

    @Test func missingPopRouteIsRecorded() {
        let router = FlowRouter<Route, FlowNoDialog>(root: .catalog, path: [.product(1)])
        #expect(!router.popTo(.checkout))
        #expect(router.operationHistory.last?.outcome == .routeNotFound)
        #expect(router.rootStack.path == [.product(1)])
    }

    @Test func sameRootWithoutRefreshPreservesIdentityAndClearsModals() {
        let router = FlowRouter<Route, FlowNoDialog>(root: .catalog)
        let root = router.rootStack
        let hostID = router.rootID
        router.sheet(.checkout)
        #expect(router.setRoot(.catalog, path: [.product(2)], refreshIfSameRoute: false))
        #expect(router.rootID == hostID)
        #expect(router.rootStack.rootID == root.rootID)
        #expect(router.rootStack.id == root.id)
        #expect(router.rootStack.path == [.product(2)])
        #expect(router.stacks.count == 1)
    }

    @Test func observerReceivesPreviousStateWhileRouterExposesNewState() {
        let router = FlowRouter<Route, FlowNoDialog>(root: .catalog)
        router.didApplyOperation = { operation, previous in
            #expect(operation == .push(.product(1), target: .active))
            #expect(previous[0].path.isEmpty)
            #expect(router.rootStack.path == [.product(1)])
        }
        router.push(.product(1))
        router.didApplyOperation = nil
    }

    @Test func pathBindingRetainsPrefixAndIgnoresRemovedStack() {
        let router = FlowRouter<Route, FlowNoDialog>(root: .catalog)
        router.sheet(.checkout, path: [.address])
        let binding = router.bindingForPath(stackID: router.activeStack.id)
        binding.wrappedValue = [.address, .receipt]
        #expect(router.activeStack.path == [.address, .receipt])
        router.dismiss()
        binding.wrappedValue = [.product(9)]
        #expect(binding.wrappedValue.isEmpty)
        #expect(router.rootStack.path.isEmpty)
    }

    @Test func asyncGatesRunInFIFOOrderAndObservePriorCommit() async {
        let router = FlowRouter<Route, FlowNoDialog>(root: .catalog)
        let entered = Latch(), release = Latch(), submitted = Latch()
        var events: [String] = []
        let first = Task { @MainActor in
            await router.pushAsync(.product(1)) { _, previous in
                #expect(previous[0].path.isEmpty)
                events.append("first gate")
                entered.open()
                await release.wait()
                return true
            }
        }
        await entered.wait()
        let second = Task { @MainActor in
            submitted.open()
            return await router.pushAsync(.checkout) { _, previous in
                events.append("second gate")
                #expect(previous[0].path == [.product(1)])
                return true
            }
        }
        await submitted.wait()
        #expect(events == ["first gate"])
        release.open()
        #expect(await first.value)
        #expect(await second.value)
        #expect(events == ["first gate", "second gate"])
        #expect(router.rootStack.path == [.product(1), .checkout])
    }

    @Test func cancellationRemovesWaiterBeforeActiveGateCompletes() async {
        let router = FlowRouter<Route, FlowNoDialog>(root: .catalog)
        let entered = Latch(), release = Latch(), submitted = Latch()
        let first = Task { @MainActor in
            await router.pushAsync(.product(1)) { _, _ in
                entered.open()
                await release.wait()
                return true
            }
        }
        await entered.wait()
        let cancelled = Task { @MainActor in
            submitted.open()
            return await router.pushAsync(.checkout)
        }
        await submitted.wait()
        cancelled.cancel()
        #expect(await cancelled.value == false)
        #expect(router.operationHistory.last?.outcome == .cancelled)
        #expect(router.rootStack.path.isEmpty)
        release.open()
        #expect(await first.value)
        #expect(await router.pushAsync(.receipt))
        #expect(router.rootStack.path == [.product(1), .receipt])
    }

    @Test func cancellationDuringGatePreventsCommitAndReleasesQueue() async {
        let router = FlowRouter<Route, FlowNoDialog>(root: .catalog)
        let entered = Latch(), release = Latch()
        let task = Task { @MainActor in
            await router.sheetAsync(.checkout) { _, _ in
                entered.open()
                await release.wait()
                return true
            }
        }
        await entered.wait()
        task.cancel()
        release.open()
        #expect(await task.value == false)
        #expect(router.operationHistory.last?.outcome == .cancelled)
        #expect(router.stacks.count == 1)
        #expect(await router.sheetAsync(.checkout))
    }

    @Test func cancellationBeforeEnqueueSkipsAction() async {
        let router = FlowRouter<Route, FlowNoDialog>(root: .catalog)
        let task = Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            return await router.pushAsync(.checkout)
        }
        #expect(await task.value == false)
        #expect(router.rootStack.path.isEmpty)
        #expect(router.operationHistory.last?.outcome == .cancelled)
    }

    @Test func suspendedGateRevalidatesExplicitTargetAfterSyncDismissal() async {
        let router = FlowRouter<Route, FlowNoDialog>(root: .catalog)
        router.sheet(.checkout)
        let target = FlowStackTarget.stack(router.activeStack.id)
        let entered = Latch(), release = Latch()
        let task = Task { @MainActor in
            await router.pushAsync(.address, on: target) { _, _ in
                entered.open()
                await release.wait()
                return true
            }
        }
        await entered.wait()
        router.dismiss()
        release.open()
        #expect(await task.value == false)
        #expect(router.operationHistory.last?.outcome == .invalidTarget)
        #expect(router.rootStack.path.isEmpty)
    }

    @Test func asyncGuardAndSyncDefaultSemanticsRemainCompatible() async {
        let router = FlowRouter<Route, FlowNoDialog>(root: .catalog)
        router.setDefaultPrecondition(for: .push) { _, _ in false }
        #expect(!router.push(.checkout))
        #expect(await router.pushAsync(.checkout))
        router.guardOperation = { _ in false }
        #expect(await router.pushAsync(.receipt) == false)
        #expect(router.operationHistory.last?.outcome == .blockedByGuard)
    }

    @Test func batchPushAllowsPartialSuccessAndDuplicatePopMatchesLast() {
        let router = FlowRouter<Route, FlowNoDialog>(root: .catalog)
        #expect(!router.push(contentsOf: [.product(1), .checkout, .product(1), .receipt]) { operation, _ in
            operation != .push(.checkout, target: .active)
        })
        #expect(router.rootStack.path == [.product(1), .product(1), .receipt])
        #expect(router.popTo(.product(1)))
        #expect(router.rootStack.path == [.product(1), .product(1)])
        #expect(router.popTo(.product(1), match: .inclusive))
        #expect(router.rootStack.path == [.product(1)])
    }

    @Test func nestedAsyncCommandFailsInsteadOfDeadlocking() async {
        let router = FlowRouter<Route, FlowNoDialog>(root: .catalog)
        let accepted = await router.pushAsync(.checkout) { _, _ in
            #expect(await router.pushAsync(.address) == false)
            #expect(router.operationHistory.last?.outcome == .reentrantTransition)
            return true
        }
        #expect(accepted)
        #expect(router.rootStack.path == [.checkout])
        #expect(await router.pushAsync(.receipt))
    }

    @Test func staleModalBindingCannotDismissReplacement() {
        let router = FlowRouter<Route, FlowNoDialog>(root: .catalog)
        router.sheet(.checkout)
        let stale = router.bindingForPresentedStack(style: .sheet)
        router.dismiss()
        router.sheet(.address)
        stale.wrappedValue = nil
        #expect(router.activeStack.root == .address)
        router.bindingForPresentedStack(style: .sheet).wrappedValue = nil
        #expect(!router.isPresenting)
    }

    @Test func loweringHistoryLimitImmediatelyReleasesOlderSnapshots() {
        let router = FlowRouter<Route, FlowNoDialog>(root: .catalog)
        router.push(contentsOf: [.product(1), .product(2), .product(3)])
        router.maximumOperationHistoryCount = 1
        #expect(router.operationHistory.count == 1)
        #expect(router.operationHistory[0].operation == .push(.product(3), target: .active))
        router.maximumOperationHistoryCount = 0
        router.push(.checkout)
        #expect(router.operationHistory.count == 2)
    }

    @Test func nestedAsyncCommandOnDifferentRouterIsAllowed() async {
        let first = FlowRouter<Route, FlowNoDialog>(root: .catalog)
        let second = FlowRouter<Route, FlowNoDialog>(root: .catalog)
        let accepted = await first.pushAsync(.checkout) { _, _ in
            await second.pushAsync(.address)
        }
        #expect(accepted)
        #expect(first.rootStack.path == [.checkout])
        #expect(second.rootStack.path == [.address])
    }

    @Test func cancellationAfterCommitKeepsCommittedResult() async {
        let router = FlowRouter<Route, FlowNoDialog>(root: .catalog)
        router.queuedTransitionDelayNanoseconds = 1_000_000_000
        router.didApplyOperation = { _, _ in withUnsafeCurrentTask { $0?.cancel() } }
        let task = Task { @MainActor in await router.pushAsync(.checkout) }
        #expect(await task.value)
        #expect(router.rootStack.path == [.checkout])
        #expect(router.operationHistory.last?.outcome == .applied)
        router.didApplyOperation = nil
        router.queuedTransitionDelayNanoseconds = 0
        #expect(await router.pushAsync(.receipt))
    }

    @Test func clearingHistoryReleasesRetiredRoutePayloads() {
        let router = FlowRouter<AnyRouteHashable, FlowNoDialog>(root: AnyRouteHashable(id: "catalog"))
        weak var retired: AnyRouteHashable?
        do {
            let route = AnyRouteHashable(id: "product")
            retired = route
            router.push(route)
        }
        router.pop()
        #expect(retired != nil) // Deliberately retained by diagnostic snapshots.
        router.clearOperationHistory()
        #expect(retired == nil)
    }

    @Test func pathBindingsDoNotRetainRouter() {
        var router: FlowRouter<Route, FlowNoDialog>? = FlowRouter(root: .catalog)
        let reference = WeakRouterBox(router!)
        let binding = router!.bindingForPath(stackID: router!.rootStack.id)
        router = nil
        #expect(reference.value == nil)
        #expect(binding.wrappedValue.isEmpty)
        binding.wrappedValue = [.checkout]
    }

    @Test func inheritedContextExpiresAfterOriginalTurn() async {
        let router = FlowRouter<Route, FlowNoDialog>(root: .catalog)
        let releaseChild = Latch()
        var child: Task<Bool, Never>?
        let accepted = await router.pushAsync(.checkout) { _, _ in
            child = Task { @MainActor in
                await releaseChild.wait()
                return await router.pushAsync(.address)
            }
            return true
        }
        #expect(accepted)
        releaseChild.open()
        if let pending = child {
            #expect(await pending.value)
        } else {
            Issue.record("The async gate did not create its child task.")
        }
        #expect(router.rootStack.path == [.checkout, .address])
    }

    @Test func safeTabLookupPreservesSelectionForUnknownID() {
        let router = FlowTabRouter<Tab, Route, FlowNoDialog>(tabs: [
            FlowTab(.shop, root: .catalog), FlowTab(.orders, root: .receipt)
        ])
        #expect(router.routerIfPresent(for: .unknown) == nil)
        #expect(!router.selectTabIfPresent(.unknown))
        #expect(router.selectedTab == .shop)
        #expect(router.selectTabIfPresent(.orders))
        #expect(router.activeRouter.rootStack.root == .receipt)
    }

    @Test func tabAndSingleRouterDialogPoliciesStayEquivalent() {
        let single = FlowRouter<Route, Dialog>(root: .catalog)
        let tabs = FlowTabRouter<Tab, Route, Dialog>(tabs: [FlowTab(.shop, root: .catalog)])
        for policy in [FlowDialogPolicy.queue, .queue, .interrupt, .replaceKeepingQueue, .ignoreIfVisible, .replace] {
            let dialog = Dialog(id: String(describing: policy))
            single.showGlobalDialog(dialog, policy: policy)
            tabs.showGlobalDialog(dialog, policy: policy)
            #expect(single.globalDialog == tabs.globalDialog)
            #expect(single.queuedGlobalDialogCount == tabs.queuedGlobalDialogCount)
        }
        single.hideGlobalDialog(); tabs.hideGlobalDialog()
        #expect(single.globalDialog == tabs.globalDialog)
        single.clearGlobalDialogs(); tabs.clearGlobalDialogs()
        #expect(single.globalDialog == nil && tabs.globalDialog == nil)
    }

    @Test func defaultStructRouteIDDoesNotRecurse() {
        let a = StructRoute(product: 1), b = StructRoute(product: 1)
        #expect(!a.id.isEmpty)
        #expect(a == b)
        #expect(Set([a, b]).count == 1)
    }

    @Test func hostsAcceptConcreteDialogViewsAndNoDialogModel() {
        let router = FlowRouter<Route, Dialog>(root: .catalog)
        let host = FlowStackView(router: router) { _ in Text("Catalog") } dialog: { _ in Text("Saved") }
        _ = host.body
        let tabs = FlowTabRouter<Tab, Route, Dialog>(tabs: [FlowTab(.shop, root: .catalog)])
        let tabHost = FlowTabStackView(router: tabs) { _ in Text("Catalog") } label: { _ in Text("Shop") } dialog: { _ in Text("Saved") }
        _ = tabHost.body
        let plain = FlowStackView(router: FlowRouter<Route, FlowNoDialog>(root: .catalog)) { _ in Text("Catalog") }
        _ = plain.body
    }
}
