import Combine
import FlowStack
import Foundation

// Routes contain identifiers, not backend models, views, or services.
enum ShopRoute: Hashable, Codable {
    case catalog
    case product(Int)
    case checkout
    case address
}

enum ShopDialog: Identifiable {
    case signInRequired
    var id: String { "signInRequired" }
}

struct NavigationSnapshot: Codable {
    let root: ShopRoute
    let path: [ShopRoute]
}

/// Consumer-owned presentation orchestration; the app injects its session check.
@MainActor
final class ShopCoordinator: ObservableObject {
    let router = FlowRouter<ShopRoute, ShopDialog>(root: .catalog)
    private let canCheckout: @MainActor () async -> Bool

    init(canCheckout: @escaping @MainActor () async -> Bool) {
        self.canCheckout = canCheckout
    }

    func showProduct(_ id: Int) {
        router.push(.product(id))
    }

    @discardableResult
    func requestCheckout() async -> Bool {
        var sessionDenied = false
        let allowed = await router.sheetAsync(.checkout) { [canCheckout] _, _ in
            let permitted = await canCheckout()
            sessionDenied = !permitted
            return permitted
        }
        // Track the app decision directly; history can contain other concurrent commands.
        if !allowed, sessionDenied, !Task.isCancelled {
            router.showGlobalDialog(.signInRequired, policy: .queue)
        }
        return allowed
    }

    func showAddress() { router.push(.address) }
    func goBack() { router.pop() }
    func closeCheckout() { router.dismiss() }

    /// URL parsing and validation belong to the app. Unrecognized URLs do nothing.
    @discardableResult
    func open(_ url: URL) -> Bool {
        let parts = url.path.split(separator: "/")
        guard url.scheme == "flowshop", url.host == "product", parts.count == 1,
              let id = Int(parts[0]), id > 0 else { return false }
        return router.setRoot(.catalog, path: [.product(id)], refreshIfSameRoute: false)
    }

    /// This example persists the root tab path; modal restoration is app-specific.
    func snapshot() throws -> Data {
        try JSONEncoder().encode(NavigationSnapshot(root: router.rootStack.root, path: router.rootStack.path))
    }

    @discardableResult
    func restore(_ data: Data) throws -> Bool {
        let snapshot = try JSONDecoder().decode(NavigationSnapshot.self, from: data)
        return router.setRoot(snapshot.root, path: snapshot.path, refreshIfSameRoute: false)
    }
}
