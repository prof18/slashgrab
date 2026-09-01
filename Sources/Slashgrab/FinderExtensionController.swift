import FinderSync

@MainActor
protocol FinderExtensionManaging {
    var isEnabled: Bool { get }
    func showManagementInterface()
}

@MainActor
struct FinderExtensionController: FinderExtensionManaging {
    var isEnabled: Bool {
        FIFinderSyncController.isExtensionEnabled
    }

    func showManagementInterface() {
        FIFinderSyncController.showExtensionManagementInterface()
    }
}
