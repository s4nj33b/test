import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private enum Defaults {
        static let chargingEnabled = "chargingEnabled"
        static let offMode = "offMode"
        static let fallbackPercent = "fallbackPercent"
    }

    /// Range and step of the low-battery fallback slider, in battery percent.
    private let fallbackRange = 10...80
    private let fallbackStep = 5
    private let defaultFallbackPercent = 20
    /// Minimum seconds between automatic re-applies triggered by power events.
    private let reapplyThrottle: TimeInterval = 30

    private let controller = PowerController()
    private var powerMonitor: PowerSourceMonitor?
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()

    private let toggle = NSSwitch()
    private let batteryItem = NSMenuItem()
    private let sourceItem = NSMenuItem()
    private let errorItem = NSMenuItem()
    private let inhibitModeItem = NSMenuItem()
    private let blockModeItem = NSMenuItem()
    private let loginItem = NSMenuItem()
    private let fallbackSlider = NSSlider()
    private let fallbackLabel = NSTextField(labelWithString: "")

    private var lastApplied: PowerMode?
    private var lastApplyDate = Date.distantPast
    private var lastError: String?

    // MARK: - Persisted settings

    private var chargingEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Defaults.chargingEnabled) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Defaults.chargingEnabled) }
    }

    /// What "off" means: stop charging only, or ignore monitor power entirely.
    private var offMode: PowerMode {
        get {
            let raw = UserDefaults.standard.string(forKey: Defaults.offMode) ?? PowerMode.inhibit.rawValue
            return PowerMode(rawValue: raw) == .block ? .block : .inhibit
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Defaults.offMode) }
    }

    /// In "block" mode the Mac runs on battery; at or below this level it falls
    /// back to "inhibit", so the Mac runs from the monitor and the battery holds.
    private var fallbackPercent: Int {
        get {
            let stored = UserDefaults.standard.object(forKey: Defaults.fallbackPercent) as? Int
            return min(max(stored ?? defaultFallbackPercent, fallbackRange.lowerBound), fallbackRange.upperBound)
        }
        set { UserDefaults.standard.set(newValue, forKey: Defaults.fallbackPercent) }
    }

    /// The SMC mode that should currently be in effect.
    private var desiredMode: PowerMode {
        if chargingEnabled { return .allow }
        if offMode == .block, let pct = BatteryInfo.current().percent, pct <= fallbackPercent {
            return .inhibit
        }
        return offMode
    }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        buildMenu()
        statusItem.menu = menu

        powerMonitor = PowerSourceMonitor { [weak self] in self?.powerSourceChanged() }

        // SMC charge settings are reset by sleep on some firmware; re-assert on wake.
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(didWake),
            name: NSWorkspace.didWakeNotification, object: nil)

        applyDesiredMode(force: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Never leave the Mac unable to charge once the app is gone.
        if lastApplied != .allow {
            _ = controller.applySync(.allow)
        }
    }

    // MARK: - Menu

    private func buildMenu() {
        menu.delegate = self
        menu.autoenablesItems = false

        let toggleItem = NSMenuItem()
        toggleItem.view = makeToggleView()
        menu.addItem(toggleItem)
        menu.addItem(.separator())

        for item in [batteryItem, sourceItem] {
            item.isEnabled = false
            menu.addItem(item)
        }
        errorItem.isEnabled = false
        errorItem.isHidden = true
        menu.addItem(errorItem)
        menu.addItem(.separator())

        let offModeParent = NSMenuItem(title: "When Off", action: nil, keyEquivalent: "")
        let offModeMenu = NSMenu()
        inhibitModeItem.title = "Stop Charging (keep using monitor power)"
        inhibitModeItem.action = #selector(selectInhibitMode)
        inhibitModeItem.target = self
        blockModeItem.title = "Disconnect Monitor Power (run on battery)"
        blockModeItem.action = #selector(selectBlockMode)
        blockModeItem.target = self
        offModeMenu.addItem(inhibitModeItem)
        offModeMenu.addItem(blockModeItem)
        let sliderItem = NSMenuItem()
        sliderItem.view = makeFallbackSliderView()
        offModeMenu.addItem(sliderItem)
        offModeParent.submenu = offModeMenu
        menu.addItem(offModeParent)

        loginItem.title = "Launch at Login"
        loginItem.action = #selector(toggleLaunchAtLogin)
        loginItem.target = self
        menu.addItem(loginItem)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Monitor Power", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        refreshUI()
    }

    private func makeToggleView() -> NSView {
        let label = NSTextField(labelWithString: "Charge from Monitor")
        label.font = .menuFont(ofSize: 0)

        toggle.target = self
        toggle.action = #selector(toggleChanged)
        toggle.controlSize = .small

        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)

        let stack = NSStackView(views: [label, spacer, toggle])
        stack.orientation = .horizontal
        stack.edgeInsets = NSEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
        stack.frame = NSRect(x: 0, y: 0, width: 280, height: 32)
        stack.autoresizingMask = [.width]
        return stack
    }

    private func makeFallbackSliderView() -> NSView {
        fallbackLabel.font = .menuFont(ofSize: NSFont.smallSystemFontSize)
        fallbackLabel.textColor = .secondaryLabelColor

        fallbackSlider.minValue = Double(fallbackRange.lowerBound)
        fallbackSlider.maxValue = Double(fallbackRange.upperBound)
        fallbackSlider.numberOfTickMarks = (fallbackRange.upperBound - fallbackRange.lowerBound) / fallbackStep + 1
        fallbackSlider.allowsTickMarkValuesOnly = true
        fallbackSlider.controlSize = .small
        fallbackSlider.isContinuous = true
        fallbackSlider.target = self
        fallbackSlider.action = #selector(fallbackSliderChanged)
        fallbackSlider.widthAnchor.constraint(greaterThanOrEqualToConstant: 190).isActive = true

        let minLabel = NSTextField(labelWithString: "\(fallbackRange.lowerBound)%")
        let maxLabel = NSTextField(labelWithString: "\(fallbackRange.upperBound)%")
        for label in [minLabel, maxLabel] {
            label.font = .menuFont(ofSize: NSFont.smallSystemFontSize)
            label.textColor = .tertiaryLabelColor
        }
        let sliderRow = NSStackView(views: [minLabel, fallbackSlider, maxLabel])
        sliderRow.orientation = .horizontal
        sliderRow.spacing = 6

        let stack = NSStackView(views: [fallbackLabel, sliderRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.edgeInsets = NSEdgeInsets(top: 4, left: 22, bottom: 6, right: 14)
        stack.frame = NSRect(x: 0, y: 0, width: 300, height: 52)
        stack.autoresizingMask = [.width]
        return stack
    }

    private func updateFallbackLabel() {
        fallbackLabel.stringValue = "Use monitor power at or below \(fallbackPercent)% battery"
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshUI()
    }

    private func refreshUI() {
        toggle.state = chargingEnabled ? .on : .off

        let info = BatteryInfo.current()
        let pct = info.percent.map { "\($0)%" } ?? "—"
        let state: String
        if info.isCharging {
            state = "Charging"
        } else if info.onExternalPower {
            state = lastApplied == .block ? "On Battery (monitor power ignored)" : "Not Charging"
        } else {
            state = "On Battery"
        }
        batteryItem.title = "Battery: \(pct) · \(state)"

        if lastApplied == .block {
            sourceItem.title = "USB-C Power: Ignored"
        } else if info.onExternalPower {
            let watts = info.adapterWatts.map { " (\($0) W)" } ?? ""
            sourceItem.title = "USB-C Power Connected\(watts)"
        } else {
            sourceItem.title = "No USB-C Power Connected"
        }

        if let lastError {
            errorItem.title = "⚠︎ \(lastError)"
            errorItem.isHidden = false
        } else {
            errorItem.isHidden = true
        }

        inhibitModeItem.state = offMode == .inhibit ? .on : .off
        blockModeItem.state = offMode == .block ? .on : .off
        fallbackSlider.integerValue = fallbackPercent
        fallbackSlider.isEnabled = offMode == .block
        fallbackLabel.textColor = offMode == .block ? .secondaryLabelColor : .tertiaryLabelColor
        updateFallbackLabel()

        if #available(macOS 13.0, *) {
            loginItem.isHidden = false
            loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        } else {
            loginItem.isHidden = true
        }

        updateIcon()
    }

    private func updateIcon() {
        let symbol = chargingEnabled ? "bolt.fill" : "bolt.slash.fill"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Monitor Power")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = chargingEnabled
            ? "Monitor Power: charging from monitor"
            : "Monitor Power: charging from monitor is off"
    }

    // MARK: - Actions

    @objc private func toggleChanged() {
        chargingEnabled = toggle.state == .on
        applyDesiredMode(force: true)
    }

    @objc private func selectInhibitMode() {
        offMode = .inhibit
        applyDesiredMode(force: true)
    }

    @objc private func selectBlockMode() {
        offMode = .block
        applyDesiredMode(force: true)
    }

    @objc private func fallbackSliderChanged() {
        let stepped = Int((fallbackSlider.doubleValue / Double(fallbackStep)).rounded()) * fallbackStep
        fallbackPercent = stepped
        updateFallbackLabel()

        // Apply once the drag ends, and only if the threshold now changes the mode.
        let isDragging = NSApp.currentEvent?.type == .leftMouseDragged
        if !isDragging, desiredMode != lastApplied {
            applyDesiredMode(force: true)
        }
    }

    @objc private func toggleLaunchAtLogin() {
        guard #available(macOS 13.0, *) else { return }
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            lastError = nil
        } catch {
            lastError = "Launch at login: \(error.localizedDescription)"
        }
        refreshUI()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func didWake() {
        // Give the SMC a moment to settle after wake before re-asserting.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.applyDesiredMode(force: true)
        }
    }

    private func powerSourceChanged() {
        let desired = desiredMode
        let info = BatteryInfo.current()
        // Re-assert if the mode should change (e.g. low-battery fallback) or if the
        // firmware started charging again on its own (e.g. after a cable re-plug).
        let drifted = desired != .allow && info.isCharging
        if desired != lastApplied || drifted {
            applyDesiredMode(force: false)
        } else {
            refreshUI()
        }
    }

    // MARK: - Applying

    private func applyDesiredMode(force: Bool) {
        let mode = desiredMode
        if !force, Date().timeIntervalSince(lastApplyDate) < reapplyThrottle {
            refreshUI()
            return
        }
        lastApplyDate = Date()

        guard controller.helperInstalled else {
            lastError = "Helper not installed. Run scripts/install.sh"
            refreshUI()
            return
        }

        controller.apply(mode) { [weak self] result in
            guard let self else { return }
            if result.success {
                self.lastApplied = mode
                self.lastError = nil
            } else {
                self.lastError = result.output.contains("password")
                    ? "Permission denied. Re-run scripts/install.sh"
                    : "Failed: \(result.output)"
            }
            self.refreshUI()
        }
    }
}
