import SwiftUI
import WebKit

struct CesiumWebView: UIViewRepresentable {
    let url: URL
    @ObservedObject var bridge: CesiumBridge

    func makeCoordinator() -> Coordinator {
        Coordinator(bridge: bridge)
    }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(bridge, name: "gev")

        let bridgeScript = WKUserScript(
            source: """
            (() => {
              window.__GEV_IOS__ = true;

              window.GEVNative = {
                postMessage(type, payload = {}) {
                  try {
                    window.webkit.messageHandlers.gev.postMessage({
                      type,
                      payload
                    });
                  } catch (error) {
                    console.warn("[GEV iOS bridge]", error);
                  }
                }
              };

              window.GEVNative.postMessage("native-ready", {
                platform: "ios"
              });

              document.documentElement.classList.add("gev-ios");
            })();
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        controller.addUserScript(bridgeScript)

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = true
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.navigationDelegate = context.coordinator

        bridge.attach(webView: webView)

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        webView.load(request)

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let bridge: CesiumBridge

        init(bridge: CesiumBridge) {
            self.bridge = bridge
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            bridge.markPageLoaded()

            // Cesium and all data modules initialize asynchronously.
            // Probe a few times so the native UI can know when the runtime exists.
            Task { @MainActor in
                for delay in [250, 750, 1_500, 3_000] {
                    try? await Task.sleep(for: .milliseconds(delay))
                    bridge.probeGodsEyeView()
                }
            }
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            print("[GEV iOS] navigation failed:", error)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            print("[GEV iOS] provisional navigation failed:", error)
        }
    }
}
