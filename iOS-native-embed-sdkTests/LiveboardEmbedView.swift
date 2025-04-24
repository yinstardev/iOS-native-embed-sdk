//
//  LiveboardEmbedView.swift
//  iOS-native-embed-sdk
//
//  Created by Prashant.patil on 23/04/25.
//

import XCTest
import SwiftUI
@testable import iOS_native_embed_sdk

final class LiveboardEmbedViewTests: XCTestCase {
    
    func testLiveboardEmbedViewInitialization() {
        // Given
        let config = EmbedConfig(
            thoughtSpotHost: "https://example.com",
            authType: "AuthServerCookieless",
            getAuthToken: nil
        )
        let viewConfig = LiveboardViewConfig(liveboardId: "abc123")

        // When
        let view = LiveboardEmbedView(embedConfig: config, viewConfig: viewConfig)

        // Then
        let controller = view.controller
        XCTAssertEqual(controller.baseController.embedType, "Liveboard")
        XCTAssertEqual(controller.baseController.embedConfig.thoughtSpotHost, "https://example.com")

        if let vc = controller.baseController.viewConfig as? LiveboardViewConfig {
            XCTAssertEqual(vc.liveboardId, "abc123")
        } else {
            XCTFail("Expected LiveboardViewConfig")
        }
    }
}
