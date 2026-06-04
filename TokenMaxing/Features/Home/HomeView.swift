import SwiftUI

struct HomeView: View {
    @State private var scanStatus = ScanStatus()

    var body: some View {
        VStack(spacing: 16) {
            Text("TokenMaxing")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text(scanStatus.message)
                .font(.title3)

            Button("Scan Local Usage") {
                scanStatus.triggerScan()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(minWidth: 420, minHeight: 260)
        .padding(32)
    }
}

#Preview {
    HomeView()
}
