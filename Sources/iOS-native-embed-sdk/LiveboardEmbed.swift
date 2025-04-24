
// LiveboardEmbed.swift
import Foundation
import WebKit
import SwiftUI
import Combine

//public struct LiveboardViewConfig: ViewConfig {
//    public let liveboardId: String
//    
//    public init(liveboardId: String) {
//        self.liveboardId = liveboardId
//    }
//}
/// just pass embedConfig, liveboardId, embedType
public class LiveboardEmbed: ObservableObject {
    private let base: BaseEmbedController

    public init(
        sdkEmbedConfig: SDKEmbedConfig,
        viewConfig: LiveboardViewConfig
    ) {
        self.base = BaseEmbedController(
            embedConfig: sdkEmbedConfig.staticConfig,
            viewConfig:  .liveboard(viewConfig),
            embedType:   "Liveboard",
            getAuthTokenCallback: sdkEmbedConfig.getAuthTokenCallback
        )
    }

    public var webView: WKWebView { base.webView }
    public var baseController: BaseEmbedController {base}
}
