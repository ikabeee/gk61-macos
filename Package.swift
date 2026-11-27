// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "GK61",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "GK61", targets: ["GK61App"]),
        .executable(name: "gk61-probe", targets: ["gk61-probe"]),
    ],
    targets: [
        .target(name: "GK61Core"),
        .target(name: "GK61HID", dependencies: ["GK61Core"]),
        .executableTarget(name: "gk61-probe", dependencies: ["GK61Core", "GK61HID"]),
        .executableTarget(name: "GK61App", dependencies: ["GK61Core", "GK61HID"]),
        .testTarget(name: "GK61CoreTests", dependencies: ["GK61Core"]),
    ]
)
