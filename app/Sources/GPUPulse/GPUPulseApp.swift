import SwiftUI
import AppKit
import Combine
import ServiceManagement

@main
struct GPUPulseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let store = MonitorStore()
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        configurePopover()
        observeStore()

        if CommandLine.arguments.contains("--settings") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.showServerSettings(nil)
            }
        } else if CommandLine.arguments.contains("--show") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.showPopover(nil)
            }
        }
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: "GPU Pulse")
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
    }

    private func configurePopover() {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentSize = NSSize(width: 640, height: 454)
        popover.contentViewController = NSHostingController(
            rootView: dashboardView()
        )
        self.popover = popover
    }

    private func dashboardView() -> DashboardView {
        DashboardView(store: store)
    }

    private func observeStore() {
        store.$servers
            .receive(on: RunLoop.main)
            .sink { [weak self] servers in
                let gpus = servers.flatMap(\.gpus)
                let active = gpus.filter(\.isBusy).count
                self?.statusItem?.button?.toolTip = "GPU Pulse · \(active) active GPUs"
            }
            .store(in: &cancellables)
    }

    @objc private func togglePopover(_ sender: Any?) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            popover?.performClose(sender)
            showContextMenu()
            return
        }

        guard let popover else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            showPopover(sender)
        }
    }

    private func showPopover(_ sender: Any?) {
        guard let button = statusItem?.button, let popover else { return }
        store.start()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    func popoverDidClose(_ notification: Notification) {
        store.stop()
    }

    private func showContextMenu() {
        guard let button = statusItem?.button,
              let event = NSApp.currentEvent else { return }

        let menu = NSMenu()

        let serversItem = NSMenuItem(
            title: "Servers…",
            action: #selector(showServerSettings(_:)),
            keyEquivalent: ""
        )
        serversItem.target = self
        menu.addItem(serversItem)
        menu.addItem(.separator())

        let launchItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin(_:)),
            keyEquivalent: ""
        )
        launchItem.target = self
        switch SMAppService.mainApp.status {
        case .enabled:
            launchItem.state = .on
        case .requiresApproval:
            launchItem.state = .mixed
        default:
            launchItem.state = .off
        }
        menu.addItem(launchItem)

        let intervalItem = NSMenuItem(title: "Refresh Interval", action: nil, keyEquivalent: "")
        let intervalMenu = NSMenu()
        for interval in MonitorStore.supportedRefreshIntervals {
            let item = NSMenuItem(
                title: intervalTitle(interval),
                action: #selector(selectRefreshInterval(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = NSNumber(value: interval)
            item.state = store.refreshInterval == interval ? .on : .off
            intervalMenu.addItem(item)
        }
        intervalItem.submenu = intervalMenu
        menu.addItem(intervalItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit GPU Pulse",
            action: #selector(quitApplication(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        NSMenu.popUpContextMenu(menu, with: event, for: button)
    }

    private func intervalTitle(_ interval: TimeInterval) -> String {
        interval == 60 ? "1 minute" : "\(Int(interval)) seconds"
    }

    @objc private func selectRefreshInterval(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? NSNumber else { return }
        store.refreshInterval = value.doubleValue
    }

    @objc private func showServerSettings(_ sender: Any?) {
        store.reloadHosts()

        let window: NSWindow
        if let existing = settingsWindow {
            window = existing
        } else {
            let controller = NSHostingController(rootView: HostSettingsView(store: store))
            window = NSWindow(contentViewController: controller)
            window.title = "GPU Pulse Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.setContentSize(NSSize(width: 460, height: 430))
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(sender)
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let service = SMAppService.mainApp
        do {
            switch service.status {
            case .enabled:
                try service.unregister()
            case .requiresApproval:
                SMAppService.openSystemSettingsLoginItems()
            default:
                try service.register()
                if service.status == .requiresApproval {
                    SMAppService.openSystemSettingsLoginItems()
                }
            }
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "Couldn’t update Launch at Login"
            alert.runModal()
        }
    }

    @objc private func quitApplication(_ sender: Any?) {
        NSApp.terminate(sender)
    }
}
