import SwiftUI
import TokenMaxxingCore

struct UsageRow: View {
    let point: TokenUsagePoint

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "circle.hexagongrid.fill")
                .foregroundStyle(HomePalette.tokenAccent)
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
