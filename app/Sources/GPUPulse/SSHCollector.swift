import Foundation

enum SSHCollector {
    private static let ownedMarker = "__OWNED_GPU_UUIDS__"
    private static let query = "nvidia-smi --query-gpu=index,uuid,name,memory.used,memory.total,utilization.gpu --format=csv,noheader,nounits; printf \"%s\\n\" \"\(ownedMarker)\"; me=$(id -un); nvidia-smi --query-compute-apps=gpu_uuid,pid --format=csv,noheader,nounits 2>/dev/null | while IFS=, read -r uuid pid; do uuid=$(printf \"%s\" \"$uuid\" | xargs); pid=$(printf \"%s\" \"$pid\" | xargs); owner=$(ps -o user:64= -p \"$pid\" | xargs); if [ \"$owner\" = \"$me\" ]; then printf \"%s\\n\" \"$uuid\"; fi; done; true"

    static func collect(_ config: ServerConfig) async -> CollectionResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: collectSynchronously(config))
            }
        }
    }

    private static func collectSynchronously(_ config: ServerConfig) -> CollectionResult {
        let started = Date()
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        process.arguments = [
            "-o", "BatchMode=yes",
            "-o", "ConnectTimeout=8",
            "-o", "ConnectionAttempts=1",
            "-o", "ServerAliveInterval=5",
            "-o", "ServerAliveCountMax=1",
            "-o", "ControlMaster=auto",
            "-o", "ControlPersist=60",
            "-o", "ControlPath=/tmp/gpupulse-%C",
            "-o", "ClearAllForwardings=yes",
            config.host,
            query
        ]
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
            process.waitUntilExit()

            let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
            let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
            let output = String(decoding: outputData, as: UTF8.self)
            let errorOutput = String(decoding: errorData, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let latency = Date().timeIntervalSince(started)

            guard process.terminationStatus == 0 else {
                let message = errorOutput.isEmpty
                    ? "SSH exited with status \(process.terminationStatus)"
                    : errorOutput
                return CollectionResult(config: config, gpus: [], latency: latency, error: message)
            }

            let gpus = parse(output)
            guard !gpus.isEmpty else {
                return CollectionResult(
                    config: config,
                    gpus: [],
                    latency: latency,
                    error: "No GPU data returned"
                )
            }
            return CollectionResult(config: config, gpus: gpus, latency: latency, error: nil)
        } catch {
            return CollectionResult(
                config: config,
                gpus: [],
                latency: Date().timeIntervalSince(started),
                error: error.localizedDescription
            )
        }
    }

    private static func parse(_ output: String) -> [GPUStat] {
        let lines = output
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let statsLines: ArraySlice<String>
        let ownedUUIDs: Set<String>
        if let markerIndex = lines.firstIndex(of: ownedMarker) {
            statsLines = lines[..<markerIndex]
            ownedUUIDs = Set(lines[lines.index(after: markerIndex)...])
        } else {
            statsLines = lines[...]
            ownedUUIDs = []
        }

        return statsLines
            .compactMap { rawLine -> GPUStat? in
                let values = rawLine
                    .split(separator: ",", omittingEmptySubsequences: false)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                guard values.count >= 6,
                      let index = Int(values[0]),
                      let memoryUsed = Double(values[3]),
                      let memoryTotal = Double(values[4]),
                      let utilization = Double(values[5]) else {
                    return nil
                }
                let uuid = values[1]
                return GPUStat(
                    index: index,
                    uuid: uuid,
                    name: values[2],
                    memoryUsedMiB: memoryUsed,
                    memoryTotalMiB: memoryTotal,
                    utilization: utilization,
                    isOwnedByCurrentUser: ownedUUIDs.contains(uuid)
                )
            }
            .sorted { $0.index < $1.index }
    }
}
