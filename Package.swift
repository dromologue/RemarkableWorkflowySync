// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "RemarkableWorkflowySync",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "RemarkableWorkflowySync",
            targets: ["RemarkableWorkflowySync"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0"),
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", from: "4.0.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "RemarkableWorkflowySync",
            dependencies: [
                "Alamofire",
                "SwiftyJSON",
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-disable-availability-checking"]),
                .unsafeFlags(["-Xfrontend", "-warn-concurrency"]),
            ]
        ),
        .testTarget(
            name: "RemarkableWorkflowySyncTests",
            dependencies: ["RemarkableWorkflowySync"]
        ),
    ]
)
