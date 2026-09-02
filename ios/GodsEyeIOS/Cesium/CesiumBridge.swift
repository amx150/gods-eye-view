import Foundation
import WebKit
import Combine

@MainActor
final class CesiumBridge: NSObject, ObservableObject {
    @Published private(set) var isReady = false
    @Published private(set) var lastMessage: String?

    weak var webView: WKWebView?

    func attach(webView: WKWebView) {
        self.webView = webView
    }

    func markPageLoaded() {
        lastMessage = "page loaded"
        probeGodsEyeView()
    }

    func probeGodsEyeView() {
        evaluate("""
        (() => {
          const ready = Boolean(window.__godsEyeView?.viewer);
          window.GEVNative?.postMessage("runtime-status", { ready });
          return ready;
        })();
        """)
    }

    func flyTo(
        latitude: Double,
        longitude: Double,
        altitudeMeters: Double = 25_000
    ) {
        evaluate("""
        (() => {
          const gev = window.__godsEyeView;

          if (!gev?.flyToDegrees) {
            window.GEVNative?.postMessage(
              "fly-to-error",
              { reason: "flyToDegrees unavailable" }
            );

            return false;
          }

          gev.flyToDegrees(
            \(latitude),
            \(longitude),
            \(altitudeMeters)
          );

          window.GEVNative?.postMessage(
            "fly-to-complete",
            {
              latitude: \(latitude),
              longitude: \(longitude)
            }
          );

          return true;
        })();
        """)
    }

    func setLayer(id: String, enabled: Bool) {
        let safeID = id
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        evaluate("""
        (() => {
          const manager = window.__godsEyeView?.dataManager;
          if (!manager) return false;

          const id = "\(safeID)";
          const desired = \(enabled ? "true" : "false");

          // The exact public method can evolve upstream. Prefer public APIs
          // when present; otherwise notify the web client through an event.
          if (desired && typeof manager.enable === "function") {
            manager.enable(id);
            return true;
          }

          if (!desired && typeof manager.disable === "function") {
            manager.disable(id);
            return true;
          }

          window.dispatchEvent(new CustomEvent("gev:native-layer-request", {
            detail: { id, enabled: desired }
          }));
          return true;
        })();
        """)
    }

    private func evaluate(_ javascript: String) {
        webView?.evaluateJavaScript(javascript) { [weak self] _, error in
            guard let error else { return }
            Task { @MainActor in
                self?.lastMessage = "JS: \(error.localizedDescription)"
            }
        }
    }
}

extension CesiumBridge: WKScriptMessageHandler {
    nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == "gev" else { return }

        Task { @MainActor in
            if let payload = message.body as? [String: Any],
               let type = payload["type"] as? String {
                lastMessage = type

                if type == "runtime-status",
                   let data = payload["payload"] as? [String: Any],
                   let ready = data["ready"] as? Bool {
                    isReady = ready
                }

                if type == "native-ready" {
                    probeGodsEyeView()
                }
            } else {
                lastMessage = String(describing: message.body)
            }
        }
    }
}
