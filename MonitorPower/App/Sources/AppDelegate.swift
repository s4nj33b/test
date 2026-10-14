import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private enum Defaults {
        static let chargingEnabled = "chargingEnabled"
        static let runOnBattery = "runOnBattery"
        static let dischargeTarget = "fallbackPercent"  // key kept from 0.01
    }

    /// Range and step of the discharge target slider, in battery percent.
    private let targetRange = 10...80
    private let targetStep = 5
    private let defaultTarget = 20
    /// Backup check of the discharge target in case no power event arrives.
    private var dischargeCheckTimer: Timer?
    /// Minimum seconds between automatic re-applies triggered by power events.
    private let reapplyThrottle: TimeInterval = 30

    private let controller = PowerController()
    private var powerMonitor: PowerSourceMonitor?
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()

    private let toggle = NSSwitch()
    private let batteryToggle = NSSwitch()
    private let batteryItem = NSMenuItem()
    private let sourceItem = NSMenuItem()
    private let noticeItem = NSMenuItem()
    private let errorItem = NSMenuItem()
    private let loginItem = NSMenuItem()
    private let installHelperItem = NSMenuItem()
    private let targetSlider = NSSlider()
    private let targetLabel = NSTextField(labelWithString: "")

    private var lastApplied: PowerMode?
    private var lastApplyDate = Date.distantPast
    /// Mode just applied, and until when the hardware may still be catching up.
    /// While the reported state disagrees with it, the menu says so instead of
    /// showing the stale reading.
    private var transition: (mode: PowerMode, until: Date)?
    private let transitionTimeout: TimeInterval = 15
    /// Refreshes the menu every second while it is open.
    private var menuRefreshTimer: Timer?
    private var lastError: String?
    /// Informational line, e.g. "Discharge finished at 20%".
    private var notice: String?

    // MARK: - Persisted settings

    private var chargingEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Defaults.chargingEnabled) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Defaults.chargingEnabled) }
    }

    /// Discharge cycle in progress: the Mac ignores the power adapter and runs
    /// on its battery until it reaches `dischargeTarget`.
    private var runOnBattery: Bool {
        get { UserDefaults.standard.bool(forKey: Defaults.runOnBattery) }
        set { UserDefaults.standard.set(newValue, forKey: Defaults.runOnBattery) }
    }

    /// Battery level at which a discharge cycle ends and the Mac switches back
    /// to the power adapter.
    private var dischargeTarget: Int {
        get {
            let stored = UserDefaults.standard.object(forKey: Defaults.dischargeTarget) as? Int
            return min(max(stored ?? defaultTarget, targetRange.lowerBound), targetRange.upperBound)
        }
        set { UserDefaults.standard.set(newValue, forKey: Defaults.dischargeTarget) }
    }

    /// The SMC mode that should currently be in effect.
    private var desiredMode: PowerMode {
        if runOnBattery { return .block }
        return chargingEnabled ? .allow : .inhibit
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

        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in self?.powerSourceChanged() }
        RunLoop.main.add(timer, forMode: .common)
        dischargeCheckTimer = timer

        if moveToApplicationsIfNeeded() { return }
        if HelperInstaller.isUpToDate {
            applyDesiredMode(force: true)
        } else {
            promptToInstallHelper()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Never leave the Mac unable to charge once the app is gone.
        if let lastApplied, lastApplied != .allow {
            _ = controller.applySync(.allow)
        }
    }

    // MARK: - Menu

    private func buildMenu() {
        menu.delegate = self
        menu.autoenablesItems = false

        let chargeItem = NSMenuItem()
        chargeItem.view = makeSwitchRow("Charge from Monitor", toggle, #selector(toggleChanged))
        menu.addItem(chargeItem)
        let dischargeItem = NSMenuItem()
        dischargeItem.view = makeSwitchRow("Run on Battery", batteryToggle, #selector(batteryToggleChanged))
        menu.addItem(dischargeItem)
        let sliderItem = NSMenuItem()
        sliderItem.view = makeTargetSliderView()
        menu.addItem(sliderItem)
        menu.addItem(.separator())

        for item in [batteryItem, sourceItem, noticeItem] {
            item.isEnabled = false
            menu.addItem(item)
        }
        noticeItem.isHidden = true
        errorItem.isEnabled = false
        errorItem.isHidden = true
        menu.addItem(errorItem)
        installHelperItem.title = "Install Helper…"
        installHelperItem.action = #selector(installHelper)
        installHelperItem.target = self
        menu.addItem(installHelperItem)
        menu.addItem(.separator())

        loginItem.title = "Launch at Login"
        loginItem.action = #selector(toggleLaunchAtLogin)
        loginItem.target = self
        menu.addItem(loginItem)

        menu.addItem(.separator())
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        let versionItem = NSMenuItem(title: "Monitor Power \(version)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)
        let uninstall = NSMenuItem(title: "Uninstall…", action: #selector(uninstall), keyEquivalent: "")
        uninstall.target = self
        menu.addItem(uninstall)
        let quit = NSMenuItem(title: "Quit Monitor Power", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        refreshUI()
    }

    private func makeSwitchRow(_ title: String, _ control: NSSwitch, _ action: Selector) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .menuFont(ofSize: 0)

        control.target = self
        control.action = action
        control.controlSize = .small

        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)

        let stack = NSStackView(views: [label, spacer, control])
        stack.orientation = .horizontal
        stack.edgeInsets = NSEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
        stack.frame = NSRect(x: 0, y: 0, width: 300, height: 32)
        stack.autoresizingMask = [.width]
        return stack
    }

    private func makeTargetSliderView() -> NSView {
        targetLabel.font = .menuFont(ofSize: NSFont.smallSystemFontSize)
        targetLabel.textColor = .secondaryLabelColor

        targetSlider.minValue = Double(targetRange.lowerBound)
        targetSlider.maxValue = Double(targetRange.upperBound)
        targetSlider.numberOfTickMarks = (targetRange.upperBound - targetRange.lowerBound) / targetStep + 1
        targetSlider.allowsTickMarkValuesOnly = true
        targetSlider.controlSize = .small
        targetSlider.isContinuous = true
        targetSlider.target = self
        targetSlider.action = #selector(targetSliderChanged)
        targetSlider.widthAnchor.constraint(greaterThanOrEqualToConstant: 190).isActive = true

        let minLabel = NSTextField(labelWithString: "\(targetRange.lowerBound)%")
        let maxLabel = NSTextField(labelWithString: "\(targetRange.upperBound)%")
        for label in [minLabel, maxLabel] {
            label.font = .menuFont(ofSize: NSFont.smallSystemFontSize)
            label.textColor = .tertiaryLabelColor
        }
        let sliderRow = NSStackView(views: [minLabel, targetSlider, maxLabel])
        sliderRow.orientation = .horizontal
        sliderRow.spacing = 6

        let stack = NSStackView(views: [targetLabel, sliderRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 14, bottom: 6, right: 14)
        stack.frame = NSRect(x: 0, y: 0, width: 300, height: 52)
        stack.autoresizingMask = [.width]
        return stack
    }

    private func updateTargetLabel() {
        targetLabel.stringValue = "Discharge down to \(dischargeTarget)%, then use monitor power"
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshUI()
        menuRefreshTimer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.refreshUI() }
        // .common so it also fires while the menu is tracking the mouse.
        RunLoop.main.add(timer, forMode: .common)
        menuRefreshTimer = timer
    }

    func menuDidClose(_ menu: NSMenu) {
        menuRefreshTimer?.invalidate()
        menuRefreshTimer = nil
    }

    /// Whether the reported battery state is what `mode` should produce.
    private func batteryState(_ info: BatteryInfo, matches mode: PowerMode) -> Bool {
        switch mode {
        case .allow: return info.isCharging || info.isFullyCharged || !info.onExternalPower
        case .inhibit, .block: return !info.isCharging
        }
    }

    private func transitionText(for mode: PowerMode) -> String {
        switch mode {
        case .allow: return "Starting to Charge…"
        case .inhibit: return "Stopping Charging…"
        case .block: return "Switching to Battery…"
        }
    }

    private func refreshUI() {
        toggle.state = chargingEnabled ? .on : .off
        batteryToggle.state = runOnBattery ? .on : .off

        let info = BatteryInfo.current()
        let pct = info.percent.map { "\($0)%" } ?? "—"

        if let t = transition, Date() >= t.until || batteryState(info, matches: t.mode) {
            transition = nil
        }

        let state: String
        if let t = transition {
            state = transitionText(for: t.mode)
        } else if info.isCharging {
            state = "Charging"
        } else if lastApplied == .block {
            state = "Discharging"
        } else if info.onExternalPower {
            state = "Not Charging"
        } else {
            state = "On Battery"
        }
        batteryItem.title = "Battery: \(pct) · \(state)"

        if lastApplied == .block {
            sourceItem.title = "Power Source: Battery (until \(dischargeTarget)%)"
        } else if info.onExternalPower {
            let watts = info.adapterWatts.map { " (\($0) W)" } ?? ""
            sourceItem.title = "USB-C Power Connected\(watts)"
        } else {
            sourceItem.title = "No USB-C Power Connected"
        }

        installHelperItem.isHidden = HelperInstaller.isUpToDate

        noticeItem.title = notice ?? ""
        noticeItem.isHidden = notice == nil

        if let lastError {
            errorItem.title = "⚠︎ \(lastError)"
            errorItem.isHidden = false
        } else {
            errorItem.isHidden = true
        }

        targetSlider.integerValue = dischargeTarget
        updateTargetLabel()

        if #available(macOS 13.0, *) {
            loginItem.isHidden = false
            loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        } else {
            loginItem.isHidden = true
        }

        updateIcon()
    }

    private func updateIcon() {
        let symbol: String
        let tip: String
        if runOnBattery {
            symbol = "battery.25"
            tip = "Monitor Power: running on battery until \(dischargeTarget)%"
        } else if chargingEnabled {
            symbol = "bolt.fill"
            tip = "Monitor Power: charging from monitor"
        } else {
            symbol = "bolt.slash.fill"
            tip = "Monitor Power: charging from monitor is off"
        }
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Monitor Power")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = tip
    }

    // MARK: - Actions

    @objc private func toggleChanged() {
        chargingEnabled = toggle.state == .on
        notice = nil
        applyDesiredMode(force: true)
    }

    @objc private func batteryToggleChanged() {
        if batteryToggle.state == .on {
            if let pct = BatteryInfo.current().percent, pct <= dischargeTarget {
                notice = "Battery is already at \(pct)%. Lower the target below to discharge."
                batteryToggle.state = .off
                refreshUI()
                return
            }
            notice = nil
            runOnBattery = true
        } else {
            runOnBattery = false
        }
        applyDesiredMode(force: true)
    }

    @objc private func targetSliderChanged() {
        let stepped = Int((targetSlider.doubleValue / Double(targetStep)).rounded()) * targetStep
        dischargeTarget = stepped
        updateTargetLabel()

        // Act once the drag ends: a higher target may end a running discharge.
        let isDragging = NSApp.currentEvent?.type == .leftMouseDragged
        if !isDragging, finishDischargeIfTargetReached() {
            applyDesiredMode(force: true)
        }
    }

    /// Ends the discharge cycle once the battery reaches the target.
    /// Returns true if the cycle was ended.
    @discardableResult
    private func finishDischargeIfTargetReached() -> Bool {
        guard runOnBattery, let pct = BatteryInfo.current().percent, pct <= dischargeTarget else { return false }
        runOnBattery = false
        let next = chargingEnabled ? "charging from monitor" : "running on monitor power"
        notice = "Discharge finished at \(pct)%; now \(next)"
        return true
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

    // MARK: - Setup

    /// Apps launched straight from the DMG run from a read-only, temporary
    /// volume. Offer to copy the app to /Applications and relaunch from there.
    /// Returns true when the app is relaunching and this instance should stop.
    private func moveToApplicationsIfNeeded() -> Bool {
        let bundleURL = Bundle.main.bundleURL
        guard bundleURL.path.hasPrefix("/Volumes/") else { return false }

        let alert = NSAlert()
        alert.messageText = "Move Monitor Power to Applications?"
        alert.informativeText = "Monitor Power is running from the disk image. Move it to the Applications folder so it keeps working after the disk image is ejected."
        alert.addButton(withTitle: "Move to Applications")
        alert.addButton(withTitle: "Not Now")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return false }

        let destination = URL(fileURLWithPath: "/Applications").appendingPathComponent(bundleURL.lastPathComponent)
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.trashItem(at: destination, resultingItemURL: nil)
            }
            try FileManager.default.copyItem(at: bundleURL, to: destination)
        } catch {
            showError("Could not move the app", error.localizedDescription + "\n\nDrag Monitor Power into the Applications folder manually.")
            return false
        }

        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: destination, configuration: config) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
        return true
    }

    private func promptToInstallHelper() {
        let alert = NSAlert()
        alert.messageText = "Finish setting up Monitor Power"
        alert.informativeText = "To control charging, Monitor Power installs a small helper tool. macOS will ask for your administrator password once.\n\nAfter this, the switch works without asking again."
        alert.addButton(withTitle: "Install Helper")
        alert.addButton(withTitle: "Later")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            installHelper()
        } else {
            lastError = "Setup not finished. Choose “Install Helper…”"
            refreshUI()
        }
    }

    @objc private func installHelper() {
        do {
            try HelperInstaller.install()
            lastError = nil
            applyDesiredMode(force: true)
        } catch let failure as HelperInstaller.Failure where failure.cancelled {
            lastError = "Setup not finished. Choose “Install Helper…”"
            refreshUI()
        } catch {
            lastError = "Helper install failed"
            showError("Helper install failed", error.localizedDescription)
            refreshUI()
        }
    }

    @objc private func uninstall() {
        let alert = NSAlert()
        alert.messageText = "Uninstall Monitor Power?"
        alert.informativeText = "This restores normal charging, removes the helper tool and quits the app. You can then drag Monitor Power from Applications to the Trash."
        alert.addButton(withTitle: "Uninstall")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            try HelperInstaller.uninstall()
        } catch let failure as HelperInstaller.Failure where failure.cancelled {
            return
        } catch {
            showError("Uninstall failed", error.localizedDescription)
            return
        }
        if #available(macOS 13.0, *) {
            try? SMAppService.mainApp.unregister()
        }
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
        lastApplied = .allow  // the uninstall script already restored charging
        NSApp.terminate(nil)
    }

    private func showError(_ title: String, _ detail: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = detail
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func didWake() {
        // Give the SMC a moment to settle after wake before re-asserting.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.applyDesiredMode(force: true)
        }
    }

    private func powerSourceChanged() {
        finishDischargeIfTargetReached()
        let desired = desiredMode
        let info = BatteryInfo.current()
        // Re-assert if the mode should change (e.g. discharge finished) or if the
        // firmware started charging again on its own (e.g. after a cable re-plug).
        let drifted = desired != .allow && info.isCharging
        if desired != lastApplied {
            applyDesiredMode(force: true)
        } else if drifted {
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
        if mode != lastApplied {
            transition = (mode, Date().addingTimeInterval(transitionTimeout))
            // Pick up the new hardware state even if no power notification arrives.
            for delay in [1.0, 2, 4, 8, transitionTimeout + 0.5] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.refreshUI() }
            }
        }

        guard controller.helperInstalled else {
            lastError = "Setup not finished. Choose “Install Helper…”"
            transition = nil
            refreshUI()
            return
        }

        controller.apply(mode) { [weak self] result in
            guard let self else { return }
            if result.success {
                self.lastApplied = mode
                self.lastError = nil
            } else {
                self.transition = nil
                self.lastError = result.output.contains("password")
                    ? "Permission denied. Choose “Install Helper…”"
                    : "Failed: \(result.output)"
            }
            self.refreshUI()
        }
    }
}
