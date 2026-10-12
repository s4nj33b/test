import Foundation

/// What the MacBook does with power coming in over USB-C.
enum PowerMode: String {
    /// Normal behaviour: run from, and charge from, the monitor.
    case allow
    /// Run from the monitor's power but leave the battery level untouched.
    case inhibit
    /// Ignore the monitor's power entirely and run from the battery.
    case block
}

/// Talks to the root `smc-power` helper through a NOPASSWD sudoers rule
/// installed by `scripts/install.sh`.
final class PowerController {
    static let helperPath = "/usr/local/bin/smc-power"

    struct Result {
        let success: Bool
        let output: String
    }

    private let queue = DispatchQueue(label: "MonitorPower.helper")

    func apply(_ mode: PowerMode, completion: @escaping (Result) -> Void) {
        queue.async {
            let result = Self.run(["-n", Self.helperPath, mode.rawValue])
            DispatchQueue.main.async { completion(result) }
        }
    }

    /// Blocking variant, used while the app is quitting.
    func applySync(_ mode: PowerMode) -> Result {
        queue.sync { Self.run(["-n", Self.helperPath, mode.rawValue]) }
    }

    var helperInstalled: Bool {
        FileManager.default.isExecutableFile(atPath: Self.helperPath)
    }

    private static func run(_ args: [String]) -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
        } catch {
            return Result(success: false, output: error.localizedDescription)
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return Result(success: process.terminationStatus == 0, output: output)
    }
}
