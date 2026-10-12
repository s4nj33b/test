import Foundation
import IOKit.ps

/// Snapshot of the internal battery and the attached power source.
struct BatteryInfo {
    var percent: Int?
    var isCharging = false
    var onExternalPower = false
    var adapterWatts: Int?

    static func current() -> BatteryInfo {
        var info = BatteryInfo()
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        else { return info }

        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(blob, source)?
                .takeUnretainedValue() as? [String: Any],
                  desc[kIOPSTypeKey] as? String == kIOPSInternalBatteryType
            else { continue }

            if let cur = desc[kIOPSCurrentCapacityKey] as? Int,
               let max = desc[kIOPSMaxCapacityKey] as? Int, max > 0 {
                info.percent = cur * 100 / max
            }
            info.isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
            info.onExternalPower = desc[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
        }

        if let adapter = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() as? [String: Any] {
            info.adapterWatts = adapter[kIOPSPowerAdapterWattsKey] as? Int
        }
        return info
    }
}

/// Calls `onChange` whenever macOS reports a power source change
/// (cable plugged/unplugged, charging started/stopped, battery level change).
final class PowerSourceMonitor {
    private var runLoopSource: CFRunLoopSource?
    private let onChange: () -> Void

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            Unmanaged<PowerSourceMonitor>.fromOpaque(ctx).takeUnretainedValue().onChange()
        }, context)?.takeRetainedValue() else { return }
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }

    deinit {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
        }
    }
}
