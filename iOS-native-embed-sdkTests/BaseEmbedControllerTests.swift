import XCTest
import Combine
@testable import iOS_native_embed_sdk

struct MockLiveboardViewConfig: Codable {
    let mockId: String = "mockLiveboard"
}

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
    var mockEmbedConfig: EmbedConfig!

    override func setUp() {
        super.setUp()

        mockEmbedConfig = SDKEmbedConfig(
            thoughtSpotHost: "https://example.com",
            authType: AuthType.TrustedAuthTokenCookieless,
            getAuthTokenCallback
        )

        let specificViewConfig: SpecificViewConfig = .liveboard(MockLiveboardViewConfig())

        // 3. Initialize the MockBaseEmbedController with the updated signature
        baseEmbedController = MockBaseEmbedController(
            embedConfig: mockEmbedConfig,
            specificViewConfig: specificViewConfig,   // Pass the enum case
            embedType: "TestEmbedType",
            getAuthTokenCallback: nil                // Pass nil callback by default
        )
    }

    // Clean up after each test
    override func tearDown() {
        baseEmbedController = nil
        mockEmbedConfig = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        XCTAssertNotNil(baseEmbedController, "Controller should initialize")
        XCTAssertEqual(baseEmbedController.embedConfig.thoughtSpotHost, "https://example.com")
        XCTAssertEqual(baseEmbedController.embedType, "TestEmbedType")
        // Optionally check the specific view config type stored
        switch baseEmbedController.viewConfig {
        case .liveboard(let config):
            // Check specific properties of the mock/real config if needed
             XCTAssertEqual((config as? MockLiveboardViewConfig)?.mockId, "mockLiveboard")
        // Add default or other cases if testing different view types
        // default: XCTFail("Expected liveboard config")
        }
    }

    func testShellURLInitialization() {
        let expectedURL = URL(string: "https://mobile-embed-shell.vercel.app")!
        XCTAssertEqual(baseEmbedController.shellURL, expectedURL)
    }

    func testWebViewInitialization() {
        XCTAssertNotNil(baseEmbedController.webView, "WebView should be initialized")
        XCTAssertEqual(baseEmbedController.webView.configuration.preferences.javaScriptEnabled, true)
    }

    func testInjectReactNativeWebViewShim() {
        let scripts = baseEmbedController.webView.configuration.userContentController.userScripts
        XCTAssertTrue(scripts.contains { $0.source.contains("window.ReactNativeWebView") }, "Shim script should be injected")
    }

    // MARK: - Property Tests

    func testEmbedConfigProperties() {
        // Access the stored embedConfig
        let config = baseEmbedController.embedConfig
        XCTAssertEqual(config.thoughtSpotHost, "https://example.com")
        // Ensure comparison matches the actual type of authType (Enum case or String)
        XCTAssertEqual(config.authType, .TrustedAuthTokenCookieless) // Compare Enum cases
        // Verify the callback property on the controller itself
        XCTAssertNil(baseEmbedController.getAuthTokenCallback, "Default getAuthTokenCallback should be nil")
    }

    // MARK: - Functionality Tests

    func testHandleAuthTokenRequest() {
        // 1. Define the mock callback function that returns a Future
        let mockAuthTokenCallback = { Future<String, Error> { promise in
            // Simulate successful token fetch
            promise(.success("mockToken"))
        }}

        // 2. Create EmbedConfig *without* getAuthToken
        let testEmbedConfig = EmbedConfig(
            thoughtSpotHost: "https://example.com",
            authType: .TrustedAuthTokenCookieless // Use enum
            // Add other necessary EmbedConfig properties
        )

        // 3. Create a SpecificViewConfig case
        let specificViewConfig: SpecificViewConfig = .liveboard(MockLiveboardViewConfig())

        // 4. Initialize MockBaseEmbedController correctly, PASSING the mock callback
        let controller = MockBaseEmbedController(
            embedConfig: testEmbedConfig,
            specificViewConfig: specificViewConfig,
            embedType: "TestEmbedType",
            getAuthTokenCallback: mockAuthTokenCallback // Pass the callback here
        )

        // 5. Set up expectation for the message sent back to the shell
        let expectation = self.expectation(description: "Auth token response message received")

        // 6. Define the assertion logic within the onSend callback
        controller.onSend = { message in
            if message["type"] as? String == "AUTH_TOKEN_RESPONSE" {
                XCTAssertEqual(message["token"] as? String, "mockToken", "Token in message should match mock")
                expectation.fulfill()
            } else if message["type"] as? String == "AUTH_TOKEN_ERROR" {
                XCTFail("Should not receive auth token error: \(message["error"] ?? "Unknown error")")
            }
        }

        // 7. Trigger the method under test
        controller.handleRequestAuthToken()

        // 8. Wait for the expectation
        waitForExpectations(timeout: 1.0, handler: nil)
    }

    func testSendJsonMessageToShell() {
        // Arrange
        let message: [String: Any] = ["type": "TEST_MESSAGE", "payload": ["dataKey": "dataValue"]]
        let expectation = self.expectation(description: "onSend callback executed")

        // Act: Set the callback and call the method
        baseEmbedController.onSend = { msg in
            // Assert: Check if the message received by the callback matches the input
            // Use NSDictionary for easier comparison if dealing with complex nested structures
            XCTAssertEqual(msg as NSDictionary, message as NSDictionary)
            expectation.fulfill()
        }
        baseEmbedController.sendJsonMessageToShell(message)

        // Assert: Wait for the callback expectation
        waitForExpectations(timeout: 0.1) // Short timeout, callback should be synchronous
        // Also check the captured message property on the mock
        XCTAssertEqual(baseEmbedController.capturedMessage as NSDictionary?, message as NSDictionary)
    }

    // Add tests for sendEmbedConfigToShell and sendViewConfigToShell
    // These will involve mocking the SpecificViewConfig cases and verifying the
    // JSON structure sent via sendJsonMessageToShell

     func testSendEmbedConfigToShell() {
         let expectation = self.expectation(description: "sendEmbedConfigToShell message sent")
         baseEmbedController.onSend = { message in
             if message["type"] as? String == "INIT" {
                 XCTAssertNotNil(message["payload"])
                 if let payload = message["payload"] as? [String: Any] {
                     XCTAssertEqual(payload["thoughtSpotHost"] as? String, "https://example.com")
                     // Assuming AuthType enum has a rawValue of String
                     XCTAssertEqual(payload["authType"] as? String, AuthType.TrustedAuthTokenCookieless.rawValue)
                     XCTAssertEqual(payload["getTokenFromSDK"] as? Bool, true)
                 } else {
                     XCTFail("Payload is not a dictionary")
                 }
                 expectation.fulfill()
             }
         }
         // Simulate shell being initialized
         baseEmbedController.sendJsonMessageToShell(["type":"INIT_VERCEL_SHELL","status":"ready"]) // Trigger initialization flow if needed, or set flag directly
         baseEmbedController.sendEmbedConfigToShell() // Call the method under test

         waitForExpectations(timeout: 1.0)
     }

     func testSendViewConfigToShell() {
         let expectation = self.expectation(description: "sendViewConfigToShell message sent")
         baseEmbedController.onSend = { message in
             if message["type"] as? String == "EMBED" {
                 XCTAssertEqual(message["embedType"] as? String, "TestEmbedType")
                 XCTAssertNotNil(message["viewConfig"])
                 if let viewCfgPayload = message["viewConfig"] as? [String: Any] {
                     // Assert specific properties of the MockLiveboardViewConfig were encoded
                     XCTAssertEqual(viewCfgPayload["mockId"] as? String, "mockLiveboard")
                 } else {
                      XCTFail("viewConfig payload is not a dictionary")
                 }
                 expectation.fulfill()
             }
         }
          // Simulate shell being initialized
         baseEmbedController.sendJsonMessageToShell(["type":"INIT_VERCEL_SHELL","status":"ready"]) // Trigger initialization flow if needed, or set flag directly
         baseEmbedController.sendViewConfigToShell() // Call the method under test

         waitForExpectations(timeout: 1.0)
     }

    // Add more tests for WKScriptMessageHandler delegate methods, error handling, etc.
}
