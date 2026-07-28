import SwiftUI

struct HostSettingsView: View {
    @ObservedObject var store: MonitorStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Servers")
                    .font(.system(size: 20, weight: .semibold))
                Text("Select up to \(MonitorStore.maximumSelectedHosts) SSH hosts to monitor.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Group {
                if store.availableHosts.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 26, weight: .light))
                            .foregroundStyle(.secondary)
                        Text("No SSH Hosts Found")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Add explicit Host entries to ~/.ssh/config, then reload.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(store.availableHosts) { host in
                                hostRow(host)
                            }
                        }
                        .padding(6)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )

            HStack {
                Button {
                    store.reloadHosts()
                } label: {
                    Label("Reload SSH Config", systemImage: "arrow.clockwise")
                }

                Spacer()

                Text("\(store.selectedHostIDs.count) selected")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Text("Only selected hosts are contacted. Host names stay on this Mac.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(20)
        .frame(width: 460, height: 430)
    }

    private func hostRow(_ host: ServerConfig) -> some View {
        let selected = store.isSelected(host)
        let selectionLimitReached =
            store.selectedHostIDs.count >= MonitorStore.maximumSelectedHosts

        return Toggle(
            isOn: Binding(
                get: { store.isSelected(host) },
                set: { store.setSelected($0, for: host) }
            )
        ) {
            VStack(alignment: .leading, spacing: 2) {
                Text(host.displayName.uppercased())
                    .font(.system(size: 12, weight: .semibold))
                Text(host.host)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .toggleStyle(.checkbox)
        .disabled(!selected && selectionLimitReached)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
