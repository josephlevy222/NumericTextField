// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NumericTextField",
    platforms: [.macOS(.v11), .iOS("17.0")],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "NumericTextField",
            targets: ["NumericTextField"]),
    ],
	dependencies: [ .package(url: repo("Utilities"), branch: "main"), ],
    
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "NumericTextField",
            dependencies: ["Utilities"]),
    ]
)

fileprivate func repo(_ repo: String) -> String {
	return "https://github.com/josephlevy222/" + repo + ".git"
}
