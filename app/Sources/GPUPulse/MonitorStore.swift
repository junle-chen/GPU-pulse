import Foundation
import Combine

@MainActor
final class MonitorStore: ObservableObject {
    static let supportedRefreshIntervals: [TimeInterval] = [5, 10, 30, 60]
    static let maximumSelectedHosts = 4
    private static let refreshIntervalKey = "refreshInterval"
    private static let selectedHostsKey = "selectedSSHHosts"

    @Published private(set) var availableHosts: [ServerConfig]
    @Published private(set) var selectedHostIDs: Set<String>
    @Published private(set) var servers: [ServerSnapshot]
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
        let defaults = UserDefaults.standard
        let savedInterval = defaults.double(forKey: Self.refreshIntervalKey)
        let discoveredHosts = ServerConfig.discover()
        let discoveredIDs = Set(discoveredHosts.map(\.id))
        let savedHosts = Set(defaults.stringArray(forKey: Self.selectedHostsKey) ?? [])
        let selection = savedHosts.intersection(discoveredIDs)

        availableHosts = discoveredHosts
        selectedHostIDs = selection
        servers = discoveredHosts
            .filter { selection.contains($0.id) }
            .map(Self.snapshot)
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

    func isSelected(_ host: ServerConfig) -> Bool {
        selectedHostIDs.contains(host.id)
    }

    func setSelected(_ selected: Bool, for host: ServerConfig) {
        if selected {
            guard selectedHostIDs.count < Self.maximumSelectedHosts else { return }
            selectedHostIDs.insert(host.id)
        } else {
            selectedHostIDs.remove(host.id)
        }
        saveSelection()
        rebuildServers()
        if isRunning { refresh() }
    }

    func reloadHosts() {
        availableHosts = ServerConfig.discover()
        selectedHostIDs.formIntersection(Set(availableHosts.map(\.id)))
        saveSelection()
        rebuildServers()
        if isRunning { refresh() }
    }

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
        let configs = servers.map(\.config)
        guard !configs.isEmpty else {
            lastCompletedRefresh = Date()
            return
        }
        isRefreshing = true

        Task {
            let results = await withTaskGroup(of: CollectionResult.self) { group in
                for config in configs {
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

    private static func snapshot(for config: ServerConfig) -> ServerSnapshot {
        ServerSnapshot(
            config: config,
            gpus: [],
            health: .connecting,
            lastSuccess: nil,
            latency: nil,
            errorMessage: nil
        )
    }

    private func saveSelection() {
        UserDefaults.standard.set(selectedHostIDs.sorted(), forKey: Self.selectedHostsKey)
    }

    private func rebuildServers() {
        let previous = Dictionary(uniqueKeysWithValues: servers.map { ($0.id, $0) })
        servers = availableHosts
            .filter { selectedHostIDs.contains($0.id) }
            .map { previous[$0.id] ?? Self.snapshot(for: $0) }
    }

    private func concise(_ error: String) -> String {
        let firstLine = error.split(whereSeparator: \.isNewline).first.map(String.init) ?? error
        return firstLine
    }
}
