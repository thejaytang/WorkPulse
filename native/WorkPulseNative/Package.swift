// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "WorkPulseNative",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "WorkPulseCore", targets: ["WorkPulseCore"]),
        .executable(name: "WorkPulseMenuBar", targets: ["WorkPulseMenuBar"]),
        .executable(name: "WorkPulseWidgetCompile", targets: ["WorkPulseWidgetCompile"]),
        .executable(name: "WorkPulseCoreVerify", targets: ["WorkPulseCoreVerify"]),
        .executable(name: "WorkPulseAppServerProbe", targets: ["WorkPulseAppServerProbe"])
    ],
    targets: [
        .target(
            name: "WorkPulseCore",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .executableTarget(
            name: "WorkPulseMenuBar",
            dependencies: ["WorkPulseCore"]
        ),
        .executableTarget(
            name: "WorkPulseWidgetCompile",
            dependencies: ["WorkPulseCore"],
            path: "WidgetExtension"
        ),
        .executableTarget(
            name: "WorkPulseCoreVerify",
            dependencies: ["WorkPulseCore"]
        ),
        .executableTarget(
            name: "WorkPulseAppServerProbe",
            dependencies: ["WorkPulseCore"]
        )
    ]
)
