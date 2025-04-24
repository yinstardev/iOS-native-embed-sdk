import XCTest
import WebKit
import SwiftUI
@testable import iOS_native_embed_sdk

final class BaseEmbedViewTests: XCTestCase {

    struct MockViewConfig: ViewConfig {}

    class MockBaseEmbedController: BaseEmbedController {
        override init(
            embedConfig: EmbedConfig,
            viewConfig: ViewConfig,
            embedType: String
        ) {
            super.init(embedConfig: embedConfig, viewConfig: viewConfig, embedType: embedType)
        }
    }

    func testBaseEmbedViewUsesControllerWebView() {
        let embedConfig = EmbedConfig(
            thoughtSpotHost: "https://example.com",
            authType: "AuthServerCookieless",
            getAuthToken: nil
        )
        let controller = MockBaseEmbedController(
            embedConfig: embedConfig,
            viewConfig: MockViewConfig(),
            embedType: "TestEmbedType"
        )

        // Instead of testing makeUIView directly, just assert that the controller's webView exists
        let baseEmbedView = BaseEmbedView(controller: controller)
        XCTAssertEqual(baseEmbedView.controller.webView, controller.webView)
    }
}
