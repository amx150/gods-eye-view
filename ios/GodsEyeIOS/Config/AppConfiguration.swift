import Foundation

enum AppConfiguration {
    static var webURL: URL {
        let environment = ProcessInfo.processInfo.environment

        let rawValue =
            environment["GEV_DEV_SERVER_URL"]
            ?? "http://localhost:4173"

        guard var components = URLComponents(string: rawValue) else {
            preconditionFailure(
                "Invalid GEV_DEV_SERVER_URL: \(rawValue)"
            )
        }

        var queryItems = components.queryItems ?? []

        if !queryItems.contains(where: { $0.name == "welcome" }) {
            queryItems.append(
                URLQueryItem(
                    name: "welcome",
                    value: "0"
                )
            )
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            preconditionFailure(
                "Unable to create web URL"
            )
        }

        return url
    }
}
