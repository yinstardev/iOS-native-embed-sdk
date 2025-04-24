//
//  LiveboardEmbedView.swift
//  iOS-native-embed-sdk
//
//  Created by Prashant.patil on 22/04/25.
//

import SwiftUI
import Combine

public struct TSEmbedConfig {
    public let embedConfig: EmbedConfig
    public let getAuthToken: (() -> Future<String, Error>)?

    public init(
        embedConfig: EmbedConfig,
        getAuthToken: (() -> Future<String, Error>)?
    ) {
        self.embedConfig = embedConfig
        self.getAuthToken = getAuthToken
    }
}

/// Public-facing SwiftUI View for embedding Liveboards
public struct LiveboardEmbedView: View {
    @StateObject public var controller: LiveboardEmbed

    // Accept the wrapper struct
    public init(
        tsEmbedConfig: TSEmbedConfig,
        viewConfig: LiveboardViewConfig
    ) {
        _controller = StateObject(wrappedValue: LiveboardEmbed(
            tsEmbedConfig: tsEmbedConfig,
            viewConfig: viewConfig
        ))
    }

    public var body: some View {
        BaseEmbedView(controller: controller.baseController)
    }
}
