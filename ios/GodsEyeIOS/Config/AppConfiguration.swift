import Foundation

enum AppConfiguration {
    /// Simulator default: http://localhost:4173
    ///
    /// For a physical iPhone launched from Xcode, set the Run scheme environment variable:
    /// GEV_DEV_SERVER_URL=http://YOUR_MAC_LAN_IP:4173
    static var webURL: URL {
        let environment = ProcessInfo.processInfo.environment
        let rawValue = environment["GEV_DEV_SERVER_URL"] ?? "http://localhost:4173"

        guard let url = URL(string: rawValue) else {
            preconditionFailure("Invalid GEV_DEV_SERVER_URL: \(rawValue)")
        }

        return url
    }
}
