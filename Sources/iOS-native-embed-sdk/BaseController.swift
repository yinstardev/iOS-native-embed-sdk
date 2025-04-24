import Foundation
import WebKit
import SwiftUI
import Combine

public enum SpecificViewConfig: Codable {
    case liveboard(LiveboardViewConfig)
    // cases for ALL specific view config types we need
}

public class BaseEmbedController: NSObject,
    WKScriptMessageHandler,
    ObservableObject,
    WKNavigationDelegate,
    WKUIDelegate {

    @Published public var webView: WKWebView!
    public let embedConfig: EmbedConfig
    public let viewConfig: SpecificViewConfig
    public let embedType: String
    internal var onMessageSend: (([String: Any]) -> Void)? = nil
    public var getAuthTokenCallback: (() -> Future<String, Error>)?

    private var cancellables = Set<AnyCancellable>()
    private let shellURL = URL(string: "https://mobile-embed-shell.vercel.app")!
    private var isShellInitialized = false

    // --- Storage for Event Listeners ---
    public typealias EventCallback = (Any?) -> Void
    private var eventListeners: [EmbedEvent: [EventCallback]] = [:]

    // --- Passing EmbedConfig, ViewConfig ( Corresponding to the EmbedType ), embedType, authTokenCallback ---
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

        // Configure WebView
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        let messageHandlerName = "ReactNativeWebView_\(UUID().uuidString)"
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

    // --- Message Handling - Messages from Vercel Shell ---
    public func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let body = message.body as? String,
              let json = try? JSONSerialization.jsonObject(with: Data(body.utf8), options: []) as? [String:Any],
              let type = json["type"] as? String
        else {
            print("Error: Could not parse message body or type from WebView.")
            return
        }

        switch type {
        case "INIT_VERCEL_SHELL":
            handleInitVercelShell()
        case "REQUEST_AUTH_TOKEN":
            handleRequestAuthToken()
        case "EMBED_EVENT":
            if let eventNameStr = json["eventName"] as? String,
               // We use EmbedEvent str
               let event = EmbedEvent(rawValue: eventNameStr) {
                let eventData = json["data"]
                // Call all registered listeners for this event
                if let listeners = eventListeners[event] {
                    for listener in listeners {
                        listener(eventData)
                    }
                }
            } else if let eventNameStr = json["eventName"] as? String {
                 print("Received unknown embed event type string: \(eventNameStr)")
            }
        default:
            print("Received unknown message type: \(type)")
            break
        }
    }

    // once the INIT_VERCEL_SHELL is received.
    private func handleInitVercelShell() {
        isShellInitialized = true
        sendEmbedConfigToShell()
        sendViewConfigToShell()
    }

    // Vercel Shell requests the Auth Token - We get the token and send back.
    public func handleRequestAuthToken() {
        guard let getAuthToken = self.getAuthTokenCallback else { return }
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

    // EmbedConfig - except the getAuthToken
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

    // ViewConfig and embedType
    public func sendViewConfigToShell() {
        guard isShellInitialized else { print("Warning: Shell not initialized..."); return }
        do {
            let data: Data
            switch viewConfig {
                case .liveboard(let config):
                    data = try JSONEncoder().encode(config)
                // other type of embeds
            }
            if let obj = try JSONSerialization.jsonObject(with: data) as? [String:Any] {
                let msg: [String:Any] = ["embedType": embedType, "viewConfig": obj, "type":"EMBED"]
                sendJsonMessageToShell(msg)
            }
        } catch { print("Error encoding specific view config: \(error)") }
    }

    @objc func sendJsonMessageToShell(_ message: [String: Any]) {
        onMessageSend?(message)
        do {
            let data = try JSONSerialization.data(withJSONObject: message)
            if let json = String(data: data, encoding: .utf8) {
                guard webView != nil else {
                    print("Error: webView not initialized before sending message.")
                    return
                }
                let script = "window.postMessage(\(json), '*');"
                webView.evaluateJavaScript(script) { result, error in
                     if let error = error {
                         print("JavaScript evaluation error: \(error)")
                     }
                 }
            }
        } catch { print("Error serializing message for JS: \(error)") }
    }

    // webView didFinish
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Use a small delay to ensure shell JS is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("WebView finished loading. Sending INIT_VERCEL_SHELL.")
            let initMsg: [String:Any] = ["type":"INIT_VERCEL_SHELL","status":"ready"]
            self.sendJsonMessageToShell(initMsg)
        }
    }

    // MARK: - Public Event Listener API

    /// Registers a callback for a specific EmbedEvent.
    ///
    /// - Parameters:
    ///   - event: The `EmbedEvent` to listen for.
    ///   - callback: The closure to execute when the event is received. The parameter is the optional payload (`Any?`).
    public func on(event: EmbedEvent, callback: @escaping EventCallback) {
        eventListeners[event, default: []].append(callback)
        print("Listener registered for \(event.rawValue)")
    }

    /// Unregisters **all** callbacks for a specific EmbedEvent.
    /// Note: Removing individual closures is complex and unreliable in Swift.
    /// This method clears all listeners for the given event.
    ///
    /// - Parameter event: The `EmbedEvent` to stop listening to.
    public func off(event: EmbedEvent) {
        eventListeners.removeValue(forKey: event)
        print("All listeners unregistered for \(event.rawValue)")
    }

    // MARK: - Public Host Event Trigger API

    /// Triggers an event to be sent to the embedded content.
    ///
    /// - Parameters:
    ///   - event: The `HostEvent` to trigger.
    ///   - data: Optional dictionary containing data for the event payload. Defaults to empty.
    public func trigger(event: HostEvent, data: [String: Any]? = nil) {
        let eventId = UUID().uuidString
        let embedEventPayload: [String: Any] = [
            "eventName": event.rawValue,
            "payload": data ?? [:],
            "eventId": eventId,
            "type": "HOST_EVENT"
        ]
        print("Triggering Host Event: \(event.rawValue)")
        sendJsonMessageToShell(embedEventPayload)
        // TODO: Does not currently wait for or handle responses from the embed.
    }

    // MARK: - Cleanup (Example)
    deinit {
        // TODO: Remove message handler to prevent leaks if controller is deallocated
        // while webview still exists (though usually webview goes away first)
        // Consider the implications if multiple controllers use the same webview instance.
        // webView?.configuration.userContentController.removeScriptMessageHandler(forName: messageHandlerName)
        print("BaseEmbedController deinit")
    }
}
