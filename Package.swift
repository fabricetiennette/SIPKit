// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "SIPKit",
    platforms: [
        .macOS(.v11),
        .iOS(.v14)
    ],
    products: [
        .library(name: "SIPKit", targets: ["SIPKit"]),
    ],
    targets: [
        .binaryTarget(name: "libpjproject", url: "https://github.com/fabricetiennette/pjLib/releases/download/v0.1.1/libpjproject.xcframework.zip", checksum: "2c069c04d447db1fd4ed4bc4eddf1337b648c47fffd2eb6f788cd46e410b7f24"),
        .target(name: "Manager", dependencies: ["libpjproject"], cxxSettings: [
                    .define("PJ_AUTOCONF")
                ], linkerSettings: [
                    .linkedFramework("Network"),
                    .linkedFramework("Security"),
                    .linkedFramework("CoreAudio"),
                    .linkedFramework("AVFoundation"),
                    .linkedFramework("AudioToolbox")
                ]),
        .target(name: "SIPKit", dependencies: ["Manager"], cxxSettings: [
            .define("PJ_AUTOCONF")
        ]),
        .testTarget(
            name: "SIPKitTests",
            dependencies: ["SIPKit"], cxxSettings: [
                .define("PJ_AUTOCONF")
            ]),
    ],
    cxxLanguageStandard: .cxx20
)
