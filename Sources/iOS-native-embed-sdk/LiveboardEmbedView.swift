//
//  LiveboardEmbedView.swift
//  iOS-native-embed-sdk
//
//  Created by Prashant.patil on 22/04/25.
//

import SwiftUI

/// Public-facing SwiftUI View for embedding Liveboards
public struct LiveboardEmbedView: View {
    @StateObject public var controller: LiveboardEmbed

    public init(embedConfig: EmbedConfig, viewConfig: LiveboardViewConfig) {
        _controller = StateObject(wrappedValue: LiveboardEmbed(
            embedConfig: embedConfig,
            viewConfig: viewConfig
        ))
    }
    
    public var body: some View {
        BaseEmbedView(controller: controller.baseController)
    }
}
