import SwiftUI

/// An intentionally small custom chart; disconnected segments expose pauses.
struct HistoryChart: View {
    let history: MetricHistory
    let window: HistoryWindow
    var color: Color
    var fixedMax: Double? = nil
    var now = Date()
    var valueLabel: (Double) -> String = { String(format: "%.1f", $0) }
    var minimumLabel = "0"

    private var visible: [HistoryPoint] { history.visible(in: window, now: now) }
    private var scale: Double { max(fixedMax ?? history.maximum(in: window, now: now), 0.0001) }
    private var summary: String {
        let samples = visible
        guard let last = samples.last, let minimum = samples.map(\.value).min(),
              let maximum = samples.map(\.value).max() else { return "No samples in the last \(window.label)." }
        let trend: String
        if let first = samples.first, samples.count > 1 {
            trend = last.value > first.value ? "rising" : last.value < first.value ? "falling" : "steady"
        } else { trend = "one reading" }
        let gaps = Set(samples.map(\.segment)).count > 1 ? " Includes collection gaps." : ""
        return "Last \(window.label): latest \(valueLabel(last.value)), minimum \(valueLabel(minimum)), maximum \(valueLabel(maximum)), \(trend).\(gaps)"
    }

    var body: some View {
        VStack(spacing: 3) {
            HStack {
                Text(minimumLabel)
                Spacer()
                Text(valueLabel(fixedMax ?? history.maximum(in: window, now: now)))
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
            plot.overlay {
                if visible.isEmpty {
                    Text("No readings in this window").font(.caption2).foregroundStyle(.secondary)
                }
            }
            HStack {
                Text(window == .minute ? "−60s" : "−5 min")
                Spacer()
                Text("Now")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("History")
        .accessibilityValue(summary)
    }

    private var plot: some View {
        GeometryReader { geometry in
            let start = now.addingTimeInterval(-window.duration)
            let paths = history.segments(in: window, now: now).map { segment in
                segment.map { sample in
                    CGPoint(x: geometry.size.width * sample.timestamp.timeIntervalSince(start) / window.duration,
                            y: geometry.size.height * (1 - min(1, max(0, sample.value / scale))))
                }
            }
            ZStack {
                Rectangle().fill(.quaternary).frame(height: 1)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                ForEach(Array(paths.enumerated()), id: \.offset) { _, points in
                    if points.count > 1 {
                        Path { path in
                            guard let first = points.first else { return }
                            path.move(to: first)
                            for point in points.dropFirst() { path.addLine(to: point) }
                        }
                        .stroke(color, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                    } else if let point = points.first {
                        Circle().fill(color).frame(width: 3, height: 3).position(point)
                    }
                }
            }
            .clipped()
        }
    }
}
