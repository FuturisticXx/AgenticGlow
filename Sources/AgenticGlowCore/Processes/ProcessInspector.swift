import AppKit
import Darwin
import Foundation

public struct InspectedProcess: Equatable, Sendable {
    public let pid: Int32
    public let parentPID: Int32
    public let name: String
    public let startedAt: Date?
    public let bundleID: String?

    public init(
        pid: Int32,
        parentPID: Int32,
        name: String,
        startedAt: Date?,
        bundleID: String?
    ) {
        self.pid = pid
        self.parentPID = parentPID
        self.name = name
        self.startedAt = startedAt
        self.bundleID = bundleID
    }
}

public protocol ProcessInspecting: Sendable {
    var currentParentPID: Int32 { get }
    func process(_ pid: Int32) -> InspectedProcess?
}

public struct DarwinProcessInspector: ProcessInspecting {
    public init() {}

    public var currentParentPID: Int32 { getppid() }

    public func process(_ pid: Int32) -> InspectedProcess? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else {
            return nil
        }

        var nameBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
        let name = String(
            decoding: nameBuffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) },
            as: UTF8.self
        )
        let startedAt: Date?
        if info.pbi_start_tvsec > 0 {
            let startTime = TimeInterval(info.pbi_start_tvsec)
                + (TimeInterval(info.pbi_start_tvusec) / 1_000_000)
            startedAt = Date(timeIntervalSince1970: startTime)
        } else {
            startedAt = nil
        }
        let bundleID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier

        return InspectedProcess(
            pid: pid,
            parentPID: Int32(info.pbi_ppid),
            name: name,
            startedAt: startedAt,
            bundleID: bundleID
        )
    }
}
