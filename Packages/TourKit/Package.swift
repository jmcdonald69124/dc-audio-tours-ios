// swift-tools-version: 6.0
import PackageDescription

// TourKit is the platform-independent core of the app: models that mirror the
// Firestore/bundled content schema, access rules, geofence planning and audio
// file naming. It has no UIKit/SwiftUI/Firebase dependency, so it builds and
// tests on Linux CI as well as in Xcode.
let package = Package(
    name: "TourKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "TourKit", targets: ["TourKit"]),
    ],
    targets: [
        .target(name: "TourKit"),
        .testTarget(name: "TourKitTests", dependencies: ["TourKit"]),
    ]
)
