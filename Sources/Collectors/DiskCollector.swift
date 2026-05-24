//
//  DiskCollector.swift
//  Auspex
//
//  Enumerates mounted volumes (internal + external) and reports capacity.
//  Uses URLResourceValues so "available" matches Finder (counts purgeable
//  space), unlike raw statfs block counts.
//

import Foundation

struct DiskCollector {
    private let keys: Set<URLResourceKey> = [
        .volumeNameKey,
        .volumeTotalCapacityKey,
        .volumeAvailableCapacityForImportantUsageKey,
        .volumeIsRemovableKey,
        .volumeIsInternalKey,
        .volumeIsBrowsableKey,
    ]

    func collect() -> [DiskInfo] {
        let fm = FileManager.default
        guard let urls = fm.mountedVolumeURLs(
            includingResourceValuesForKeys: Array(keys),
            options: [.skipHiddenVolumes]
        ) else { return [] }

        var disks: [DiskInfo] = []
        for url in urls {
            guard let values = try? url.resourceValues(forKeys: keys) else { continue }
            // Skip non-browsable system volumes (e.g. the read-only system snapshot).
            if values.volumeIsBrowsable == false { continue }

            let total = UInt64(values.volumeTotalCapacity ?? 0)
            guard total > 0 else { continue }

            // `volumeAvailableCapacityForImportantUsage` is Int64 and may be 0
            // on some virtual volumes; treat 0 as "full" rather than dropping it.
            let available = UInt64(max(0, values.volumeAvailableCapacityForImportantUsage ?? 0))

            disks.append(
                DiskInfo(
                    url: url,
                    name: values.volumeName ?? url.lastPathComponent,
                    total: total,
                    available: available,
                    isRemovable: values.volumeIsRemovable ?? false,
                    isInternal: values.volumeIsInternal ?? true
                )
            )
        }

        // Internal first, then by name for stable ordering.
        disks.sort {
            if $0.isInternal != $1.isInternal { return $0.isInternal && !$1.isInternal }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        return disks
    }
}
