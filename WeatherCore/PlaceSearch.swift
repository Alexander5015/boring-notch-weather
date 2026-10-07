import Foundation

public struct Place: Identifiable, Hashable, Sendable, Codable {
    public let name: String
    public let country: String?
    public let latitude: Double
    public let longitude: Double

    public var id: String { "\(latitude),\(longitude)" }

    public init(name: String, country: String?, latitude: Double, longitude: Double) {
        self.name = name
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
    }

    public var subtitle: String? {
        guard let country, !country.isEmpty else { return nil }
        return country
    }
}

public enum PlaceSearch {

    public enum SearchError: Error, LocalizedError {
        case badStatus(Int)

        public var errorDescription: String? {
            switch self {
            case .badStatus(let code): "The place search answered HTTP \(code)."
            }
        }
    }


    private static func url(for query: String) -> URL? {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")
        components?.queryItems = [
            .init(name: "name", value: query),
            .init(name: "count", value: "8"),
            .init(name: "language", value: "en"),
            .init(name: "format", value: "json")
        ]
        return components?.url
    }

    public static func search(
        _ query: String,
        session: URLSession = .shared
    ) async throws -> [Place] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2, let url = url(for: trimmed) else { return [] }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw SearchError.badStatus(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return (decoded.results ?? []).map {
            Place(
                name: $0.name,
                country: $0.country,
                latitude: $0.latitude,
                longitude: $0.longitude
            )
        }
    }

    private struct Response: Decodable {
        struct Result: Decodable {
            let name: String
            let country: String?
            let latitude: Double
            let longitude: Double
        }
        let results: [Result]?
    }
}
