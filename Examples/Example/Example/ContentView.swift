import FlowStack
import SwiftUI
import UIKit

@MainActor
struct ContentView: View {
    @ObservedObject var navigator: ShopNavigator
    @State private var isShowingSingleStackDemo = false

    var body: some View {
        Group {
            if isShowingSingleStackDemo {
                FlowStackView(
                    router: navigator.singleStackRouter,
                    style: .default,
                    screen: singleStackScreen(for:)
                )
            } else {
                FlowTabStackView(
                    router: navigator.router,
                    style: .default,
                    screen: screen(for:),
                    label: { tab in
                        Label(tab.title, systemImage: tab.symbol)
                    },
                    dialog: { binding in
                        Color.clear.alert(item: binding) { dialog in
                            Alert(
                                title: Text(dialog.title),
                                message: Text(dialog.message),
                                dismissButton: .default(Text("OK"))
                            )
                        }
                    }
                )
            }
        }
        .tint(.indigo)
    }

    @ViewBuilder
    private func singleStackScreen(for route: SingleStackRoute) -> some View {
        SingleStackDemoScreen(
            route: route,
            root: navigator.singleStackRouter.rootStack.root,
            onPushDetails: navigator.pushSingleStackDetails,
            onSetRoot: navigator.setSingleStackRoot,
            onReturnToTabs: { isShowingSingleStackDemo = false }
        )
    }

    @ViewBuilder
    private func screen(for route: DemoRoute) -> some View {
        switch route {
        case .catalog:
            ProductListScreen(
                title: "Discover",
                sectionTitle: "Made for everyday",
                products: DemoProduct.catalog,
                navigator: navigator
            )
                .toolbar { appToolbar }
        case .favorites:
            ProductListScreen(
                title: "Saved",
                sectionTitle: "Your saved products",
                products: DemoProduct.saved,
                navigator: navigator
            )
                .toolbar { appToolbar }
        case .product(let id):
            ProductDetailScreen(product: DemoProduct.product(id: id), navigator: navigator)
                .toolbar { appToolbar }
        case .cart:
            CartScreen(navigator: navigator)
        case .checkout:
            CheckoutScreen(navigator: navigator)
        case .shippingAddress:
            ShippingAddressScreen(navigator: navigator)
        case .orderComplete:
            OrderCompleteScreen(navigator: navigator)
        }
    }

    @ToolbarContentBuilder
    private var appToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button(navigator.isSignedIn ? "Signed In" : "Sign In") {
                navigator.toggleSignIn()
            }
            .font(.subheadline.weight(.medium))
            .accessibilityHint("Toggles the demo checkout access gate")
        }

        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Button {
                isShowingSingleStackDemo = true
            } label: {
                Label("Single Root", systemImage: "rectangle.portrait")
            }
            .accessibilityHint("Opens a single-stack FlowStack and set-root demo")

            Button {
                navigator.showHelp()
            } label: {
                Image(systemName: "questionmark.circle")
            }
            .accessibilityLabel("Navigation help")

            Button {
                navigator.showCart()
            } label: {
                Label("\(navigator.cartCount)", systemImage: "basket")
            }
            .accessibilityLabel("Cart, \(navigator.cartCount) items")
        }
    }
}

private struct SingleStackDemoScreen: View {
    let route: SingleStackRoute
    let root: SingleStackRoute
    let onPushDetails: () -> Void
    let onSetRoot: (SingleStackRoute) -> Void
    let onReturnToTabs: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Single root flow", systemImage: "rectangle.portrait")
                .font(.headline)
                .foregroundStyle(.indigo)

            Text("Current root: \(root.title)")
                .font(.title2.bold())

            Text(message)
                .foregroundStyle(.secondary)

            Divider()

            switch route {
            case .home:
                Button("Push details", action: onPushDetails)
                    .buttonStyle(.borderedProminent)
                Button("Set root to Profile") { onSetRoot(.profile) }
                    .buttonStyle(.bordered)
            case .details:
                Button("Set Root to Profile") { onSetRoot(.profile) }
                    .buttonStyle(.borderedProminent)
            case .profile:
                Button("Push details", action: onPushDetails)
                    .buttonStyle(.borderedProminent)
                Button("Set root to Home") { onSetRoot(.home) }
                    .buttonStyle(.bordered)
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(route.title)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Tabs", action: onReturnToTabs)
            }
        }
    }

    private var message: String {
        switch route {
        case .home:
            "This flow uses one FlowRouter and one root stack. Push adds a destination without changing the root."
        case .details:
            "This screen was pushed above \(root.title). Set Root replaces the current root and clears this path in one operation."
        case .profile:
            "Profile is now the root. The previous root and its navigation path have been replaced."
        }
    }
}

private struct ProductListScreen: View {
    let title: String
    let sectionTitle: String
    let products: [DemoProduct]
    @ObservedObject var navigator: ShopNavigator

    var body: some View {
        List {
            Section {
                ForEach(products) { product in
                    Button {
                        navigator.showProduct(product.id)
                    } label: {
                        ProductRow(product: product)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text(sectionTitle)
            } footer: {
                Text("Choose a product to push a detail screen onto this tab's navigation stack.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(title)
    }
}

private struct ProductRow: View {
    let product: DemoProduct

    var body: some View {
        HStack(spacing: 16) {
            ProductArtwork(product: product, size: 68)
            VStack(alignment: .leading, spacing: 5) {
                Text(product.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(product.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(product.price, format: .currency(code: "USD"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }
}

private struct ProductDetailScreen: View {
    let product: DemoProduct
    @ObservedObject var navigator: ShopNavigator
    @State private var didAddToCart = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ProductArtwork(product: product, size: 220)
                    .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 8) {
                    Text(product.name)
                        .font(.largeTitle.bold())
                    Text(product.subtitle)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text(product.price, format: .currency(code: "USD"))
                        .font(.title2.weight(.semibold))
                        .padding(.top, 5)
                }

                Text("This detail view is a pushed route. The cart and checkout below are separate modal stacks.")
                    .foregroundStyle(.secondary)

                Button {
                    navigator.addToCart()
                    didAddToCart = true
                } label: {
                    Label("Add to cart", systemImage: "basket")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                if didAddToCart {
                    Label("Added — cart has \(navigator.cartCount) item(s)", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
            .padding(20)
        }
        .navigationTitle(product.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CartScreen: View {
    @ObservedObject var navigator: ShopNavigator

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: navigator.cartSymbol)
                .font(.system(size: 42))
                .foregroundStyle(.indigo)
            Text(navigator.cartTitle)
                .font(.title2.bold())
            Text(navigator.cartMessage)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                navigator.requestCheckout()
            } label: {
                Text("Continue to checkout")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!navigator.canCheckout)

            Button(navigator.isSignedIn ? "Demo session signed in" : "Sign in for checkout") {
                navigator.toggleSignIn()
            }
            .buttonStyle(.bordered)

            Button("Keep shopping") { navigator.dismissModal() }
                .buttonStyle(.bordered)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Cart")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CheckoutScreen: View {
    @ObservedObject var navigator: ShopNavigator

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "creditcard")
                .font(.system(size: 42))
                .foregroundStyle(.indigo)
            Text("Checkout")
                .font(.title2.bold())
            Text("Access was checked asynchronously before this sheet opened. This screen is a nested modal flow.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                navigator.showShippingAddress()
            } label: {
                Label("Add shipping address", systemImage: "mappin.and.ellipse")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button("Close checkout") { navigator.dismissModal() }
                .buttonStyle(.bordered)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Checkout")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ShippingAddressScreen: View {
    @ObservedObject var navigator: ShopNavigator
    @State private var street = ""
    @State private var city = ""

    var body: some View {
        Form {
            Section("Delivery address") {
                TextField("Street address", text: $street)
                    .textContentType(.streetAddressLine1)
                TextField("City", text: $city)
                    .textContentType(.addressCity)
            }

            Section {
                Button("Place demo order") {
                    navigator.completeOrder()
                }
                .disabled(!navigator.isValidAddress(street: street, city: city))
            } footer: {
                Text("No payment or delivery service is contacted by this example.")
            }
        }
        .navigationTitle("Shipping")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct OrderCompleteScreen: View {
    @ObservedObject var navigator: ShopNavigator

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 52))
                .foregroundStyle(.green)
            Text("Order placed")
                .font(.title2.bold())
            Text("The example clears the modal flow and returns to the shop root.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Complete")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Back to shop") { navigator.finishOrder() }
            }
        }
    }
}

private struct ProductArtwork: View {
    let product: DemoProduct
    let size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
            .fill(product.tint.gradient)
            .overlay {
                Image(systemName: product.symbol)
                    .font(.system(size: size * 0.42, weight: .light))
                    .foregroundStyle(.white.opacity(0.95))
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

private struct DemoProduct: Identifiable {
    let id: Int
    let name: String
    let subtitle: String
    let price: Decimal
    let symbol: String
    let tint: Color

    static let catalog = [
        DemoProduct(id: 42, name: "Everyday Headphones", subtitle: "Wireless · 30-hour battery", price: 129, symbol: "headphones", tint: .indigo),
        DemoProduct(id: 84, name: "Travel Speaker", subtitle: "Portable · Water resistant", price: 89, symbol: "speaker.wave.2", tint: .teal),
        DemoProduct(id: 126, name: "Studio Microphone", subtitle: "USB-C · Cardioid", price: 179, symbol: "mic", tint: .orange)
    ]
    static let saved = [catalog[0], catalog[2]]

    static func product(id: Int) -> DemoProduct {
        catalog.first(where: { $0.id == id }) ?? catalog[0]
    }
}

#Preview {
    ContentView(navigator: ShopNavigator())
}
