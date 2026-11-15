// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RemotePilot",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "OpenNodeDesk", targets: ["RemotePilot"])
    ],
    dependencies: [
        // SSH 会话的内嵌终端：复用成熟终端实现，避免自造 ANSI 解析
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.99.0")
    ],
    targets: [
        .executableTarget(
            name: "RemotePilot",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ],
            path: "Sources/RemotePilot",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
