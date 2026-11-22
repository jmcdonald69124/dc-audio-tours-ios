import Foundation

public struct Coordinate: Codable, Hashable, Sendable {
    public var lat: Double
    public var lon: Double

    public init(lat: Double, lon: Double) { self.lat = lat; self.lon = lon }

    private static let earthRadiusMeters = 6_371_008.8

    /// Great-circle distance in meters (haversine).
    public func distance(to other: Coordinate) -> Double {
        let p1 = lat * .pi / 180, p2 = other.lat * .pi / 180
        let dp = (other.lat - lat) * .pi / 180
        let dl = (other.lon - lon) * .pi / 180
        let a = sin(dp / 2) * sin(dp / 2) + cos(p1) * cos(p2) * sin(dl / 2) * sin(dl / 2)
        return 2 * Self.earthRadiusMeters * atan2(sqrt(a), sqrt(1 - a))
    }

    /// Initial compass bearing to `other`, in degrees `0 ..< 360` (0 = north).
    public func bearing(to other: Coordinate) -> Double {
        let p1 = lat * .pi / 180, p2 = other.lat * .pi / 180
        let dl = (other.lon - lon) * .pi / 180
        let y = sin(dl) * cos(p2)
        let x = cos(p1) * sin(p2) - sin(p1) * cos(p2) * cos(dl)
        let degrees = atan2(y, x) * 180 / .pi
        return (degrees + 360).truncatingRemainder(dividingBy: 360)
    }

    private static let base32 = Array("0123456789bcdefghjkmnpqrstuvwxyz")

    /// Geohash string (default ~5 m cells). Stored on Firestore documents for "near me" range queries.
    public func geohash(precision: Int = 9) -> String {
        var latRange = (-90.0, 90.0), lonRange = (-180.0, 180.0)
        var result = "", bits = 0, ch = 0, evenBit = true
        while result.count < precision {
            if evenBit {
                let mid = (lonRange.0 + lonRange.1) / 2
                if lon >= mid { ch = ch << 1 | 1; lonRange.0 = mid } else { ch <<= 1; lonRange.1 = mid }
            } else {
                let mid = (latRange.0 + latRange.1) / 2
                if lat >= mid { ch = ch << 1 | 1; latRange.0 = mid } else { ch <<= 1; latRange.1 = mid }
            }
            evenBit.toggle()
            bits += 1
            if bits == 5 { result.append(Self.base32[ch]); bits = 0; ch = 0 }
        }
        return result
    }
}

public extension Collection where Element == Coordinate {
    /// Axis-aligned bounds of the coordinates, or nil when empty.
    var bounds: (southWest: Coordinate, northEast: Coordinate)? {
        guard let first else { return nil }
        var minLat = first.lat, maxLat = first.lat, minLon = first.lon, maxLon = first.lon
        for c in self {
            minLat = Swift.min(minLat, c.lat); maxLat = Swift.max(maxLat, c.lat)
            minLon = Swift.min(minLon, c.lon); maxLon = Swift.max(maxLon, c.lon)
        }
        return (Coordinate(lat: minLat, lon: minLon), Coordinate(lat: maxLat, lon: maxLon))
    }
}
