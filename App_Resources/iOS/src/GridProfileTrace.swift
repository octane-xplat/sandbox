import Foundation
import os.signpost

@objc(GridProfileTrace)
final class GridProfileTrace: NSObject {
    private static let log = OSLog(subsystem: "org.octanexplat.sandbox", category: .pointsOfInterest)

    @objc static func begin() {
        os_signpost(.begin, log: log, name: "GridProfile")
    }

    @objc static func end() {
        os_signpost(.end, log: log, name: "GridProfile")
    }
}
