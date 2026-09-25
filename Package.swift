// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WeekPact",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "WeekPactCore", targets: ["WeekPactCore"]),
        .library(name: "WeekPactFilterPrototype", targets: ["WeekPactFilterPrototype"]),
        .executable(name: "WeekPactApp", targets: ["WeekPactApp"]),
        .executable(name: "WeekPactTrialAgent", targets: ["WeekPactTrialAgent"])
    ],
    targets: [
        .target(name: "WeekPactCore"),
        .target(name: "WeekPactFilterPrototype", dependencies: ["WeekPactCore"]),
        .executableTarget(name: "WeekPactApp", dependencies: ["WeekPactCore"]),
        .executableTarget(name: "WeekPactTrialAgent", dependencies: ["WeekPactCore"]),
        .testTarget(name: "WeekPactCoreTests", dependencies: ["WeekPactCore"])
    ]
)
