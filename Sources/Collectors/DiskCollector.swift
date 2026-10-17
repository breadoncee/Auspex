//
//  DiskCollector.swift
//  Auspex
//
//  Enumerates mounted volumes and preserves unavailable capacity readings.
//  Finder-compatible available space includes purgeable storage. Read-only
//  images and network volumes are identified separately from writable disks.
//

import Foundation

struct DiskCollector {
    private let keys: Set<URLResourceKey> = [
        .volumeNameKey,
        .volumeTotalCapacityKey,
        .volumeAvailableCapacityForImportantUsageKey,
        .volumeAvailableCapacityKey,
        .volumeIsRemovableKey,
        .volumeIsInternalKey,
        .volumeIsBrowsableKey,
        .volumeIsReadOnlyKey,
        .volumeIsLocalKey,
    ]

    func collect() -> [DiskInfo] { collectReading() ?? [] }

    /// nil means enumeration failed; an empty array means no browsable volumes.
    func collectReading() -> [DiskInfo]? {
        guard let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: Array(keys),
            options: [.skipHiddenVolumes]
        ) else { return nil }

        let disks = urls.compactMap { url -> DiskInfo? in
            let values = try? url.resourceValues(forKeys: keys)
            // Hidden system snapshots are omitted. Missing metadata is retained
            // as an unavailable reading rather than a fabricated full disk.
            if values?.volumeIsBrowsable == false { return nil }
            let total = UInt64(max(0, values?.volumeTotalCapacity ?? 0))
            return DiskInfo(
                url: url,
                name: values?.volumeName ?? url.lastPathComponent,
                total: total,
                available: Self.availableBytes(
                    total: total,
                    important: values?.volumeAvailableCapacityForImportantUsage,
                    basic: values?.volumeAvailableCapacity
                ),
                isRemovable: values?.volumeIsRemovable ?? false,
                isInternal: values?.volumeIsInternal ?? false,
                isReadOnly: values?.volumeIsReadOnly ?? false,
                isLocal: values?.volumeIsLocal ?? true
            )
        }
        return disks.sorted(by: Self.orderedBefore)
    }

    static func availableBytes(total: UInt64, important: Int64?, basic: Int?) -> UInt64? {
        // Negative resource values are unknown, not zero free bytes. Prefer
        // Finder's important-usage capacity, falling back only when unavailable.
        let validImportant = important.flatMap { $0 >= 0 ? UInt64($0) : nil }
        let validBasic = basic.flatMap { $0 >= 0 ? UInt64($0) : nil }
        guard total > 0, let available = validImportant ?? validBasic else { return nil }
        return min(total, available)
    }

    static func orderedBefore(_ lhs: DiskInfo, _ rhs: DiskInfo) -> Bool {
        func rank(_ disk: DiskInfo) -> Int {
            if disk.isLocal && !disk.isReadOnly && disk.isInternal { return 0 }
            if disk.isLocal && !disk.isReadOnly { return 1 }
            if disk.isLocal { return 2 }
            return 3
        }
        if rank(lhs) != rank(rhs) { return rank(lhs) < rank(rhs) }
        let comparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        return comparison == .orderedSame ? lhs.url.path < rhs.url.path : comparison == .orderedAscending
    }
}
