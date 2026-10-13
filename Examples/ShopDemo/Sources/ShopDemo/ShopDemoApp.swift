import FlowStack
import SwiftUI

@main
@MainActor
struct ShopDemoApp: App {
    // The demo grants access. A real app injects its session/application service here.
    @StateObject private var coordinator = ShopCoordinator(canCheckout: { true })

    var body: some Scene {
        WindowGroup {
            ShopHost(coordinator: coordinator)
        }
    }
}

@MainActor
struct ShopHost: View {
    @ObservedObject var coordinator: ShopCoordinator

    var body: some View {
        FlowStackView(router: coordinator.router, style: .default.navigationBarHidden(false)) { route in
            screen(for: route)
        } dialog: { binding in
            Color.clear
                .frame(width: 0, height: 0)
                .alert(item: binding) { _ in
                    Alert(title: Text("Sign in required"), message: Text("Sign in before checking out."))
                }
        }
        .onOpenURL { coordinator.open($0) }
    }

    @ViewBuilder
    private func screen(for route: ShopRoute) -> some View {
        switch route {
        case .catalog:
            List([42, 84], id: \.self) { id in
                Button("Product \(id)") { coordinator.showProduct(id) }
            }
            .navigationTitle("Catalog")
        case .product(let id):
            VStack(spacing: 16) {
                Text("Product \(id)")
                Button("Checkout") {
                    Task { await coordinator.requestCheckout() }
                }
            }
            .navigationTitle("Product")
        case .checkout:
            VStack(spacing: 16) {
                Text("Checkout")
                Button("Shipping address") { coordinator.showAddress() }
                Button("Close") { coordinator.closeCheckout() }
            }
            .navigationTitle("Checkout")
        case .address:
            VStack(spacing: 16) {
                Text("Shipping address")
                Button("Back") { coordinator.goBack() }
            }
            .navigationTitle("Address")
        }
    }
}
