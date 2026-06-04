import Observation

@Observable
final class ScanStatus {
    var message = "Hello, TokenMaxing"

    func triggerScan() {
        message = "Scan triggered"
    }
}
