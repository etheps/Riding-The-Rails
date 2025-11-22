import SwiftUI
import Foundation
import CoreLocation

struct TransitSystem: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var name: String
    // Hex color string for representative color (e.g., "#FF0000")
    var colorHex: String
}

struct City: Identifiable {
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

extension City: Codable {
    private enum CodingKeys: String, CodingKey { case id, name, country, coordinate, systems, visitedSystemIDs }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        country = try container.decode(String.self, forKey: .country)
        let coordPair = try container.decode([Double].self, forKey: .coordinate)
        coordinate = CLLocationCoordinate2D(latitude: coordPair[0], longitude: coordPair[1])
        systems = try container.decode([TransitSystem].self, forKey: .systems)
        visitedSystemIDs = try container.decodeIfPresent(Set<UUID>.self, forKey: .visitedSystemIDs) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(country, forKey: .country)
        try container.encode([coordinate.latitude, coordinate.longitude], forKey: .coordinate)
        try container.encode(systems, forKey: .systems)
        try container.encode(visitedSystemIDs, forKey: .visitedSystemIDs)
    }
}

extension City: Equatable {
    static func == (lhs: City, rhs: City) -> Bool {
        lhs.id == rhs.id
    }
}

extension City: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(country)
        hasher.combine(coordinate.latitude)
        hasher.combine(coordinate.longitude)
        hasher.combine(systems)
        hasher.combine(visitedSystemIDs)
    }
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

// MARK: - Store
@Observable
final class MetroStore {
    private let visitedDefaultsKey = "VisitedSystemIDsByCity"

    var cities: [City]

    init() {
        // Load cities from bundled JSON
        self.cities = Self.loadCitiesFromBundle() ?? []
        // Apply persisted visited states from UserDefaults
        applyPersistedVisits()
    }

    func toggleVisit(cityID: City.ID, systemID: TransitSystem.ID) {
        guard let idx = cities.firstIndex(where: { $0.id == cityID }) else { return }
        if cities[idx].visitedSystemIDs.contains(systemID) {
            cities[idx].visitedSystemIDs.remove(systemID)
        } else {
            cities[idx].visitedSystemIDs.insert(systemID)
        }
        persistVisits()
    }

    // MARK: - Persistence
    private func persistVisits() {
        // Store a dictionary of city.id -> array of system UUID strings
        let dict: [String: [String]] = Dictionary(uniqueKeysWithValues: cities.map { city in
            let arr = city.visitedSystemIDs.map { $0.uuidString }
            return (city.id.uuidString, arr)
        })
        UserDefaults.standard.set(dict, forKey: visitedDefaultsKey)
    }

    private func applyPersistedVisits() {
        guard let dict = UserDefaults.standard.dictionary(forKey: visitedDefaultsKey) as? [String: [String]] else { return }
        for i in cities.indices {
            let key = cities[i].id.uuidString
            if let arr = dict[key] {
                cities[i].visitedSystemIDs = Set(arr.compactMap(UUID.init(uuidString:)))
            }
        }
    }

    // MARK: - Loading
    private static func loadCitiesFromBundle() -> [City]? {
        guard let url = Bundle.main.url(forResource: "Cities", withExtension: "json") else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode([City].self, from: data)
        } catch {
            print("Failed to load Cities.json: \(error)")
            return nil
        }
    }
}
