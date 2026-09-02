import SwiftUI

struct ContentView: View {
    @StateObject private var bridge = CesiumBridge()

    var body: some View {
        ZStack {
            CesiumWebView(
                url: AppConfiguration.webURL,
                bridge: bridge
            )
            .ignoresSafeArea()

            VStack {
                statusBar

                Spacer()

                HStack {
                    Button {
                        bridge.flyTo(
                            latitude: -23.5505,
                            longitude: -46.6333,
                            altitudeMeters: 25_000
                        )
                    } label: {
                        Label(
                            "São Paulo",
                            systemImage: "location.fill"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!bridge.isReady)

                    Spacer()
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 24)
        }
        .background(Color.black)
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(
                    bridge.isReady
                    ? Color.green
                    : Color.orange
                )
                .frame(width: 8, height: 8)

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

            if let message = bridge.lastMessage {
                Text(message)
                    .lineLimit(1)
                    .font(
                        .system(
                            size: 10,
                            design: .monospaced
                        )
                    )
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(.black.opacity(0.70))
        .clipShape(
            RoundedRectangle(cornerRadius: 10)
        )
    }
}
