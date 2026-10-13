import FlowStack
import Foundation
import Testing
@testable import ShopDemo

@MainActor
@Suite("External package integration")
struct ShopDemoTests {
    @Test func deepLinkCheckoutModalAndRestoration() async throws {
        let shop = ShopCoordinator(canCheckout: { true })
        #expect(shop.open(URL(string: "flowshop://product/42")!))
        #expect(shop.router.rootStack.path == [.product(42)])
        let snapshot = try shop.snapshot()
        #expect(await shop.requestCheckout())
        shop.showAddress()
        #expect(shop.router.activeStack.path == [.address])
        #expect(shop.router.rootStack.path == [.product(42)])
        shop.closeCheckout()
        #expect(shop.router.topRoute == .product(42))
        shop.router.setRoot(.catalog)
        #expect(try shop.restore(snapshot))
        #expect(shop.router.topRoute == .product(42))
        let host = ShopHost(coordinator: shop)
        _ = host.body
    }

    @Test func deniedCheckoutShowsActionableDialog() async {
        let shop = ShopCoordinator(canCheckout: { false })
        #expect(await shop.requestCheckout() == false)
        #expect(!shop.router.isPresenting)
        #expect(shop.router.globalDialog?.id == "signInRequired")
        #expect(shop.router.operationHistory.last?.outcome == .blockedByPrecondition)
    }

    @Test func invalidURLsAndCorruptSnapshotsDoNotChangeState() {
        let shop = ShopCoordinator(canCheckout: { true })
        shop.showProduct(84)
        for text in ["https://product/42", "flowshop://product/-1", "flowshop://product/abc", "flowshop://product/42/extra"] {
            #expect(!shop.open(URL(string: text)!))
        }
        #expect(throws: DecodingError.self) { try shop.restore(Data("broken".utf8)) }
        #expect(shop.router.topRoute == .product(84))
    }
}
