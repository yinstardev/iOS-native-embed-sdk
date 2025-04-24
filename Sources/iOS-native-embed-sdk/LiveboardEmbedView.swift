//
//  LiveboardEmbedView.swift
//  iOS-native-embed-sdk
//
//  Created by Prashant.patil on 22/04/25.
//

import SwiftUI
import Combine

public struct SDKEmbedConfig {
    public let staticConfig: EmbedConfig
    public let getAuthTokenCallback: (() -> Future<String, Error>)?

    public init(
        staticConfig: EmbedConfig,
        getAuthTokenCallback: (() -> Future<String, Error>)?
    ) {
        self.staticConfig = staticConfig
        self.getAuthTokenCallback = getAuthTokenCallback
    }
}

/// Public-facing SwiftUI View for embedding Liveboards
public struct LiveboardEmbedView: View {
    @StateObject public var controller: LiveboardEmbed

    // Accept the wrapper struct
    public init(
        sdkEmbedConfig: SDKEmbedConfig,
        viewConfig: LiveboardViewConfig
    ) {
        _controller = StateObject(wrappedValue: LiveboardEmbed(
            sdkEmbedConfig: sdkEmbedConfig,
            viewConfig: viewConfig
        ))
    }

    public var body: some View {
        BaseEmbedView(controller: controller.baseController)
    }
}
