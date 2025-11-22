import SwiftUI
import Foundation
import CoreLocation

struct TransitSystem: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var name: String
    // Hex color string for representative color (e.g., "#FF0000")
    var colorHex: String
}

struct City: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var name: String
    var country: String
    var coordinate: CLLocationCoordinate2D
    var systems: [TransitSystem]
    // Track visited systems by id
    var visitedSystemIDs: Set<UUID> = []
}

extension City {
    var anyVisited: Bool { !visitedSystemIDs.isEmpty }
}

// MARK: - Helpers
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&int) else { return nil }
        let a, r, g, b: UInt64
        switch hexSanitized.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

extension CLLocationCoordinate2D: Codable, Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(latitude)
        hasher.combine(longitude)
    }
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let pair = try container.decode([Double].self)
        self.init(latitude: pair[0], longitude: pair[1])
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode([latitude, longitude])
    }
}

// MARK: - Store
@Observable
final class MetroStore {
    var cities: [City]
    init(cities: [City] = SampleData.cities) { self.cities = cities }

    func toggleVisit(cityID: City.ID, systemID: TransitSystem.ID) {
        guard let idx = cities.firstIndex(where: { $0.id == cityID }) else { return }
        if cities[idx].visitedSystemIDs.contains(systemID) {
            cities[idx].visitedSystemIDs.remove(systemID)
        } else {
            cities[idx].visitedSystemIDs.insert(systemID)
        }
    }
}

// MARK: - Sample Data
enum SampleData {
    static let cities: [City] = {
        let nyc = City(
            name: "New York City",
            country: "USA",
            coordinate: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
            systems: [
                TransitSystem(name: "NYC Subway", colorHex: "#0039A6"),
                TransitSystem(name: "PATH", colorHex: "#6CACE4")
            ]
        )
        let london = City(
            name: "London",
            country: "UK",
            coordinate: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
            systems: [
                TransitSystem(name: "London Underground", colorHex: "#000000"),
                TransitSystem(name: "DLR", colorHex: "#00AFAD")
            ]
        )
        return [nyc, london]
    }()
}
