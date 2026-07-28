import Foundation
import Combine

@MainActor
final class MonitorStore: ObservableObject {
    static let supportedRefreshIntervals: [TimeInterval] = [5, 10, 30, 60]
    private static let refreshIntervalKey = "refreshInterval"

    @Published private(set) var servers: [ServerSnapshot] = ServerConfig.all.map {
        ServerSnapshot(
            config: $0,
            gpus: [],
            health: .connecting,
            lastSuccess: nil,
            latency: nil,
            errorMessage: nil
        )
    }
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastCompletedRefresh: Date?
    @Published var refreshInterval: TimeInterval {
        didSet {
            UserDefaults.standard.set(refreshInterval, forKey: Self.refreshIntervalKey)
            scheduleTimer()
        }
    }

    private var timer: Timer?
    private var isRunning = false

    init() {
        let savedInterval = UserDefaults.standard.double(forKey: Self.refreshIntervalKey)
        refreshInterval = Self.supportedRefreshIntervals.contains(savedInterval) ? savedInterval : 10
    }

    var allGPUs: [GPUStat] { servers.flatMap(\.gpus) }
    var onlineServerCount: Int { servers.filter { $0.health == .online }.count }
    var busyGPUCount: Int { allGPUs.filter(\.isBusy).count }
    var totalGPUCount: Int { allGPUs.count }
    var averageUtilization: Double {
        guard !allGPUs.isEmpty else { return 0 }
        return allGPUs.map(\.utilization).reduce(0, +) / Double(allGPUs.count)
    }
    var totalMemoryUsedGiB: Double { allGPUs.map(\.memoryUsedGiB).reduce(0, +) }
    var totalMemoryGiB: Double { allGPUs.map(\.memoryTotalGiB).reduce(0, +) }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        scheduleTimer()
        refresh()
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true

        Task {
            let results = await withTaskGroup(of: CollectionResult.self) { group in
                for config in ServerConfig.all {
                    group.addTask { await SSHCollector.collect(config) }
                }
                var collected: [CollectionResult] = []
                for await result in group { collected.append(result) }
                return collected
            }

            let now = Date()
            for result in results {
                guard let index = servers.firstIndex(where: { $0.config.id == result.config.id }) else {
                    continue
                }
                if let error = result.error {
                    servers[index].health = servers[index].lastSuccess == nil ? .offline : .delayed
                    servers[index].latency = result.latency
                    servers[index].errorMessage = concise(error)
                } else {
                    servers[index].gpus = result.gpus
                    servers[index].health = .online
                    servers[index].lastSuccess = now
                    servers[index].latency = result.latency
                    servers[index].errorMessage = nil
                }
            }
            lastCompletedRefresh = now
            isRefreshing = false
        }
    }

    private func scheduleTimer() {
        timer?.invalidate()
        guard isRunning else {
            timer = nil
            return
        }
        let timer = Timer(timeInterval: max(refreshInterval, 5), repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func concise(_ error: String) -> String {
        let firstLine = error.split(whereSeparator: \.isNewline).first.map(String.init) ?? error
        return firstLine
    }
}
