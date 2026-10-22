// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "PartsCore", products: [.library(name: "PartsCore", targets: ["PartsCore"])], targets: [.target(name: "PartsCore", path: "Parts/Core"), .testTarget(name: "PartsCoreTests", dependencies: ["PartsCore"], path: "Tests/PartsCoreTests")])
