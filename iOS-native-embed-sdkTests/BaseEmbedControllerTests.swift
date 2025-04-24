//
//  BaseEmbedControllerTests.swift
//  iOS-native-embed-sdk
//
//  Created by Prashant.patil on 24/04/25.
//

import XCTest
import WebKit
import Combine
@testable import iOS_native_embed_sdk

final class BaseEmbedControllerTests: XCTestCase {

    var cancellables: Set<AnyCancellable> = []

    struct MockConfig: Codable, Equatable {
        let key: String
    }
    
    let getAuthToken: () -> Future<String, Error> = {
        return Future { promise in
            // Simulate async token fetching
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                promise(.success("mock-token-123"))
            }
        }
    }

    func makeController(getToken: (() -> Future<String, Error>)? = nil) -> BaseEmbedController {
        let config = EmbedConfig(thoughtSpotHost: "https://test.com",authType: AuthType.TrustedAuthTokenCookieless)
        let viewConfig = SpecificViewConfig.liveboard(LiveboardViewConfig(liveboardId: "abc"))
        let controller = BaseEmbedController(embedConfig: config, viewConfig: viewConfig, embedType: "Liveboard", getAuthTokenCallback: getToken)
        return controller
    }

    func testInitializationSetsPropertiesCorrectly() throws {
        let controller = makeController()

        XCTAssertEqual(controller.embedConfig.thoughtSpotHost, "https://test.com")
        XCTAssertEqual(controller.embedType, "Liveboard")
        XCTAssertNotNil(controller.webView)
    }

    func testShellInitializationTriggersEmbedAndViewConfig() {
        let expectation1 = expectation(description: "Embed config sent")
        let expectation2 = expectation(description: "View config sent")

        class TestController: BaseEmbedController {
            let onEmbedConfigSent: () -> Void
            let onViewConfigSent: () -> Void

            init(embedConfig: EmbedConfig,
                 viewConfig: SpecificViewConfig,
                 embedType: String,
                 onEmbedConfigSent: @escaping () -> Void,
                 onViewConfigSent: @escaping () -> Void) {
                self.onEmbedConfigSent = onEmbedConfigSent
                self.onViewConfigSent = onViewConfigSent
                super.init(embedConfig: embedConfig, viewConfig: viewConfig, embedType: embedType)
            }

            override func sendEmbedConfigToShell() {
                onEmbedConfigSent()
            }

            override func sendViewConfigToShell() {
                onViewConfigSent()
            }
        }

        let config = EmbedConfig(thoughtSpotHost: "https://test.com", authType: AuthType.TrustedAuthTokenCookieless)
        let viewConfig = SpecificViewConfig.liveboard(LiveboardViewConfig(liveboardId: "abc"))
        let controller = TestController(
            embedConfig: config,
            viewConfig: viewConfig,
            embedType: "Liveboard",
            onEmbedConfigSent: {
                expectation1.fulfill()
            },
            onViewConfigSent: {
                expectation2.fulfill()
            }
        )

        controller.handleInitVercelShell()
        wait(for: [expectation1, expectation2], timeout: 1.0)
    }


    func testGetAuthTokenCallbackSuccess() {
        let expectation = expectation(description: "Token sent")

        let controller = makeController {
            Future<String, Error> { promise in
                promise(.success("abc-token"))
            }
        }

        controller.onMessageSend = { msg in
            if let type = msg["type"] as? String, type == "AUTH_TOKEN_RESPONSE" {
                XCTAssertEqual(msg["token"] as? String, "abc-token")
                expectation.fulfill()
            }
        }

        controller.handleRequestAuthToken()
        wait(for: [expectation], timeout: 1.0)
    }

    func testEventListenerRegistrationAndTriggering() {
        let controller = makeController()
        let expectation = expectation(description: "Event listener called")

        controller.on(event: EmbedEvent.AuthInit) { data in
            expectation.fulfill()
        }

        controller.userContentController(
            WKUserContentController(),
            didReceive: makeScriptMessage(type: "EMBED_EVENT", eventName: "Init")
        )

        wait(for: [expectation], timeout: 1.0)
    }

    func testTriggerSendsCorrectPayload() {
        let controller = makeController()
        let expectation = expectation(description: "Message sent")

        controller.onMessageSend = { msg in
            XCTAssertEqual(msg["type"] as? String, "HOST_EVENT")
            XCTAssertEqual(msg["eventName"] as? String, "AppReload")
            expectation.fulfill()
        }

        controller.trigger(event: HostEvent.Reload, data: ["info": "now"])
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Helpers
    private func makeScriptMessage(type: String, eventName: String? = nil) -> WKScriptMessage {
        let messageJSON: [String: Any] = [
            "type": type,
            "eventName": eventName ?? "",
            "data": [:]
        ]
        let data = try! JSONSerialization.data(withJSONObject: messageJSON)
        let jsonString = String(data: data, encoding: .utf8)!

        class DummyFrame: WKFrameInfo {}

        return WKScriptMessage(name: "ReactNativeWebView", body: jsonString)
    }
}
