// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WeekPact",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "WeekPactCore", targets: ["WeekPactCore"]),
        .executable(name: "WeekPactApp", targets: ["WeekPactApp"])
    ],
    targets: [
        .target(name: "WeekPactCore"),
        .executableTarget(name: "WeekPactApp", dependencies: ["WeekPactCore"]),
        .testTarget(name: "WeekPactCoreTests", dependencies: ["WeekPactCore"])
    ]
)
