// swift-tools-version: 6.2
// Dependency rule lives here: Data and Presentation depend on Domain, never on each other.
// scripts/check-deps.sh re-checks the same rule against import statements.
import PackageDescription

let package = Package(
    name: "TenureKit",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Persistence", targets: ["Persistence"]),
        .library(name: "DriveSync", targets: ["DriveSync"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "BoardFeature", targets: ["BoardFeature"]),
        .library(name: "EntryEditorFeature", targets: ["EntryEditorFeature"]),
        .library(name: "SearchFeature", targets: ["SearchFeature"]),
        .library(name: "SettingsFeature", targets: ["SettingsFeature"]),
    ],
    targets: [
        .target(name: "Domain", dependencies: [], path: "Domain/Sources"),
        .target(name: "Persistence", dependencies: ["Domain"], path: "Data/Persistence/Sources"),
        .target(name: "DriveSync", dependencies: ["Domain"], path: "Data/DriveSync/Sources"),
        .target(name: "DesignSystem", dependencies: [], path: "Presentation/DesignSystem/Sources"),
        .target(
            name: "BoardFeature",
            dependencies: ["Domain", "DesignSystem"],
            path: "Presentation/Features/Board/Sources"
        ),
        .target(
            name: "EntryEditorFeature",
            dependencies: ["Domain", "DesignSystem"],
            path: "Presentation/Features/EntryEditor/Sources"
        ),
        .target(
            name: "SearchFeature",
            dependencies: ["Domain", "DesignSystem"],
            path: "Presentation/Features/Search/Sources"
        ),
        .target(
            name: "SettingsFeature",
            dependencies: ["Domain", "DesignSystem"],
            path: "Presentation/Features/Settings/Sources"
        ),
        .testTarget(name: "DomainTests", dependencies: ["Domain"], path: "Domain/Tests"),
        .testTarget(
            name: "PersistenceTests",
            dependencies: ["Persistence", "Domain"],
            path: "Data/Persistence/Tests"
        ),
        .testTarget(name: "DriveSyncTests", dependencies: ["DriveSync", "Domain"], path: "Data/DriveSync/Tests"),
        .testTarget(
            name: "BoardFeatureTests",
            dependencies: ["BoardFeature", "Domain"],
            path: "Presentation/Features/Board/Tests"
        ),
        .testTarget(
            name: "EntryEditorFeatureTests",
            dependencies: ["EntryEditorFeature", "Domain"],
            path: "Presentation/Features/EntryEditor/Tests"
        ),
        .testTarget(
            name: "SettingsFeatureTests",
            dependencies: ["SettingsFeature", "Domain"],
            path: "Presentation/Features/Settings/Tests"
        ),
        .testTarget(
            name: "IntegrationTests",
            dependencies: ["Domain", "Persistence"],
            path: "IntegrationTests"
        ),
    ]
)
