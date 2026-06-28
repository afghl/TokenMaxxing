import SwiftUI

struct AppShellView: View {
    @State private var selection: AppSection? = .home

    var body: some View {
        NavigationSplitView {
            Sidebar(selection: $selection)
                .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 280)
        } detail: {
            switch selection ?? .home {
            case .home:
                HomeView()
            }
        }
        #if os(macOS)
            .frame(minWidth: 780, minHeight: 500)
        #endif
    }
}

private enum AppSection: String, CaseIterable, Identifiable {
    case home

    var id: Self { self }

    var title: String {
        switch self {
        case .home:
            "Home"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            "chart.bar.xaxis"
        }
    }
}

private struct Sidebar: View {
    @Binding var selection: AppSection?

    var body: some View {
        List(selection: $selection) {
            ForEach(AppSection.allCases) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("TokenMaxxing")
    }
}

#Preview {
    AppShellView()
}
