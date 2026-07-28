import Foundation
import SwiftUI

struct ServerConfig: Identifiable, Hashable, Codable {
    let id: String
    let displayName: String
    let host: String

    static let all: [ServerConfig] = load()

    static let configURL: URL = {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return applicationSupport
            .appendingPathComponent("GPU Pulse", isDirectory: true)
            .appendingPathComponent("servers.json")
    }()

    private static let exampleServers: [ServerConfig] = (1...4).map { index in
        ServerConfig(
            id: "server-\(index)",
            displayName: "SERVER \(index)",
            host: "gpu-server-\(index)"
        )
    }

    private static func load() -> [ServerConfig] {
        guard let data = try? Data(contentsOf: configURL),
              let servers = try? JSONDecoder().decode([ServerConfig].self, from: data),
              !servers.isEmpty else {
            return exampleServers
        }
        return servers
    }
}

struct GPUStat: Identifiable, Hashable {
    let index: Int
    let uuid: String
    let name: String
    let memoryUsedMiB: Double
    let memoryTotalMiB: Double
    let utilization: Double
    let isOwnedByCurrentUser: Bool

    var id: Int { index }
    var memoryFraction: Double {
        guard memoryTotalMiB > 0 else { return 0 }
        return min(max(memoryUsedMiB / memoryTotalMiB, 0), 1)
    }
    var utilizationFraction: Double { min(max(utilization / 100, 0), 1) }
    var memoryUsedGiB: Double { memoryUsedMiB / 1024 }
    var memoryTotalGiB: Double { memoryTotalMiB / 1024 }
    var isBusy: Bool { utilization >= 10 || memoryFraction >= 0.1 }
}

enum ServerHealth: Equatable {
    case connecting
    case online
    case delayed
    case offline

    var label: String {
        switch self {
        case .connecting: return "CONNECTING"
        case .online: return "ONLINE"
        case .delayed: return "DELAYED"
        case .offline: return "OFFLINE"
        }
    }

    var color: Color {
        switch self {
        case .connecting: return .blue
        case .online: return Color(red: 0.31, green: 0.96, blue: 0.65)
        case .delayed: return Color(red: 1.0, green: 0.69, blue: 0.26)
        case .offline: return Color(red: 1.0, green: 0.32, blue: 0.46)
        }
    }
}

struct ServerSnapshot: Identifiable {
    let config: ServerConfig
    var gpus: [GPUStat]
    var health: ServerHealth
    var lastSuccess: Date?
    var latency: TimeInterval?
    var errorMessage: String?

    var id: String { config.id }
    var averageUtilization: Double {
        guard !gpus.isEmpty else { return 0 }
        return gpus.map(\.utilization).reduce(0, +) / Double(gpus.count)
    }
    var memoryUsedMiB: Double { gpus.map(\.memoryUsedMiB).reduce(0, +) }
    var memoryTotalMiB: Double { gpus.map(\.memoryTotalMiB).reduce(0, +) }
    var busyGPUCount: Int { gpus.filter(\.isBusy).count }
}

struct CollectionResult {
    let config: ServerConfig
    let gpus: [GPUStat]
    let latency: TimeInterval
    let error: String?
}
