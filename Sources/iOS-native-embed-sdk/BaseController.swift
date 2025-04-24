import Foundation
import WebKit
import SwiftUI
import Combine

public enum AuthType: String {
    case TrustedAuthTokenCookieless = "AuthServerCookieless"
}

public struct EmbedConfig {
    public let thoughtSpotHost: String
    public let authType: String
    public let getAuthToken: (() -> Future<String, Error>)?
    
    public init(
        thoughtSpotHost: String,
        authType: String,
        getAuthToken: (() -> Future<String, Error>)?
    ) {
        self.thoughtSpotHost = thoughtSpotHost
        self.authType = authType
        self.getAuthToken = getAuthToken
    }
}

public struct EmbedConfigForEncoding: Encodable {
    public let thoughtSpotHost: String
    public let authType: String
    public let getTokenFromSDK: Bool?
}

public protocol ViewConfig: Encodable {}
public class BaseEmbedController: NSObject,
    WKScriptMessageHandler,
    ObservableObject,
    WKNavigationDelegate,
    WKUIDelegate {
    
    @Published public var webView: WKWebView!
    public var embedConfig: EmbedConfig
    public let viewConfig: ViewConfig
    public let embedType: String
    internal var onMessageSend: (([String: Any]) -> Void)? = nil

    private var cancellables = Set<AnyCancellable>()
    public let shellURL = URL(string: "https://mobile-embed-shell.vercel.app")!
    private var isShellInitialized = false

    public init(
        embedConfig: EmbedConfig,
        viewConfig: ViewConfig,
        embedType: String
    ) {
        self.embedConfig = embedConfig
        self.viewConfig  = viewConfig
        self.embedType   = embedType
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
        guard let getAuthToken = embedConfig.getAuthToken else { return }
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
        guard isShellInitialized else { return }
        let cfg = EmbedConfigForEncoding(
            thoughtSpotHost: embedConfig.thoughtSpotHost,
            authType:      embedConfig.authType,
            getTokenFromSDK: true
        )
        do {
            let data = try JSONEncoder().encode(cfg)
            if let obj = try JSONSerialization.jsonObject(with: data) as? [String:Any] {
                let msg: [String:Any] = ["payload": obj, "type":"INIT"]
                sendJsonMessageToShell(msg)
            }
        } catch { print(error) }
    }

    private func sendViewConfigToShell() {
        guard isShellInitialized else { return }
        do {
            let data = try JSONEncoder().encode(viewConfig)
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
