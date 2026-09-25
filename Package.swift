// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WeekPact",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "WeekPactCore", targets: ["WeekPactCore"]),
        .library(name: "WeekPactFilterPrototype", targets: ["WeekPactFilterPrototype"]),
        .executable(name: "WeekPactApp", targets: ["WeekPactApp"])
    ],
    targets: [
        .target(name: "WeekPactCore"),
        .target(name: "WeekPactFilterPrototype", dependencies: ["WeekPactCore"]),
        .executableTarget(name: "WeekPactApp", dependencies: ["WeekPactCore"]),
        .testTarget(name: "WeekPactCoreTests", dependencies: ["WeekPactCore"])
    ]
)
