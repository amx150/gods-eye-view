import SwiftUI

struct ContentView: View {

    @StateObject private var bridge =
        CesiumBridge()

    @StateObject private var locationManager =
        LocationManager()

    @State private var flightsEnabled = false
    @State private var satellitesEnabled = false
    @State private var earthquakesEnabled = false

    @State private var lastCoordinate:
        UserCoordinate?

    @State private var showNearbySheet = false

    @State private var nearbyRadiusKm:
        Double = 100

    @State private var nearbySearch = ""


    var body: some View {

        ZStack {

            CesiumWebView(
                url: AppConfiguration.webURL,
                bridge: bridge
            )
            .ignoresSafeArea()


            VStack(spacing: 10) {

                statusBar

                Spacer()


                if let aircraft =
                    bridge.selectedAircraft {

                    aircraftCard(
                        aircraft
                    )
                }


                if let error =
                    locationManager.errorMessage {

                    locationErrorCard(
                        error
                    )
                }


                controls
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 24)
        }
        .background(Color.black)

        .animation(
            .easeInOut(
                duration: 0.2
            ),
            value:
                bridge.selectedAircraft
        )

        .onChange(
            of:
                locationManager.coordinate
        ) { _, coordinate in

            guard let coordinate else {
                return
            }

            lastCoordinate =
                coordinate

            goToUserLocation(
                coordinate
            )
        }

        .sheet(
            isPresented:
                $showNearbySheet
        ) {

            nearbySheet
                .presentationDetents(
                    [
                        .height(180),
                        .medium,
                        .large
                    ]
                )
                .presentationDragIndicator(
                    .visible
                )
                .presentationBackgroundInteraction(
                    .enabled(
                        upThrough:
                            .medium
                    )
                )
        }
    }


    // MARK: - Filtered Flights

    private var filteredNearbyFlights:
        [NearbyFlight] {

        let query =
            nearbySearch
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .lowercased()


        guard !query.isEmpty else {

            return bridge
                .nearbyFlights
        }


        return bridge
            .nearbyFlights
            .filter {

                $0.displayName
                    .lowercased()
                    .contains(query)

                ||

                $0.icao24
                    .lowercased()
                    .contains(query)

                ||

                (
                    $0.aircraftClass?
                        .lowercased()
                        .contains(query)
                    ?? false
                )
            }
    }


    // MARK: - Status Bar

    private var statusBar:
        some View {

        HStack(spacing: 8) {

            Circle()
                .fill(
                    bridge.isReady
                    ? Color.green
                    : Color.orange
                )
                .frame(
                    width: 8,
                    height: 8
                )


            Text(
                bridge.isReady
                ? "GEV CONNECTED"
                : "CONNECTING…"
            )
            .font(
                .system(
                    size: 11,
                    weight: .semibold,
                    design: .monospaced
                )
            )
            .foregroundStyle(.white)


            Spacer()


            if locationManager.isLocating {

                ProgressView()
                    .controlSize(.small)
                    .tint(.white)

            } else if let message =
                        bridge.lastMessage {

                Text(message)
                    .lineLimit(1)
                    .font(
                        .system(
                            size: 10,
                            design: .monospaced
                        )
                    )
                    .foregroundStyle(
                        .white.opacity(0.65)
                    )
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(
            .black.opacity(0.72)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 10
            )
        )
    }


    // MARK: - Controls

    private var controls:
        some View {

        VStack(spacing: 10) {

            HStack(spacing: 8) {

                Button {

                    flightsEnabled.toggle()

                    bridge.setLayer(
                        id: "flights",
                        enabled:
                            flightsEnabled
                    )


                    if flightsEnabled {

                        scheduleNearbyRefresh()
                    }

                } label: {

                    Label(
                        flightsEnabled
                        ? "Flights ON"
                        : "Flights",
                        systemImage:
                            "airplane"
                    )
                }
                .buttonStyle(
                    .borderedProminent
                )


                Button {

                    satellitesEnabled.toggle()

                    bridge.setLayer(
                        id: "satellites",
                        enabled:
                            satellitesEnabled
                    )

                } label: {

                    Image(
                        systemName:
                            "antenna.radiowaves.left.and.right"
                    )
                }
                .buttonStyle(.bordered)


                Button {

                    earthquakesEnabled.toggle()

                    bridge.setLayer(
                        id: "earthquakes",
                        enabled:
                            earthquakesEnabled
                    )

                } label: {

                    Image(
                        systemName:
                            "waveform.path.ecg"
                    )
                }
                .buttonStyle(.bordered)


                Spacer()
            }


            HStack(spacing: 8) {

                Button {

                    locationManager
                        .requestCurrentLocation()

                } label: {

                    if locationManager.isLocating {

                        HStack(spacing: 6) {

                            ProgressView()
                                .controlSize(
                                    .small
                                )

                            Text(
                                "Locating"
                            )
                        }

                    } else {

                        Label(
                            "Near Me",
                            systemImage:
                                "location.fill"
                        )
                    }
                }
                .buttonStyle(
                    .borderedProminent
                )


                Button {

                    refreshNearbyFlights()

                    showNearbySheet =
                        true

                } label: {

                    HStack(spacing: 5) {

                        Image(
                            systemName:
                                "list.bullet"
                        )


                        if !bridge
                            .nearbyFlights
                            .isEmpty {

                            Text(
                                "\(bridge.nearbyFlights.count)"
                            )
                        }
                    }
                }
                .buttonStyle(.bordered)
                .disabled(
                    lastCoordinate == nil
                    || !flightsEnabled
                )


                Button {

                    refreshNearbyFlights()

                } label: {

                    Image(
                        systemName:
                            "arrow.clockwise"
                    )
                }
                .buttonStyle(.bordered)
                .disabled(
                    lastCoordinate == nil
                    || !flightsEnabled
                )


                Spacer()
            }
        }
        .disabled(
            !bridge.isReady
        )
    }


    // MARK: - Nearby Sheet

    private var nearbySheet:
        some View {

        NavigationStack {

            VStack(spacing: 12) {

                radiusPicker


                if filteredNearbyFlights.isEmpty {

                    emptyNearbyView

                } else {

                    List {

                        ForEach(
                            filteredNearbyFlights
                        ) { flight in

                            Button {

                                bridge.trackAircraft(
                                    icao24:
                                        flight.icao24
                                )

                                showNearbySheet =
                                    false

                            } label: {

                                nearbyFlightRow(
                                    flight
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .padding(.top, 4)

            .navigationTitle(
                "Nearby Flights"
            )

            .navigationBarTitleDisplayMode(
                .inline
            )

            .searchable(
                text:
                    $nearbySearch,
                prompt:
                    "Callsign, ICAO or type"
            )

            .toolbar {

                ToolbarItem(
                    placement:
                        .topBarTrailing
                ) {

                    Button {

                        refreshNearbyFlights()

                    } label: {

                        Image(
                            systemName:
                                "arrow.clockwise"
                        )
                    }
                }
            }
        }
    }


    // MARK: - Radius Picker

    private var radiusPicker:
        some View {

        Picker(
            "Radius",
            selection:
                $nearbyRadiusKm
        ) {

            Text("50 km")
                .tag(50.0)

            Text("100 km")
                .tag(100.0)

            Text("250 km")
                .tag(250.0)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)

        .onChange(
            of:
                nearbyRadiusKm
        ) { _, _ in

            refreshNearbyFlights()
        }
    }


    // MARK: - Nearby Row

    private func nearbyFlightRow(
        _ flight:
            NearbyFlight
    ) -> some View {

        HStack(spacing: 12) {

            ZStack {

                Circle()
                    .fill(
                        flight.onGround
                        ? Color.secondary
                            .opacity(0.15)
                        : Color.blue
                            .opacity(0.15)
                    )
                    .frame(
                        width: 40,
                        height: 40
                    )


                Image(
                    systemName:
                        flight.onGround
                        ? "airplane.circle"
                        : "airplane"
                )
                .foregroundStyle(
                    flight.onGround
                    ? Color.secondary
                    : Color.blue
                )
            }


            VStack(
                alignment:
                    .leading,
                spacing: 4
            ) {

                Text(
                    flight.displayName
                )
                .font(
                    .system(
                        size: 15,
                        weight:
                            .semibold,
                        design:
                            .monospaced
                    )
                )


                if flight.onGround {

                    HStack(spacing: 6) {

                        Text("GROUND")
                            .fontWeight(
                                .semibold
                            )


                        if let type =
                            flight.aircraftClass {

                            Text("•")

                            Text(type)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )

                } else {

                    HStack(spacing: 7) {

                        if let altitude =
                            flight.altitudeFeet {

                            Text(
                                "\(altitude.formatted()) ft"
                            )
                        }


                        if let speed =
                            flight.speedKmh {

                            Text(
                                "\(speed) km/h"
                            )
                        }


                        if let heading =
                            flight.heading {

                            Text(
                                "\(heading)°"
                            )
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }
            }


            Spacer()


            VStack(
                alignment:
                    .trailing,
                spacing: 3
            ) {

                Text(
                    String(
                        format:
                            "%.1f km",
                        flight.distanceKm
                    )
                )
                .font(
                    .system(
                        size: 13,
                        weight:
                            .semibold,
                        design:
                            .monospaced
                    )
                )


                if !flight.onGround,
                   let type =
                    flight.aircraftClass {

                    Text(type)
                        .font(
                            .caption2
                        )
                        .foregroundStyle(
                            .secondary
                        )
                }
            }


            Image(
                systemName:
                    "chevron.right"
            )
            .font(.caption)
            .foregroundStyle(
                .tertiary
            )
        }
        .contentShape(
            Rectangle()
        )
        .padding(
            .vertical,
            4
        )
    }


    // MARK: - Empty Nearby

    private var emptyNearbyView:
        some View {

        ContentUnavailableView(
            nearbySearch.isEmpty
            ? "No Nearby Flights"
            : "No Matches",

            systemImage:
                "airplane",

            description:
                Text(
                    nearbySearch.isEmpty
                    ? "No aircraft were found within \(Int(nearbyRadiusKm)) km."
                    : "Try another callsign, ICAO or aircraft type."
                )
        )
    }


    // MARK: - Aircraft Card

    private func aircraftCard(
        _ aircraft:
            AircraftInfo
    ) -> some View {

        VStack(
            alignment:
                .leading,
            spacing: 12
        ) {

            HStack {

                Image(
                    systemName:
                        "airplane"
                )


                VStack(
                    alignment:
                        .leading,
                    spacing: 2
                ) {

                    Text(
                        aircraft.displayName
                    )
                    .font(.headline)


                    if let registration =
                        aircraft.registration {

                        Text(
                            registration
                        )
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                    }
                }


                Spacer()


                if aircraft.stale {

                    Text("STALE")
                        .font(
                            .caption2.bold()
                        )
                        .foregroundStyle(
                            .orange
                        )
                }
            }


            if let route =
                aircraft.routeText {

                Text(route)
                    .font(
                        .system(
                            .body,
                            design:
                                .monospaced
                        )
                    )
            }


            HStack {

                metric(
                    title:
                        "ALT",

                    value:
                        aircraft.onGround
                        ? "GROUND"
                        : aircraft
                            .altitudeFeet
                            .map {
                                "\($0.formatted()) ft"
                            }
                            ?? "--"
                )


                Spacer()


                metric(
                    title:
                        "SPEED",

                    value:
                        aircraft.onGround
                        ? "--"
                        : aircraft
                            .speedKmh
                            .map {
                                "\($0) km/h"
                            }
                            ?? "--"
                )


                Spacer()


                metric(
                    title:
                        "HDG",

                    value:
                        aircraft.onGround
                        ? "--"
                        : aircraft
                            .heading
                            .map {
                                "\($0)°"
                            }
                            ?? "--"
                )
            }


            if let type =
                aircraft.typeName {

                Text(type)
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
            }


            Button {

                bridge.stopTracking()

            } label: {

                Label(
                    "Stop Tracking",
                    systemImage:
                        "xmark.circle.fill"
                )
                .frame(
                    maxWidth:
                        .infinity
                )
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .background(
            .ultraThinMaterial
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18
            )
        )
    }


    // MARK: - Location

    private func goToUserLocation(
        _ coordinate:
            UserCoordinate
    ) {

        bridge.flyTo(
            latitude:
                coordinate.latitude,

            longitude:
                coordinate.longitude,

            altitudeMeters:
                150_000
        )


        if !flightsEnabled {

            flightsEnabled =
                true

            bridge.setLayer(
                id:
                    "flights",

                enabled:
                    true
            )
        }


        scheduleNearbyRefresh(
            openSheet:
                true
        )
    }


    // MARK: - Refresh Nearby

    private func scheduleNearbyRefresh(
        openSheet:
            Bool = false
    ) {

        guard
            lastCoordinate != nil
        else {
            return
        }


        Task {

            try? await Task.sleep(
                for:
                    .seconds(2)
            )


            await MainActor.run {

                refreshNearbyFlights()


                if openSheet {

                    showNearbySheet =
                        true
                }
            }
        }
    }


    private func refreshNearbyFlights() {

        guard
            let coordinate =
                lastCoordinate
        else {
            return
        }


        bridge.requestNearbyFlights(
            latitude:
                coordinate.latitude,

            longitude:
                coordinate.longitude,

            radiusKm:
                nearbyRadiusKm,

            maxCount:
                50
        )
    }


    // MARK: - Location Error

    private func locationErrorCard(
        _ message:
            String
    ) -> some View {

        HStack(spacing: 10) {

            Image(
                systemName:
                    "location.slash.fill"
            )
            .foregroundStyle(
                .orange
            )


            Text(message)
                .font(.caption)


            Spacer()
        }
        .padding(12)
        .background(
            .ultraThinMaterial
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 12
            )
        )
    }


    // MARK: - Metric

    private func metric(
        title: String,
        value: String
    ) -> some View {

        VStack(
            alignment:
                .leading,
            spacing: 3
        ) {

            Text(title)
                .font(
                    .caption2.bold()
                )
                .foregroundStyle(
                    .secondary
                )


            Text(value)
                .font(
                    .system(
                        size: 13,
                        weight:
                            .semibold,
                        design:
                            .monospaced
                    )
                )
        }
    }
}
