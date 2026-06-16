import Charts
import SwiftUI
import TokenMaxxingCore

struct HomeView: View {
    @State private var dashboard = UsageDashboardState()

    private let summaryColumns = [
        GridItem(.adaptive(minimum: 156), spacing: 12, alignment: .top)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
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
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("TokenMaxxing")
        }
        #if os(macOS)
        .frame(minWidth: 760, minHeight: 720)
        #endif
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
                        .foregroundStyle(Color.tokenAccent)

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
                .buttonStyle(.borderedProminent)
                .tint(Color.tokenAccent)
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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.28), lineWidth: 1)
        }
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
                tint: .summaryBlue
            )

            SummaryTile(
                title: dashboard.selectedRange.peakLabel,
                value: dashboard.peakUsage.map { dashboard.formatPeakLabel($0) } ?? "-",
                subtitle: dashboard.peakUsage.map { "\($0.tokens.formatted()) tokens" } ?? "No data",
                systemImage: "flame.fill",
                tint: .summaryRed
            )

            SummaryTile(
                title: "7-Day Average",
                value: dashboard.weekAverageTokens.formatted(),
                subtitle: "tokens per day",
                systemImage: "calendar",
                tint: .summaryGreen
            )

            SummaryTile(
                title: "Active Days",
                value: dashboard.activeDays.formatted(),
                subtitle: "last 30 days",
                systemImage: "arrow.up.right",
                tint: .summaryPurple
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
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

#Preview {
    HomeView()
}

private struct TokenUsageChart: View {
    let range: UsageRange
    let points: [TokenUsagePoint]

    private var maxTokens: Int {
        max(points.map(\.tokens).max() ?? 1, 1)
    }

    var body: some View {
        switch range {
        case .day:
            styledChart(dayChart)
        case .month, .year:
            styledChart(barChart)
        }
    }

    private var dayChart: some View {
        Chart(points) { item in
            AreaMark(
                x: .value("Time", item.date),
                y: .value("Tokens", item.tokens)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.tokenAccent.opacity(0.35), Color.tokenAccent.opacity(0.03)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            LineMark(
                x: .value("Time", item.date),
                y: .value("Tokens", item.tokens)
            )
            .interpolationMethod(.catmullRom)
            .lineStyle(.init(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .foregroundStyle(Color.tokenAccent)
        }
    }

    private var barChart: some View {
        Chart(points) { item in
            BarMark(
                x: .value("Date", item.date),
                y: .value("Tokens", item.tokens)
            )
            .foregroundStyle(Color.tokenAccent.gradient)
            .cornerRadius(4)
        }
    }

    private func styledChart(_ chart: some View) -> some View {
        chart
        .chartYScale(domain: 0...(Double(maxTokens) * 1.18))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: range == .day ? 6 : 5)) { value in
                AxisGridLine()
                    .foregroundStyle(.secondary.opacity(0.22))
                AxisTick()
                    .foregroundStyle(.secondary.opacity(0.35))

                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(axisLabel(for: date))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) {
                AxisGridLine()
                    .foregroundStyle(.secondary.opacity(0.18))
                AxisValueLabel()
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func axisLabel(for date: Date) -> String {
        switch range {
        case .day:
            date.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)))
        case .month:
            date.formatted(.dateTime.day())
        case .year:
            date.formatted(.dateTime.month(.abbreviated))
        }
    }
}

private struct SummaryTile: View {
    let title: String
    let value: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 24, height: 24)
                    .background(tint.opacity(0.16), in: Circle())

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct UsageRow: View {
    let point: TokenUsagePoint

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "circle.hexagongrid.fill")
                .foregroundStyle(Color.tokenAccent)
                .font(.system(size: 20))
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(point.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.subheadline.weight(.semibold))

                Text("Daily token volume")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Text(point.tokens.formatted())
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 11)
    }
}

private extension Color {
    static let appBackground = Color(red: 0.95, green: 0.95, blue: 0.97)
    static let tokenAccent = Color(red: 0.98, green: 0.38, blue: 0.13)
    static let summaryBlue = Color(red: 0.12, green: 0.43, blue: 0.92)
    static let summaryGreen = Color(red: 0.06, green: 0.55, blue: 0.32)
    static let summaryPurple = Color(red: 0.48, green: 0.28, blue: 0.88)
    static let summaryRed = Color(red: 0.88, green: 0.14, blue: 0.21)
}
