//
//  LiveboardEmbedTests.swift
//  iOS-native-embed-sdk
//
//  Created by Prashant.patil on 23/04/25.
//

import XCTest
import WebKit
@testable import iOS_native_embed_sdk

final class LiveboardEmbedTests: XCTestCase {

    func testLiveboardEmbedInitialization() {
        // Given
        let config = EmbedConfig(
            thoughtSpotHost: "https://example.com",
            authType: "AuthServerCookieless",
            getAuthToken: nil
        )
        let viewConfig = LiveboardViewConfig(liveboardId: "abc123")

        // When
        let embed = LiveboardEmbed(embedConfig: config, viewConfig: viewConfig)

        // Then
        XCTAssertNotNil(embed.webView)
        XCTAssertEqual(embed.baseController.embedConfig.thoughtSpotHost, "https://example.com")
        XCTAssertEqual(embed.baseController.embedType, "Liveboard")
        
        if let vc = embed.baseController.viewConfig as? LiveboardViewConfig {
            XCTAssertEqual(vc.liveboardId, "abc123")
        } else {
            XCTFail("Expected viewConfig to be LiveboardViewConfig")
        }
    }
}
