// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "SpatialReviewCore", platforms: [.macOS("27.0")], products: [.library(name: "SpatialReviewCore", targets: ["SpatialReviewCore"])], targets: [.target(name: "SpatialReviewCore", path: "Sources/Core"), .testTarget(name: "ReviewTests", dependencies: ["SpatialReviewCore"], path: "Tests/Core")])
