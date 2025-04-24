import Foundation
import WebKit
import SwiftUI
import Combine

public enum SpecificViewConfig: Codable {
    case liveboard(LiveboardViewConfig)
    // cases for ALL specific view config types we need
}

//public protocol ViewConfig: Encodable {}
public class BaseEmbedController: NSObject,
    WKScriptMessageHandler,
    ObservableObject,
    WKNavigationDelegate,
    WKUIDelegate {
    
    @Published public var webView: WKWebView!
    public var embedConfig: EmbedConfig
    public let viewConfig: SpecificViewConfig
    public let embedType: String
    internal var onMessageSend: (([String: Any]) -> Void)? = nil
    public var getAuthTokenCallback: (() -> Future<String, Error>)?

    private var cancellables = Set<AnyCancellable>()
    public let shellURL = URL(string: "https://mobile-embed-shell.vercel.app")!
    private var isShellInitialized = false

    public init(
        embedConfig: EmbedConfig,
        viewConfig: SpecificViewConfig,
        embedType: String,
        getAuthTokenCallback: (() -> Future<String, Error>)? = nil
    ) {
        self.embedConfig = embedConfig
        self.viewConfig  = viewConfig
        self.embedType   = embedType
        self.getAuthTokenCallback = getAuthTokenCallback
        super.init()

        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        contentController.add(self, name: "ReactNativeWebView")
        config.userContentController = contentController
        config.preferences.javaScriptEnabled = true

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        injectReactNativeWebViewShim()
        webView.load(URLRequest(url: shellURL))
    }

    private func injectReactNativeWebViewShim() {
        let js = """
        (function() {
          if (!window.ReactNativeWebView) {
            window.ReactNativeWebView = {
              postMessage: function(msg) {
                window.webkit.messageHandlers.ReactNativeWebView.postMessage(msg);
              }
            };
          }
        })();
        """
        let userScript = WKUserScript(
            source: js,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        webView.configuration.userContentController.addUserScript(userScript)
    }

    // MARK: - WKScriptMessageHandler
    public func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == "ReactNativeWebView",
              let body = message.body as? String,
              let json = try? JSONSerialization
                            .jsonObject(with: Data(body.utf8), options: []) as? [String:Any],
              let type = json["type"] as? String
        else { return }
        switch type {
        case "INIT_VERCEL_SHELL":
            handleInitVercelShell()
        case "REQUEST_AUTH_TOKEN":
            handleRequestAuthToken()
        case "EMBED_EVENT":
            if let eventName = json["eventName"] as? String,
               let data      = json["data"] {
                print("Embed event:", eventName, data)
            }
        default:
            break
        }
    }

    private func handleInitVercelShell() {
        isShellInitialized = true
        sendEmbedConfigToShell()
        sendViewConfigToShell()
    }

    public func handleRequestAuthToken() {
        guard let getAuthToken = self.getAuthTokenCallback else { return } // <<< CHANGE THIS
        getAuthToken()
          .sink(receiveCompletion: { comp in
            if case .failure(let err) = comp {
              let msg: [String:Any] = ["type":"AUTH_TOKEN_ERROR", "error": err.localizedDescription]
              self.sendJsonMessageToShell(msg)
            }
          }, receiveValue: { token in
            self.sendJsonMessageToShell(["token": token, "type":"AUTH_TOKEN_RESPONSE"] )
          })
          .store(in: &cancellables)
    }

    // MARK: - Sending Configs
    public func sendEmbedConfigToShell() {
        guard isShellInitialized else {
            print("Warning: Shell not initialized, cannot send EmbedConfig.")
            return
        }

        do {
            let encoder = JSONEncoder()
            let embedConfigData = try encoder.encode(embedConfig)

            guard var payloadDict = try JSONSerialization.jsonObject(with: embedConfigData, options: .mutableContainers) as? [String: Any] else {
                print("Error: Could not convert encoded EmbedConfig to dictionary.")
                return
            }

            payloadDict["getTokenFromSDK"] = true
            let msg: [String: Any] = ["payload": payloadDict, "type": "INIT"]
            sendJsonMessageToShell(msg)

        } catch {
            print("Error encoding or processing EmbedConfig for sending: \(error)")
        }
    }

    public func sendViewConfigToShell() {
        guard isShellInitialized else { return }
        do {
            let data: Data
            switch viewConfig {
                case .liveboard(let config):
                    data = try JSONEncoder().encode(config)
            }
            if let obj = try JSONSerialization.jsonObject(with: data) as? [String:Any] {
                let msg: [String:Any] = [
                    "embedType": embedType,
                    "viewConfig": obj,
                    "type":"EMBED"
                ]
                sendJsonMessageToShell(msg)
            }
        } catch { print(error) }
    }

    @objc func sendJsonMessageToShell(_ message: [String: Any]) {
        onMessageSend?(message)
        do {
            let data = try JSONSerialization.data(withJSONObject: message)
            if let json = String(data: data, encoding: .utf8) {
                let script = "window.postMessage(\(json), '*');"
                webView.evaluateJavaScript(script)
            }
        } catch { print(error) }
    }

    // MARK: - WKNavigationDelegate
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let initMsg: [String:Any] = ["type":"INIT_VERCEL_SHELL","status":"ready"]
            self.sendJsonMessageToShell(initMsg)
        }
    }
}
