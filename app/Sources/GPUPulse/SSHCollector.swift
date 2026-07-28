import Foundation

enum SSHCollector {
    private static let processMarker = "__GPU_PROCESSES__"
    private static let query = """
    nvidia-smi --query-gpu=index,uuid,name,memory.used,memory.total,utilization.gpu --format=csv,noheader,nounits
    printf "%s\\n" "\(processMarker)"
    me=$(id -un)
    nvidia-smi --query-compute-apps=gpu_uuid,pid,used_memory,process_name --format=csv,noheader,nounits 2>/dev/null | while IFS=, read -r uuid pid memory process_name; do
        uuid=$(printf "%s" "$uuid" | xargs)
        pid=$(printf "%s" "$pid" | xargs)
        memory=$(printf "%s" "$memory" | xargs)
        fallback=$(printf "%s" "$process_name" | xargs)
        [ -n "$pid" ] || continue
        owner=$(ps -o user:64= -p "$pid" 2>/dev/null | xargs)
        elapsed=$(ps -o etime= -p "$pid" 2>/dev/null | xargs)
        command=$(ps -o comm= -p "$pid" 2>/dev/null | xargs)
        [ -n "$owner" ] || continue
        [ -n "$command" ] || command="$fallback"
        is_mine=0
        [ "$owner" = "$me" ] && is_mine=1
        printf "%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n" "$uuid" "$owner" "$elapsed" "$memory" "$is_mine" "$command"
    done
    true
    """

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
        let processLines: ArraySlice<String>
        if let markerIndex = lines.firstIndex(of: processMarker) {
            statsLines = lines[..<markerIndex]
            processLines = lines[lines.index(after: markerIndex)...]
        } else {
            statsLines = lines[...]
            processLines = []
        }

        var processesByGPU: [String: [GPUProcessStat]] = [:]
        for (offset, rawLine) in processLines.enumerated() {
            let values = rawLine.split(
                separator: "\t",
                maxSplits: 5,
                omittingEmptySubsequences: false
            )
            guard values.count == 6 else { continue }
            let gpuUUID = String(values[0])
            let memoryUsed = Double(values[3]) ?? 0
            let process = GPUProcessStat(
                id: "\(gpuUUID):\(offset)",
                username: String(values[1]),
                processName: String(values[5]),
                elapsedTime: values[2].isEmpty ? "—" : String(values[2]),
                memoryUsedMiB: memoryUsed,
                isCurrentUser: values[4] == "1"
            )
            processesByGPU[gpuUUID, default: []].append(process)
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
                    processes: processesByGPU[uuid, default: []]
                )
            }
            .sorted { $0.index < $1.index }
    }
}
