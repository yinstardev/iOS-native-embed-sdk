
// LiveboardEmbed.swift
import Foundation
import WebKit
import SwiftUI
import Combine

public struct LiveboardViewConfig: ViewConfig {
    public let liveboardId: String
    
    public init(liveboardId: String) {
        self.liveboardId = liveboardId
    }
}
/// just pass embedConfig, liveboardId, embedType
public class LiveboardEmbed: ObservableObject {
    private let base: BaseEmbedController

    public init(
        embedConfig: EmbedConfig,
        viewConfig: LiveboardViewConfig
    ) {
        self.base = BaseEmbedController(
            embedConfig: embedConfig,
            viewConfig:  viewConfig,
            embedType:   "Liveboard"
        )
    }

    public var webView: WKWebView { base.webView }
    public var baseController: BaseEmbedController {base}
}
