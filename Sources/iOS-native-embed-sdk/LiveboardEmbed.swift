
// LiveboardEmbed.swift
import Foundation
import WebKit
import SwiftUI
import Combine

/// just pass embedConfig, liveboardId, embedType
public class LiveboardEmbed: ObservableObject {
    private let base: BaseEmbedController

    public init(
        tsEmbedConfig: TSEmbedConfig,
        viewConfig: LiveboardViewConfig
    ) {
        self.base = BaseEmbedController(
            embedConfig: tsEmbedConfig.embedConfig,
            viewConfig:  .liveboard(viewConfig),
            embedType:   "Liveboard",
            getAuthTokenCallback: tsEmbedConfig.getAuthToken
        )
    }

    public var webView: WKWebView { base.webView }
    public var baseController: BaseEmbedController {base}
}
