import Charts
import SwiftUI

struct HomeView: View {
    @State private var dashboard = UsageDashboardState()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            usageChart

            HStack(spacing: 12) {
                Button {
                    dashboard.triggerScan()
                } label: {
                    LiquidGlassButtonLabel(
                        title: "Scan Local Usage",
                        systemImage: "waveform.path.ecg.magnifyingglass",
                        tint: .blue
                    )
                }
                .buttonStyle(.liquidGlass)

                Button {
                    withAnimation(.snappy) {
                        dashboard.toggleChartStyle()
                    }
                } label: {
                    LiquidGlassButtonLabel(
                        title: dashboard.chartStyle.toggleTitle,
                        systemImage: dashboard.chartStyle.toggleIconName,
                        tint: .teal
                    )
                }
                .buttonStyle(.liquidGlass)
            }
        }
        .frame(minWidth: 920, minHeight: 760)
        .padding(32)
        .glassEffect(.regular.tint(.gray.opacity(0.15)).interactive(), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .background()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TokenMaxing")
                .font(.largeTitle)
                .fontWeight(.semibold)

            HStack(spacing: 16) {
                Text(dashboard.message)
                    .font(.title3)

                Text("\(dashboard.totalTokens.formatted()) tokens today")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var usageChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(dashboard.chartStyle.title)
                .font(.headline)

            Chart(dashboard.hourlyUsage) { item in
                if dashboard.chartStyle == .line {
                    LineMark(
                        x: .value("Hour", item.hour),
                        y: .value("Tokens", item.tokens)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.tint)

                    PointMark(
                        x: .value("Hour", item.hour),
                        y: .value("Tokens", item.tokens)
                    )
                    .foregroundStyle(.tint)
                    .symbolSize(24)
                } else {
                    BarMark(
                        x: .value("Hour", item.hour),
                        y: .value("Tokens", item.tokens)
                    )
                    .foregroundStyle(.tint)
                    .cornerRadius(3)
                }
            }
            .chartXScale(domain: 0...23)
            .chartXAxisLabel("Hour")
            .chartYAxisLabel("Tokens")
            .frame(height: 260)
        }
    }
}

#Preview {
    HomeView()
}

private struct LiquidGlassButtonLabel: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)
                .background(.white.opacity(0.22), in: Circle())

            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minWidth: 220, minHeight: 76, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }
}

private struct LiquidGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(.blue.opacity(configuration.isPressed ? 0.06 : 0.23), in: Capsule())
            .glassEffect(.regular.tint(.gray.opacity(0.35)).interactive(), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(.white.opacity(configuration.isPressed ? 0.28 : 0.18), lineWidth: 1)
            }
            .shadow(color: .black.opacity(configuration.isPressed ? 0.10 : 0.16), radius: 18, x: 0, y: 10)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

private extension ButtonStyle where Self == LiquidGlassButtonStyle {
    static var liquidGlass: LiquidGlassButtonStyle {
        LiquidGlassButtonStyle()
    }
}
