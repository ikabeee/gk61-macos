import Observation
import ServiceManagement

/// Whether macOS opens GK61 when you log in, so arrow mode is ready without opening it by hand.
/// https://developer.apple.com/documentation/servicemanagement/smappservice
@Observable @MainActor
final class LoginItem {
    private(set) var status: SMAppService.Status = SMAppService.mainApp.status
    private(set) var failure: OperationFailure?

    var opensAtLogin: Bool { status == .enabled }

    /// macOS asks the user to allow it in System Settings › General › Login Items.
    var needsApproval: Bool { status == .requiresApproval }

    func setOpensAtLogin(_ isOn: Bool) {
        do {
            if isOn {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            failure = nil
        } catch {
            failure = .loginItemFailed(error)
        }
        status = SMAppService.mainApp.status
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
