// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SongBattle",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "SongBattle",
            targets: ["SongBattle"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SongBattle",
            dependencies: ["SpotifyiOS"],
            path: "Sources/SongBattle"),
        .binaryTarget(
            name: "SpotifyiOS",
            path: "SpotifyiOS.xcframework")
    ]
) 