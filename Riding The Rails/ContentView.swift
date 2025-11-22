import SwiftUI
import MapKit
import AppKit

struct ContentView: View {
    @State private var store = MetroStore()
    @State private var searchText: String = ""
    @State private var cameraPosition: MapCameraPosition = .automatic

    var filteredCities: [City] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return store.cities
        }
        let q = searchText.lowercased()
        return store.cities.filter { city in
            if city.name.lowercased().contains(q) || city.country.lowercased().contains(q) { return true }
            return city.systems.contains { $0.name.lowercased().contains(q) }
        }
    }

    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            CityListView(store: $store, searchText: $searchText)
                .frame(minWidth: 240)
        } detail: {
            Map(position: $cameraPosition, interactionModes: [.all]) {
                ForEach(filteredCities) { city in
                    let colors: [Color] = city.systems.map { sys in
                        if city.visitedSystemIDs.contains(sys.id) {
                            return Color(hex: sys.colorHex) ?? .accentColor
                        } else {
                            return .gray.opacity(0.6)
                        }
                    }
                    Annotation(city.name, coordinate: city.coordinate) {
                        PieMarker(colors: colors)
                            .onTapGesture {
                                withAnimation(.easeInOut) {
                                    cameraPosition = .region(MKCoordinateRegion(center: city.coordinate, span: MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8)))
                                }
                            }
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat))
            .ignoresSafeArea(edges: .top)
        }
        .searchable(text: $searchText, placement: .automatic, prompt: Text("Search cities or systems"))
        #else
        VStack(spacing: 0) {
            Map(position: $cameraPosition, interactionModes: [.all]) {
                ForEach(store.cities) { city in
                    let colors: [Color] = city.systems.map { sys in
                        if city.visitedSystemIDs.contains(sys.id) {
                            return Color(hex: sys.colorHex) ?? .accentColor
                        } else {
                            return .gray.opacity(0.6)
                        }
                    }
                    Annotation(city.name, coordinate: city.coordinate) {
                        PieMarker(colors: colors)
                            .onTapGesture {
                                // Zoom toward the city when tapped
                                withAnimation(.easeInOut) {
                                    cameraPosition = .region(MKCoordinateRegion(center: city.coordinate, span: MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8)))
                                }
                            }
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .ignoresSafeArea(edges: .top)
            .frame(maxWidth: .infinity)
            .frame(height: 320)

            Divider()

            CityListView(store: $store, searchText: $searchText)
        }
        .searchable(text: $searchText, placement: .automatic, prompt: Text("Search cities or systems"))
        #endif
    }
}

struct CityListView: View {
    @Binding var store: MetroStore
    @Binding var searchText: String

    var filteredCities: [City] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return store.cities }
        let q = searchText.lowercased()
        return store.cities.filter { city in
            if city.name.lowercased().contains(q) || city.country.lowercased().contains(q) { return true }
            return city.systems.contains { $0.name.lowercased().contains(q) }
        }
    }

    var body: some View {
        List {
            ForEach(filteredCities) { city in
                Section(header: HStack {
                    Text(city.name)
                    Spacer()
                    Text(city.country).foregroundStyle(.secondary)
                }) {
                    ForEach(city.systems) { system in
                        HStack(spacing: 12) {
                            PieMarker(colors: city.systems.map { s in
                                let visited = city.visitedSystemIDs.contains(s.id)
                                return visited ? (Color(hex: s.colorHex) ?? .accentColor) : .gray.opacity(0.6)
                            })
                            .frame(width: 18, height: 18)

                            VStack(alignment: .leading) {
                                Text(system.name)
                                    .font(.body)
                                Text(city.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("Visited", isOn: Binding(
                                get: { city.visitedSystemIDs.contains(system.id) },
                                set: { _ in store.toggleVisit(cityID: city.id, systemID: system.id) }
                            ))
                            .labelsHidden()
                        }
                    }
                }
            }
        }
#if os(iOS)
        .listStyle(.insetGrouped)
#else
        .listStyle(.inset)
#endif
    }
}

struct PieMarker: View {
    var colors: [Color]

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let rect = CGRect(x: (geo.size.width - size)/2, y: (geo.size.height - size)/2, width: size, height: size)
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                PieSlices(colors: colors)
            }
            .frame(width: rect.width, height: rect.height)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.secondary.opacity(0.4), lineWidth: 1))
        }
        .frame(width: 24, height: 24)
    }
}

struct PieSlices: View {
    var colors: [Color]
    var body: some View {
        Canvas { context, size in
            guard !colors.isEmpty else { return }
            let center = CGPoint(x: size.width/2, y: size.height/2)
            let radius = min(size.width, size.height) / 2
            let anglePer = Angle.degrees(360.0 / Double(colors.count))
            var start = Angle.degrees(-90)
            for color in colors {
                let end = start + anglePer
                var path = Path()
                path.move(to: center)
                path.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
                path.closeSubpath()
                context.fill(path, with: .color(color))
                start = end
            }
        }
    }
}

#Preview {
    ContentView()
}
