// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Example",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Example",
            targets: ["Example"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/tu-konnichiwa/FlowStack.git", from: "1.0.3")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Example",
            dependencies: [
                .product(name: "FlowStack", package: "FlowStack")
            ]
        ),
        .testTarget(
            name: "ExampleTests",
            dependencies: [
                .product(name: "FlowStack", package: "FlowStack")
            ]
        ),
    ],
    
    swiftLanguageModes: [.v6]
)
