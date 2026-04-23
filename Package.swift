// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacSmoothScroll",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "macsmoothscroll", targets: ["MacSmoothScroll"]),
    ],
    targets: [
        .executableTarget(
            name: "MacSmoothScroll",
            exclude: [
                "Resources/Info.plist",
                "Resources/MacSmoothScroll.entitlements",
            ],
            resources: [
                .copy("Resources/mouse.svg"),
            ]
        ),
    ]
)
