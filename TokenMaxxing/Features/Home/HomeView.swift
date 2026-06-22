import SwiftUI
import TokenMaxxingCore

struct HomeView: View {
    @State private var dashboard = HomeDashboardViewModel()

    private let summaryColumns = [
        GridItem(.adaptive(minimum: 156), spacing: 12, alignment: .top)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                GlassEffectContainer(spacing: 12) {
                    VStack(alignment: .leading, spacing: 18) {
                        overview
                        rangePicker
                        usageCard
                        summaryGrid
                        recentUsage
                    }
                    .frame(maxWidth: 980, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                }
            }
            .background {
                pageBackground
            }
            .navigationTitle("TokenMaxxing")
        }
        #if os(macOS)
            .frame(minWidth: 760, minHeight: 720)
        #endif
    }

    private var pageBackground: some View {
        ZStack {
            HomePalette.appBackground

            LinearGradient(
                colors: [
                    Color.white.opacity(0.56),
                    Color.white.opacity(0.18),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [
                    HomePalette.tokenAccent.opacity(0.045),
                    HomePalette.summaryBlue.opacity(0.035),
                    Color.clear
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        }
        .ignoresSafeArea()
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Token Usage")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.primary)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(dashboard.selectedRange.headline)
                    .font(.title3.weight(.semibold))

                Text(dashboard.status)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var rangePicker: some View {
        Picker("Range", selection: $dashboard.selectedRange) {
            ForEach(UsageRange.allCases) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 420)
    }

    private var usageCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 7) {
                    Label(dashboard.selectedRange.chartTitle, systemImage: "chart.xyaxis.line")
                        .font(.headline)
                        .foregroundStyle(HomePalette.tokenAccent)

                    Text(dashboard.trendDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 10)

                Button {
                    Task {
                        await dashboard.refreshFromCodexLogs()
                    }
                } label: {
                    Label("Scan", systemImage: "arrow.clockwise")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.glassProminent)
                .tint(HomePalette.tokenAccent)
                .controlSize(.regular)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(dashboard.totalTokens.formatted())
                    .font(.system(size: 54, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.72)
                    .lineLimit(1)

                Text(dashboard.selectedRange.totalLabel)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            TokenUsageChart(range: dashboard.selectedRange, points: dashboard.visibleUsage)
                .frame(height: 280)
        }
        .padding(20)
        .glassEffect(
            .regular.interactive(),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .task {
            await dashboard.refreshFromCodexLogs()
        }
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: summaryColumns, spacing: 12) {
            SummaryTile(
                title: dashboard.selectedRange.averageLabel,
                value: dashboard.averageTokens.formatted(),
                subtitle: "tokens",
                systemImage: "waveform.path.ecg",
                tint: HomePalette.summaryBlue
            )

            SummaryTile(
                title: dashboard.selectedRange.peakLabel,
                value: dashboard.peakUsage.map { dashboard.formatPeakLabel($0) } ?? "-",
                subtitle: dashboard.peakUsage.map { "\($0.tokens.formatted()) tokens" }
                    ?? "No data",
                systemImage: "flame.fill",
                tint: HomePalette.summaryRed
            )

            SummaryTile(
                title: "7-Day Average",
                value: dashboard.weekAverageTokens.formatted(),
                subtitle: "tokens per day",
                systemImage: "calendar",
                tint: HomePalette.summaryGreen
            )

            SummaryTile(
                title: "Active Days",
                value: dashboard.activeDays.formatted(),
                subtitle: "last 30 days",
                systemImage: "arrow.up.right",
                tint: HomePalette.summaryPurple
            )
        }
    }

    private var recentUsage: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recent Volume")
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(dashboard.dailyUsage.suffix(7).reversed()) { item in
                    UsageRow(point: item)

                    if item.id != dashboard.dailyUsage.suffix(7).first?.id {
                        Divider()
                            .padding(.leading, 42)
                    }
                }
            }
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

#Preview {
    HomeView()
}
