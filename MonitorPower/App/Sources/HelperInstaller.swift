import Foundation

/// Installs the root `smc-power` helper and its sudoers rule from inside the
/// app bundle, using the standard macOS administrator password prompt. This
/// lets users install by dragging the app out of the DMG, with no Terminal.
enum HelperInstaller {
    struct Failure: LocalizedError {
        let message: String
        let cancelled: Bool
        var errorDescription: String? { message }
    }

    static let sudoersPath = "/etc/sudoers.d/monitor-power"

    private static var bundledHelper: URL? {
        Bundle.main.url(forResource: "smc-power", withExtension: nil)
    }

    private static var bundledScript: URL? {
        Bundle.main.url(forResource: "helper-install", withExtension: "sh")
    }

    /// True when the installed helper matches the one shipped in this app
    /// version and the sudoers rule is present.
    static var isUpToDate: Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: sudoersPath),
              fm.isExecutableFile(atPath: PowerController.helperPath)
        else { return false }
        guard let bundled = bundledHelper else { return true }
        return fm.contentsEqual(atPath: bundled.path, andPath: PowerController.helperPath)
    }

    static func install() throws {
        guard let helper = bundledHelper, let script = bundledScript else {
            throw Failure(message: "The app bundle is missing its helper files.", cancelled: false)
        }
        try runAsAdmin([script.path, "install", helper.path, NSUserName()])
    }

    static func uninstall() throws {
        guard let script = bundledScript else {
            throw Failure(message: "The app bundle is missing its helper files.", cancelled: false)
        }
        try runAsAdmin([script.path, "uninstall"])
    }

    private static func runAsAdmin(_ args: [String]) throws {
        let command = (["/bin/sh"] + args).map(shellQuote).joined(separator: " ")
        let source = "do shell script \"\(appleScriptEscape(command))\" with administrator privileges"
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error {
            let code = error[NSAppleScript.errorNumber] as? Int
            let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
            throw Failure(message: message, cancelled: code == -128)
        }
    }

    private static func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func appleScriptEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }
}
