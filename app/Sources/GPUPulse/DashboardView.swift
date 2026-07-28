import SwiftUI

struct DashboardView: View {
    @ObservedObject var store: MonitorStore

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                MineLegend()
                Spacer()
                UtilLegend()
                RefreshButton(store: store)
            }
            .padding(.horizontal, 4)

            if store.servers.isEmpty {
                NoServersView()
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(store.servers) { server in
                        ServerCard(server: server)
                    }
                }
            }
        }
        .padding(10)
        .frame(width: 640, height: 454)
        .preferredColorScheme(.light)
    }
}

private struct NoServersView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "server.rack")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Color.black.opacity(0.32))
            Text("No servers selected")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.62))
            Text("Right-click the menu-bar icon and choose Servers…")
                .font(.system(size: 11))
                .foregroundStyle(Color.black.opacity(0.40))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct MineLegend: View {
    private let ownershipColor = Color(red: 0.37, green: 0.39, blue: 0.94)

    var body: some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(ownershipColor)
                .frame(width: 2, height: 10)

            Text("MINE")
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.7)
                .foregroundStyle(ownershipColor.opacity(0.86))
        }
        .help("GPUs running your processes")
    }
}

private struct RefreshButton: View {
    @ObservedObject var store: MonitorStore

    var body: some View {
        Button {
            store.refresh()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.48))
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(0.07), lineWidth: 0.6)
                    )

                if store.isRefreshing {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.72)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.48))
                }
            }
            .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .disabled(store.isRefreshing)
        .help(store.isRefreshing ? "Refreshing GPU data…" : "Refresh GPU data")
        .accessibilityLabel("Refresh GPU data")
    }
}

private struct UtilLegend: View {
    var body: some View {
        HStack(spacing: 7) {
            Text("UTIL")
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Color.black.opacity(0.42))

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.15, green: 0.67, blue: 0.28),
                            Color(red: 0.93, green: 0.63, blue: 0.05),
                            Color(red: 0.91, green: 0.22, blue: 0.20)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 104, height: 7)
                .overlay(Capsule().stroke(Color.white.opacity(0.42), lineWidth: 0.5))
        }
    }
}

private struct ServerCard: View {
    let server: ServerSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.52))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.black.opacity(0.055), lineWidth: 0.6)
                        )
                    Image(systemName: "square.grid.3x3")
                        .font(.system(size: 10, weight: .medium))
                }
                .frame(width: 21, height: 21)

                Text(server.config.displayName.uppercased())
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("MEM")
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(Color.black.opacity(0.30))
                Circle()
                    .fill(server.health.color)
                    .frame(width: 7, height: 7)
                    .shadow(color: server.health.color.opacity(0.56), radius: 4)
            }
            .foregroundStyle(Color.black.opacity(0.54))

            if server.gpus.isEmpty {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(server.health == .connecting ? "CONNECTING" : "OFFLINE")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.42))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 3) {
                    ForEach(server.gpus) { gpu in
                        GPURow(gpu: gpu)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 200, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.42), Color.white.opacity(0.18)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.14), radius: 8, y: 5)
    }
}

private struct GPURow: View {
    let gpu: GPUStat

    private let ownershipColor = Color(red: 0.37, green: 0.39, blue: 0.94)

    private func thresholdColor(for fraction: Double) -> Color {
        switch fraction {
        case 0.8...: return Color(red: 0.91, green: 0.22, blue: 0.20)
        case 0.5...: return Color(red: 0.93, green: 0.63, blue: 0.05)
        default: return Color(red: 0.15, green: 0.67, blue: 0.28)
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(gpu.isOwnedByCurrentUser ? ownershipColor : Color.clear)
                .frame(width: 2, height: 10)

            Text("GPU #\(gpu.index)")
                .font(.system(size: 11, weight: gpu.isOwnedByCurrentUser ? .bold : .medium))
                .foregroundStyle(Color.black.opacity(0.82))
                .frame(width: 47, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.06))
                        .overlay(Capsule().stroke(Color.white.opacity(0.36), lineWidth: 0.5))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    thresholdColor(for: gpu.utilizationFraction).opacity(0.72),
                                    thresholdColor(for: gpu.utilizationFraction)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(4, proxy.size.width * gpu.memoryFraction))
                        .shadow(color: thresholdColor(for: gpu.utilizationFraction).opacity(0.18), radius: 2)
                }
            }
            .frame(height: 7)

        }
        .padding(.horizontal, 3)
        .frame(height: 15)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(gpu.isOwnedByCurrentUser ? ownershipColor.opacity(0.075) : Color.clear)
        )
        .help(gpu.isOwnedByCurrentUser ? "Your process is using this GPU" : "GPU #\(gpu.index)")
        .animation(.easeInOut(duration: 0.4), value: gpu.memoryFraction)
        .animation(.easeInOut(duration: 0.2), value: gpu.isOwnedByCurrentUser)
    }
}
