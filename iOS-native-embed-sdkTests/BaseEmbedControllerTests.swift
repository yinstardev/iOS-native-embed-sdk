import XCTest
import Combine
@testable import iOS_native_embed_sdk

struct MockViewConfig: ViewConfig {}

final class BaseEmbedControllerTests: XCTestCase {

    class MockBaseEmbedController: BaseEmbedController {
        var capturedMessage: [String: Any]?
        var onSend: (([String: Any]) -> Void)?

        override func sendJsonMessageToShell(_ message: [String: Any]) {
            capturedMessage = message
            onSend?(message)
        }
    }

    var baseEmbedController: MockBaseEmbedController!

    override func setUp() {
        super.setUp()
        let embedConfig = EmbedConfig(
            thoughtSpotHost: "https://example.com",
            authType: "AuthServerCookieless",
            getAuthToken: nil
        )
        baseEmbedController = MockBaseEmbedController(
            embedConfig: embedConfig,
            viewConfig: MockViewConfig(),
            embedType: "TestEmbedType"
        )
    }

    override func tearDown() {
        baseEmbedController = nil
        super.tearDown()
    }

    func testInitialization() {
        XCTAssertNotNil(baseEmbedController)
        XCTAssertEqual(baseEmbedController.embedConfig.thoughtSpotHost, "https://example.com")
        XCTAssertEqual(baseEmbedController.embedType, "TestEmbedType")
    }

    func testShellURLInitialization() {
        let expectedURL = URL(string: "https://mobile-embed-shell.vercel.app")!
        XCTAssertEqual(baseEmbedController.shellURL, expectedURL)
    }

    func testWebViewInitialization() {
        XCTAssertNotNil(baseEmbedController.webView)
        XCTAssertEqual(baseEmbedController.webView.configuration.preferences.javaScriptEnabled, true)
    }

    func testInjectReactNativeWebViewShim() {
        let scripts = baseEmbedController.webView.configuration.userContentController.userScripts
        XCTAssertTrue(scripts.contains { $0.source.contains("window.ReactNativeWebView") })
    }

    func testEmbedConfigProperties() {
        let config = baseEmbedController.embedConfig
        XCTAssertEqual(config.thoughtSpotHost, "https://example.com")
        XCTAssertEqual(config.authType, "AuthServerCookieless")
        XCTAssertNil(config.getAuthToken)
    }

    func testHandleAuthTokenRequest() {
        let mockAuthToken = { Future<String, Error> { promise in
            promise(.success("mockToken"))
        }}

        let controller = MockBaseEmbedController(
            embedConfig: EmbedConfig(
                thoughtSpotHost: "https://example.com",
                authType: "AuthServerCookieless",
                getAuthToken: mockAuthToken
            ),
            viewConfig: MockViewConfig(),
            embedType: "TestEmbedType"
        )

        let expectation = self.expectation(description: "Auth token received")

        controller.onSend = { message in
            if message["type"] as? String == "AUTH_TOKEN_RESPONSE" {
                XCTAssertEqual(message["token"] as? String, "mockToken")
                expectation.fulfill()
            }
        }

        controller.handleRequestAuthToken()
        waitForExpectations(timeout: 1.0)
    }

    func testSendJsonMessageToShell() {
        let message: [String: Any] = ["type": "INIT", "payload": ["key": "value"]]

        baseEmbedController.onMessageSend = { msg in
            XCTAssertEqual(msg["type"] as? String, "INIT")
            XCTAssertEqual((msg["payload"] as? [String: Any])?["key"] as? String, "value")
        }

        baseEmbedController.sendJsonMessageToShell(message)
    }
}

