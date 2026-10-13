import FlowStack
import SwiftUI
import Testing

// Keep this consumer host synchronized with README's complete quick start.
private enum AppRoute: Hashable {
    case catalog
    case product(Int)
}

@MainActor
private struct CatalogFlow: View {
    @StateObject private var router = FlowRouter<AppRoute, FlowNoDialog>(root: .catalog)

    var body: some View {
        FlowStackView(router: router, style: .default.navigationBarHidden(false)) { route in
            switch route {
            case .catalog:
                Button("Product 42") { router.push(.product(42)) }
                    .navigationTitle("Catalog")
            case .product(let id):
                Text("Product \(id)")
                    .navigationTitle("Product")
            }
        }
    }
}

@MainActor
@Test func readmeQuickStartCompilesUsingOnlyPublicAPIs() {
    _ = CatalogFlow().body
}
