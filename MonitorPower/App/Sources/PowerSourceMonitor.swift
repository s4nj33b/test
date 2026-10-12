import Foundation
import IOKit
import IOKit.ps

/// Snapshot of the internal battery and the attached power source.
struct BatteryInfo {
    var percent: Int?
    var isCharging = false
    var isFullyCharged = false
    var onExternalPower = false
    var adapterWatts: Int?

    static func current() -> BatteryInfo {
        var info = fromSmartBattery() ?? fromPowerSources()
        if let adapter = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() as? [String: Any] {
            info.adapterWatts = adapter[kIOPSPowerAdapterWattsKey] as? Int
        }
        return info
    }

    /// Reads the battery driver's registry entry directly. It reflects charge
    /// state changes within a second or two, whereas the IOPowerSources summary
    /// that powerd publishes can lag behind by much longer.
    private static func fromSmartBattery() -> BatteryInfo? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = props?.takeRetainedValue() as? [String: Any],
              let charging = dict["IsCharging"] as? Bool
        else { return nil }

        var info = BatteryInfo()
        info.isCharging = charging
        info.isFullyCharged = dict["FullyCharged"] as? Bool ?? false
        info.onExternalPower = dict["ExternalConnected"] as? Bool ?? false
        if let cur = dict["CurrentCapacity"] as? Int, let max = dict["MaxCapacity"] as? Int, max > 0 {
            info.percent = cur * 100 / max
        }
        return info
    }

    private static func fromPowerSources() -> BatteryInfo {
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
            info.isFullyCharged = desc[kIOPSIsChargedKey] as? Bool ?? false
            info.onExternalPower = desc[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
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
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    }

    deinit {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
    }
}
