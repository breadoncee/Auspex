import Foundation

enum HistoryWindow: String, CaseIterable, Identifiable {
    case minute, fiveMinutes
    var id: String { rawValue }
    var duration: TimeInterval { self == .minute ? 60 : 300 }
    var label: String { self == .minute ? "60 seconds" : "5 minutes" }
}

struct HistoryPoint: Equatable, Sendable {
    let timestamp: Date
    let value: Double
    let segment: Int
}

/// Short, in-memory history. Its x axis uses elapsed time, never sample indices.
/// A new segment prevents lines bridging a pause or a failed collection.
struct MetricHistory: Equatable, Sendable {
    private(set) var points: [HistoryPoint] = []
    private var segment = 0
    static let retention: TimeInterval = 300
    static let maximumPoints = 601

    mutating func markGap() { segment &+= 1 }

    mutating func append(_ value: Double, at timestamp: Date) {
        guard value.isFinite, timestamp.timeIntervalSinceReferenceDate.isFinite else { return }
        // Clock changes must not produce a backwards line or invalid elapsed axis.
        if let last = points.last, timestamp <= last.timestamp { markGap(); return }
        points.removeAll { $0.timestamp < timestamp.addingTimeInterval(-Self.retention) }
        points.append(HistoryPoint(timestamp: timestamp, value: value, segment: segment))
        if points.count > Self.maximumPoints { points.removeFirst(points.count - Self.maximumPoints) }
    }

    func visible(in window: HistoryWindow, now: Date = Date()) -> [HistoryPoint] {
        let start = now.addingTimeInterval(-window.duration)
        return points.filter { $0.timestamp >= start && $0.timestamp <= now }
    }

    func segments(in window: HistoryWindow, now: Date = Date()) -> [[HistoryPoint]] {
        var result: [[HistoryPoint]] = []
        for point in visible(in: window, now: now) {
            if result.last?.last?.segment == point.segment {
                result[result.count - 1].append(point)
            } else { result.append([point]) }
        }
        return result
    }

    func maximum(in window: HistoryWindow, now: Date = Date()) -> Double {
        visible(in: window, now: now).map(\.value).max() ?? 0
    }
}
