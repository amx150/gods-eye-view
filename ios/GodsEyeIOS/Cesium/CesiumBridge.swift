import Foundation
import Combine
@preconcurrency import WebKit


// MARK: - Aircraft Info

struct AircraftInfo: Equatable {

    let icao24: String
    let callsign: String?
    let registration: String?
    let airline: String?
    let typeName: String?

    let latitude: Double?
    let longitude: Double?

    let altitudeFeet: Int?
    let speedKmh: Int?
    let heading: Int?

    let onGround: Bool
    let stale: Bool

    let origin: String?
    let destination: String?


    init?(payload: [String: Any]) {

        guard
            let icao24 =
                payload["icao24"] as? String,
            !icao24.isEmpty
        else {
            return nil
        }


        self.icao24 = icao24

        self.callsign =
            Self.string(
                payload["callsign"]
            )

        self.registration =
            Self.string(
                payload["registration"]
            )

        self.airline =
            Self.string(
                payload["airline"]
            )

        self.typeName =
            Self.string(
                payload["typeName"]
            )

        self.latitude =
            Self.double(
                payload["latitude"]
            )

        self.longitude =
            Self.double(
                payload["longitude"]
            )

        self.altitudeFeet =
            Self.int(
                payload["altitudeFeet"]
            )

        self.speedKmh =
            Self.int(
                payload["speedKmh"]
            )

        self.heading =
            Self.int(
                payload["heading"]
            )

        self.onGround =
            payload["onGround"] as? Bool
            ?? false

        self.stale =
            payload["stale"] as? Bool
            ?? false

        self.origin =
            Self.string(
                payload["origin"]
            )

        self.destination =
            Self.string(
                payload["destination"]
            )
    }


    var displayName: String {

        if let callsign,
           !callsign.isEmpty {

            return callsign
        }

        if let registration,
           !registration.isEmpty {

            return registration
        }

        return icao24.uppercased()
    }


    var routeText: String? {

        guard
            let origin,
            let destination,
            !origin.isEmpty,
            !destination.isEmpty
        else {
            return nil
        }

        return "\(origin) → \(destination)"
    }


    private static func string(
        _ value: Any?
    ) -> String? {

        guard
            let value =
                value as? String
        else {
            return nil
        }

        let trimmed =
            value.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        return trimmed.isEmpty
            ? nil
            : trimmed
    }


    private static func double(
        _ value: Any?
    ) -> Double? {

        if let number =
            value as? NSNumber {

            return number.doubleValue
        }

        return value as? Double
    }


    private static func int(
        _ value: Any?
    ) -> Int? {

        if let number =
            value as? NSNumber {

            return number.intValue
        }

        return value as? Int
    }
}


// MARK: - Nearby Flight

struct NearbyFlight:
    Identifiable,
    Equatable
{

    let icao24: String
    let callsign: String?

    let distanceKm: Double

    let altitudeFeet: Int?
    let speedKmh: Int?
    let heading: Int?

    let aircraftClass: String?

    let onGround: Bool


    var id: String {
        icao24
    }


    var displayName: String {

        if let callsign,
           !callsign.isEmpty {

            return callsign
        }

        return icao24.uppercased()
    }


    init?(
        payload: [String: Any]
    ) {

        guard
            let icao24 =
                payload["icao24"]
                as? String,

            !icao24.isEmpty,

            let distance =
                payload["distanceKm"]
                as? NSNumber
        else {
            return nil
        }


        self.icao24 =
            icao24


        self.callsign =
            Self.string(
                payload["callsign"]
            )


        self.distanceKm =
            distance.doubleValue


        self.altitudeFeet =
            Self.int(
                payload["altitudeFeet"]
            )


        self.speedKmh =
            Self.int(
                payload["speedKmh"]
            )


        self.heading =
            Self.int(
                payload["heading"]
            )


        self.aircraftClass =
            Self.string(
                payload["aircraftClass"]
            )


        self.onGround =
            payload["onGround"] as? Bool
            ?? false
    }


    private static func string(
        _ value: Any?
    ) -> String? {

        guard
            let value =
                value as? String
        else {
            return nil
        }

        let trimmed =
            value.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        return trimmed.isEmpty
            ? nil
            : trimmed
    }


    private static func int(
        _ value: Any?
    ) -> Int? {

        if let number =
            value as? NSNumber {

            return number.intValue
        }

        return value as? Int
    }
}


// MARK: - Cesium Bridge

@MainActor
final class CesiumBridge:
    NSObject,
    ObservableObject
{

    // MARK: Runtime State

    @Published private(set)
    var isReady = false


    @Published private(set)
    var lastMessage: String?


    // MARK: Aircraft State

    @Published private(set)
    var selectedAircraft: AircraftInfo?


    @Published private(set)
    var nearbyFlights: [NearbyFlight] = []


    // MARK: Layer State

    @Published private(set)
    var enabledLayers: Set<String> = []


    @Published private(set)
    var pendingLayers: Set<String> = []


    @Published private(set)
    var layerErrorMessage: String?


    private var previousLayerStates:
        [String: Bool] = [:]


    // MARK: WebView

    weak var webView: WKWebView?


    // MARK: Attach

    func attach(
        webView: WKWebView
    ) {

        self.webView =
            webView
    }


    // MARK: Page Loaded

    func markPageLoaded() {

        lastMessage =
            "page loaded"

        probeGodsEyeView()
    }


    // MARK: Runtime Probe

    func probeGodsEyeView() {

        evaluate("""
        (() => {

          const gev =
            window.__godsEyeView;


          const ready =
            Boolean(
              gev?.viewer
            );


          if (
            ready
            && !window.__GEV_IOS_MODE_READY__
          ) {

            window.__GEV_IOS_MODE_READY__ =
              true;


            document.documentElement
              .classList
              .add(
                "gev-ios"
              );


            if (
              gev?.styleManager
                ?.setCleanView
            ) {

              gev.styleManager
                .setCleanView(
                  true
                );
            }


            window.GEVNative
              ?.postMessage(
                "ios-mode-ready",
                {}
              );
          }


          window.GEVNative
            ?.postMessage(
              "runtime-status",
              {
                ready
              }
            );


          return ready;

        })();
        """)
    }


    // MARK: Fly To

    func flyTo(
        latitude: Double,
        longitude: Double,
        altitudeMeters: Double = 25_000
    ) {

        evaluate("""
        (() => {

          const gev =
            window.__godsEyeView;


          if (
            !gev?.flyToDegrees
          ) {

            window.GEVNative
              ?.postMessage(
                "fly-to-error",
                {
                  reason:
                    "flyToDegrees unavailable"
                }
              );


            return false;
          }


          gev.flyToDegrees(
            \(latitude),
            \(longitude),
            \(altitudeMeters)
          );


          window.GEVNative
            ?.postMessage(
              "fly-to-complete",
              {
                latitude:
                  \(latitude),

                longitude:
                  \(longitude)
              }
            );


          return true;

        })();
        """)
    }


    // MARK: Layer Helpers

    func isLayerEnabled(
        _ id: String
    ) -> Bool {

        enabledLayers.contains(
            id
        )
    }


    func isLayerPending(
        _ id: String
    ) -> Bool {

        pendingLayers.contains(
            id
        )
    }


    func clearLayerError() {

        layerErrorMessage =
            nil
    }


    // MARK: Set Layer

    func setLayer(
        id: String,
        enabled: Bool
    ) {

        let safeID =
            escapeJavaScriptString(
                id
            )


        let previousState =
            enabledLayers.contains(
                id
            )


        previousLayerStates[id] =
            previousState


        pendingLayers.insert(
            id
        )


        if enabled {

            enabledLayers.insert(
                id
            )

        } else {

            enabledLayers.remove(
                id
            )
        }


        if id == "flights",
           !enabled {

            nearbyFlights = []
            selectedAircraft = nil
        }


        evaluate("""
        (async () => {

          if (
            !window.GEViOS
              ?.setLayer
          ) {

            window.GEVNative
              ?.postMessage(
                "layer-error",
                {
                  id:
                    "\(safeID)",

                  message:
                    "GEViOS bridge unavailable"
                }
              );


            return false;
          }


          return await window.GEViOS
            .setLayer(
              "\(safeID)",
              \(enabled ? "true" : "false")
            );

        })();
        """)
    }


    // MARK: Nearby Flights

    func requestNearbyFlights(
        latitude: Double,
        longitude: Double,
        radiusKm: Double = 100,
        maxCount: Int = 20
    ) {

        evaluate("""
        (() => {

          if (
            !window.GEViOS
              ?.publishNearbyFlights
          ) {

            window.GEVNative
              ?.postMessage(
                "nearby-flights-error",
                {
                  reason:
                    "publishNearbyFlights unavailable"
                }
              );


            return false;
          }


          window.GEViOS
            .publishNearbyFlights(
              \(latitude),
              \(longitude),
              \(radiusKm),
              \(maxCount)
            );


          return true;

        })();
        """)
    }


    // MARK: Track Aircraft

    func trackAircraft(
        icao24: String
    ) {

        let safeID =
            escapeJavaScriptString(
                icao24
            )


        evaluate("""
        (() => {

          if (
            !window.GEViOS
              ?.trackAircraft
          ) {

            window.GEVNative
              ?.postMessage(
                "aircraft-track-error",
                {
                  icao24:
                    "\(safeID)",

                  reason:
                    "trackAircraft unavailable"
                }
              );


            return false;
          }


          return window.GEViOS
            .trackAircraft(
              "\(safeID)"
            );

        })();
        """)
    }


    // MARK: Stop Tracking

    func stopTracking() {

        selectedAircraft =
            nil


        evaluate("""
        (() => {

          if (
            !window.GEViOS
              ?.stopTracking
          ) {

            return false;
          }


          return window.GEViOS
            .stopTracking();

        })();
        """)
    }


    // MARK: JavaScript Helpers

    private func escapeJavaScriptString(
        _ value: String
    ) -> String {

        value
            .replacingOccurrences(
                of: "\\",
                with: "\\\\"
            )
            .replacingOccurrences(
                of: "\"",
                with: "\\\""
            )
            .replacingOccurrences(
                of: "\n",
                with: "\\n"
            )
            .replacingOccurrences(
                of: "\r",
                with: "\\r"
            )
    }


    private func evaluate(
        _ javascript: String
    ) {

        webView?.evaluateJavaScript(
            javascript
        ) { [weak self] _, error in

            guard let error else {
                return
            }


            Task { @MainActor in

                self?.lastMessage =
                    "JS: \(error.localizedDescription)"
            }
        }
    }
}


// MARK: - WKScriptMessageHandler

extension CesiumBridge:
    WKScriptMessageHandler
{

    nonisolated func userContentController(
        _ userContentController:
            WKUserContentController,

        didReceive message:
            WKScriptMessage
    ) {

        guard
            message.name == "gev"
        else {
            return
        }


        let messageBody =
            message.body


        Task { @MainActor in

            guard
                let envelope =
                    messageBody
                    as? [String: Any],

                let type =
                    envelope["type"]
                    as? String
            else {
                return
            }


            lastMessage =
                type


            let payload =
                envelope["payload"]
                as? [String: Any]


            switch type {


            // MARK: Runtime

            case "runtime-status":

                if let ready =
                    payload?["ready"]
                    as? Bool {

                    isReady =
                        ready
                }


            case "native-ready":

                probeGodsEyeView()


            // MARK: Aircraft

            case "aircraft-selected",
                 "aircraft-updated":

                if let payload,
                   let aircraft =
                    AircraftInfo(
                        payload:
                            payload
                    ) {

                    selectedAircraft =
                        aircraft
                }


            case "aircraft-cleared":

                selectedAircraft =
                    nil


            // MARK: Nearby Flights

            case "nearby-flights":

                guard
                    let rawItems =
                        payload?["items"]
                        as? [[String: Any]]
                else {

                    nearbyFlights =
                        []

                    break
                }


                nearbyFlights =
                    rawItems
                        .compactMap {

                            NearbyFlight(
                                payload:
                                    $0
                            )
                        }
                        .sorted {

                            $0.distanceKm
                            <
                            $1.distanceKm
                        }


            // MARK: Layer Changed

            case "layer-changed":

                guard
                    let id =
                        payload?["id"]
                        as? String,

                    let enabled =
                        payload?["enabled"]
                        as? Bool
                else {
                    break
                }


                pendingLayers.remove(
                    id
                )


                previousLayerStates
                    .removeValue(
                        forKey:
                            id
                    )


                if enabled {

                    enabledLayers.insert(
                        id
                    )

                } else {

                    enabledLayers.remove(
                        id
                    )
                }


                if id == "flights",
                   !enabled {

                    nearbyFlights = []
                    selectedAircraft = nil
                }


            // MARK: Layer Error

            case "layer-error":

                if let id =
                    payload?["id"]
                    as? String {

                    if let previousState =
                        previousLayerStates[
                            id
                        ] {

                        if previousState {

                            enabledLayers.insert(
                                id
                            )

                        } else {

                            enabledLayers.remove(
                                id
                            )
                        }
                    }


                    pendingLayers.remove(
                        id
                    )


                    previousLayerStates
                        .removeValue(
                            forKey:
                                id
                        )
                }


                layerErrorMessage =
                    payload?["message"]
                    as? String
                    ??
                    "Não foi possível alterar esta camada."


            // MARK: Nearby Error

            case "nearby-flights-error":

                nearbyFlights =
                    []


            // MARK: Tracking Error

            case "aircraft-track-error":

                layerErrorMessage =
                    payload?["reason"]
                    as? String
                    ??
                    "Não foi possível acompanhar esta aeronave."


            default:

                break
            }
        }
    }
}
