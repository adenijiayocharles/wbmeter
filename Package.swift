// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WBMeterCore",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "WBMeterCore", targets: ["WBMeterCore"])
    ],
    targets: [
        .target(
            name: "WBMeterCore",
            path: "wbmeter",
            exclude: [
                "Assets.xcassets",
                "CameraPreview.swift",
                "CameraService.swift",
                "CameraSessionController.swift",
                "ContentView.swift",
                "Info.plist",
                "MyApp.swift",
                "RawPhotoCapture.swift"
            ],
            sources: ["SensorROIAnalyzer.swift"]
        ),
        .testTarget(
            name: "WBMeterCoreTests",
            dependencies: ["WBMeterCore"],
            path: "Tests/WBMeterCoreTests"
        )
    ]
)
