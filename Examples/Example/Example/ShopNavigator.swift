import Combine
import FlowStack
import Foundation

enum DemoTab: String, CaseIterable {
    case shop
    case saved

    var title: String {
        switch self {
        case .shop: "Shop"
        case .saved: "Saved"
        }
    }

    var symbol: String {
        switch self {
        case .shop: "bag"
        case .saved: "heart"
        }
    }

    var root: DemoRoute {
        switch self {
        case .shop: .catalog
        case .saved: .favorites
        }
    }
}

enum DemoRoute: Hashable {
    case catalog
    case favorites
    case product(Int)
    case cart
    case checkout
    case shippingAddress
    case orderComplete
}

enum SingleStackRoute: Hashable {
    case home
    case details
    case profile

    var title: String {
        switch self {
        case .home: "Home"
        case .details: "Details"
        case .profile: "Profile"
        }
    }
}

struct ExampleDialog: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

/// App-owned navigation and checkout policy. FlowStack owns presentation state;
/// this navigator owns the demo's cart and sign-in decisions.
@MainActor
final class ShopNavigator: ObservableObject {
    let router: FlowTabRouter<DemoTab, DemoRoute, ExampleDialog>
    let singleStackRouter: FlowRouter<SingleStackRoute, FlowNoDialog>

    @Published private(set) var cartCount = 0
    @Published private(set) var isSignedIn = false

    var cartIsEmpty: Bool { cartCount == 0 }
    var cartTitle: String { cartIsEmpty ? "Your cart is empty" : "Your cart" }
    var cartSymbol: String { cartIsEmpty ? "basket" : "basket.fill" }
    var cartMessage: String {
        cartIsEmpty
            ? "Add a product before starting checkout."
            : "\(cartCount) demo item(s) are ready for checkout."
    }
    var canCheckout: Bool { !cartIsEmpty }

    init() {
        router = FlowTabRouter(tabs: [
            FlowTab(.shop, root: .catalog),
            FlowTab(.saved, root: .favorites)
        ])
        singleStackRouter = FlowRouter(root: .home)
    }

    func showProduct(_ id: Int) {
        router.push(.product(id))
    }

    func pushSingleStackDetails() {
        singleStackRouter.push(.details)
    }

    func setSingleStackRoot(_ route: SingleStackRoute) {
        singleStackRouter.setRoot(route)
    }

    func showCart() {
        router.sheet(.cart)
    }

    func addToCart() {
        cartCount += 1
    }

    func isValidAddress(street: String, city: String) -> Bool {
        !street.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func toggleSignIn() {
        isSignedIn.toggle()
    }

    func showHelp() {
        router.showGlobalDialog(
            ExampleDialog(
                title: "FlowStack example",
                message: "Each tab remembers its own pushed routes. The cart and checkout are modal stacks managed by the tab's router."
            ),
            policy: .queue
        )
    }

    func requestCheckout() {
        let tab = router.selectedTab
        Task { @MainActor [weak self] in
            guard let self else { return }
            let allowed = await router.router(for: tab).sheetAsync(.checkout) { [weak self] _, _ in
                self?.isSignedIn == true
            }

            guard !Task.isCancelled else { return }
            if !allowed {
                router.showGlobalDialog(
                    ExampleDialog(
                        title: "Sign in to continue",
                        message: "Sign in from the cart screen, then try checkout again. This async gate stands in for an app-owned session check."
                    ),
                    policy: .queue
                )
            }
        }
    }

    func showShippingAddress() {
        router.push(.shippingAddress)
    }

    func completeOrder() {
        cartCount = 0
        router.push(.orderComplete)
    }

    func finishOrder() {
        let tab = router.selectedTab
        router.setRoot(tab.root, on: tab)
    }

    func dismissModal() {
        router.dismiss()
    }
}
