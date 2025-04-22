//
//  BaseEmbed.swift
//  iOS-native-embed-sdk
//
//  Created by Prashant.patil on 09/04/25.
//

import SwiftUI
import WebKit

struct BaseEmbedView: UIViewRepresentable {
    public var controller: BaseEmbedController

    public init(controller: BaseEmbedController) {
        self.controller = controller
    }

    public func makeUIView(context: Context) -> WKWebView {
        return controller.webView
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {
        // updates if needed
    }
}
