import SwiftUI
import UniformTypeIdentifiers

struct LibraryScreen: View {
    @ObservedObject var viewModel: HubViewModel
    @State private var showingImporter = false
    @State private var routeToExport: SavedRoute?
    @State private var exportDocument: GPXDocument?
    @State private var showingExporter = false
    @State private var exportName = "BabisHub-Route"

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Favorite locations")) {
                    if viewModel.favorites.isEmpty {
                        Text("Save a location from the Map tab to see it here.")
                            .foregroundColor(.secondary)
                    }
                    ForEach(viewModel.favorites) { favorite in
                        HStack {
                            Button {
                                viewModel.selectFavorite(favorite)
                            } label: {
                                PlaceRow(place: favorite)
                            }.foregroundColor(.primary)
                            Spacer()
                            Button(role: .destructive) {
                                viewModel.deleteFavorite(favorite)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Delete \(favorite.name)")
                        }
                    }
                }

                Section(header: Text("Routes")) {
                    if viewModel.routes.isEmpty {
                        Text("Add at least two waypoints on the Map tab to create a route.")
                            .foregroundColor(.secondary)
                    }
                    ForEach(viewModel.routes) { route in
                        VStack(alignment: .leading, spacing: 8) {
                            Button {
                                viewModel.selectRoute(route)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(route.name).font(.headline).foregroundColor(.primary)
                                    Text("\(route.waypoints.count) waypoints")
                                        .font(.caption).foregroundColor(.secondary)
                                }
                            }
                            HStack {
                                Button("Simulate") { viewModel.startSimulation(for: route) }
                                    .buttonStyle(.borderless)
                                Button("Export GPX") { prepareExport(route) }
                                    .buttonStyle(.borderless)
                                Spacer()
                                Button(role: .destructive) {
                                    viewModel.deleteRoute(route)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Delete \(route.name)")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingImporter = true
                    } label: {
                        Label("Import GPX", systemImage: "square.and.arrow.down")
                    }
                }
            }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [GPXDocument.contentType], allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first { viewModel.importRoute(from: url) }
                case .failure(let error):
                    viewModel.errorMessage = "Could not open file: \(error.localizedDescription)"
                }
            }
            .fileExporter(
                isPresented: $showingExporter,
                document: exportDocument,
                contentType: GPXDocument.contentType,
                defaultFilename: exportName
            ) { result in
                if case .failure(let error) = result {
                    viewModel.errorMessage = "Could not export GPX: \(error.localizedDescription)"
                }
            }
        }
    }

    private func prepareExport(_ route: SavedRoute) {
        exportName = route.name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        exportDocument = GPXDocument.make(from: route)
        showingExporter = true
    }
}

private struct PlaceRow: View {
    let place: Place

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(place.name).font(.headline)
            Text(String(format: "%.5f, %.5f", place.latitude, place.longitude))
                .font(.caption).foregroundColor(.secondary)
        }
    }
}
