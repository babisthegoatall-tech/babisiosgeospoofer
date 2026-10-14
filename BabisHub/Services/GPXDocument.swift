import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct GPXDocument: FileDocument {
    static let contentType = UTType(filenameExtension: "gpx", conformingTo: .xml) ?? .xml
    static var readableContentTypes: [UTType] { [contentType] }
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }

    static func make(from route: SavedRoute) -> GPXDocument {
        let points = route.waypoints.map {
            "    <rtept lat=\"\($0.latitude)\" lon=\"\($0.longitude)\"><name>\(xmlEscaped($0.name))</name></rtept>"
        }.joined(separator: "\n")
        let gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Babis Hub" xmlns="http://www.topografix.com/GPX/1/1">
          <rte>
            <name>\(xmlEscaped(route.name))</name>
        \(points)
          </rte>
        </gpx>
        """
        return GPXDocument(data: Data(gpx.utf8))
    }

    private static func xmlEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

enum GPXParser {
    static func parse(_ data: Data, name: String) throws -> SavedRoute {
        let parserDelegate = GPXParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = parserDelegate
        guard parser.parse() else {
            throw parser.parserError ?? CocoaError(.fileReadCorruptFile)
        }
        let points = parserDelegate.waypoints
        guard points.count >= 2 else {
            throw NSError(
                domain: "BabisHub.GPX",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "The GPX file must contain at least two valid route or track points."]
            )
        }
        return SavedRoute(name: parserDelegate.routeName.isEmpty ? name : parserDelegate.routeName, waypoints: points)
    }
}

private final class GPXParserDelegate: NSObject, XMLParserDelegate {
    private(set) var waypoints: [Place] = []
    private(set) var routeName = ""
    private var currentPointName = ""
    private var isReadingRouteName = false
    private var isReadingPointName = false
    private var currentPointIndex: Int?

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let element = elementName.lowercased()
        if element == "name" {
            if currentPointIndex == nil && routeName.isEmpty {
                isReadingRouteName = true
            } else if currentPointIndex != nil {
                isReadingPointName = true
                currentPointName = ""
            }
            return
        }
        guard ["rtept", "trkpt", "wpt"].contains(element),
              let latitude = Double(attributeDict["lat"] ?? ""),
              let longitude = Double(attributeDict["lon"] ?? "") else { return }
        let point = Place(name: "Waypoint \(waypoints.count + 1)", latitude: latitude, longitude: longitude)
        guard point.isValidCoordinate else { return }
        waypoints.append(point)
        currentPointIndex = waypoints.count - 1
        currentPointName = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isReadingRouteName {
            routeName += string
        } else if isReadingPointName {
            currentPointName += string
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let element = elementName.lowercased()
        if element == "name", isReadingRouteName {
            isReadingRouteName = false
        } else if element == "name", isReadingPointName {
            isReadingPointName = false
        } else if ["rtept", "trkpt", "wpt"].contains(element), !waypoints.isEmpty {
            let name = currentPointName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty, let currentPointIndex {
                waypoints[currentPointIndex].name = name
            }
            currentPointName = ""
            currentPointIndex = nil
        }
    }
}
