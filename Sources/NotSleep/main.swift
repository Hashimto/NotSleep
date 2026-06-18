import AppKit
import Foundation
import SwiftUI

private enum SleepSetting: Equatable {
    case enabled
    case disabled
    case unknown

    var isSleepEnabled: Bool {
        self != .disabled
    }

    var statusSymbolName: String {
        switch self {
        case .enabled:
            return "moon.fill"
        case .disabled:
            return "sun.max.fill"
        case .unknown:
            return "questionmark.circle"
        }
    }

    var statusDescription: String {
        switch self {
        case .enabled:
            return "スリープ有効"
        case .disabled:
            return "スリープ無効"
        case .unknown:
            return "状態不明"
        }
    }
}

private enum SleepError: LocalizedError {
    case appleScriptUnavailable
    case authorizationFailed(String)
    case helperUnavailable
    case commandFailed(String)
    case unsupportedUserName(String)

    var errorDescription: String? {
        switch self {
        case .appleScriptUnavailable:
            return "AppleScriptを作成できませんでした。"
        case .authorizationFailed(let message):
            return message
        case .helperUnavailable:
            return "スリープ設定用ヘルパーが見つからないか、認証なしで実行できません。"
        case .commandFailed(let message):
            return message
        case .unsupportedUserName(let userName):
            return "ユーザー名「\(userName)」をsudoersへ安全に登録できません。"
        }
    }
}

private final class PrivilegedHelperInstaller {
    private let helperPath = "/Library/PrivilegedHelperTools/local.notsleep.pmset-helper"
    private let sudoersPath = "/etc/sudoers.d/local-notsleep"
    private let temporarySudoersPath = "/private/tmp/local-notsleep.sudoers"

    var helperExecutablePath: String {
        helperPath
    }

    func ensureInstalled() throws {
        if helperIsReady {
            return
        }

        try install()

        guard helperIsReady else {
            throw SleepError.helperUnavailable
        }
    }

    private var helperIsReady: Bool {
        FileManager.default.isExecutableFile(atPath: helperPath)
            && canRunHelperCheck()
    }

    func reinstall() throws {
        try install()

        guard helperIsReady else {
            throw SleepError.helperUnavailable
        }
    }

    private func install() throws {
        let userName = NSUserName()
        let allowedUserName = try sudoersSafeUserName(userName)
        let helperScript = """
        #!/bin/sh
        set -eu

        case "${1:-}" in
            check)
                exit 0
                ;;
            0|1)
                /usr/bin/pmset -a disablesleep "$1"
                ;;
            *)
                exit 64
                ;;
        esac
        """
        let sudoers = """
        \(allowedUserName) ALL=(root) NOPASSWD: \(helperPath) check, \(helperPath) 0, \(helperPath) 1
        """

        let helperBase64 = Data(helperScript.utf8).base64EncodedString()
        let sudoersBase64 = Data(sudoers.utf8).base64EncodedString()
        let command = [
            "/bin/mkdir -p /Library/PrivilegedHelperTools",
            "/bin/echo '\(helperBase64)' | /usr/bin/base64 -D > \(shellQuoted(helperPath))",
            "/usr/sbin/chown root:wheel \(shellQuoted(helperPath))",
            "/bin/chmod 755 \(shellQuoted(helperPath))",
            "/bin/echo '\(sudoersBase64)' | /usr/bin/base64 -D > \(shellQuoted(temporarySudoersPath))",
            "/usr/sbin/visudo -cf \(shellQuoted(temporarySudoersPath))",
            "/bin/mv \(shellQuoted(temporarySudoersPath)) \(shellQuoted(sudoersPath))",
            "/usr/sbin/chown root:wheel \(shellQuoted(sudoersPath))",
            "/bin/chmod 440 \(shellQuoted(sudoersPath))"
        ].joined(separator: " && ")

        let script = """
        do shell script "\(appleScriptEscaped(command))" with administrator privileges
        """

        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            throw SleepError.appleScriptUnavailable
        }

        appleScript.executeAndReturnError(&error)

        if let error {
            let message = error[NSAppleScript.errorMessage] as? String
            throw SleepError.authorizationFailed(message ?? "初回セットアップの認証に失敗しました。")
        }
    }

    private func sudoersSafeUserName(_ userName: String) throws -> String {
        let pattern = #"^[A-Za-z0-9._-]+$"#
        if userName.range(of: pattern, options: .regularExpression) != nil {
            return userName
        }

        throw SleepError.unsupportedUserName(userName)
    }

    private func canRunHelperCheck() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["-n", helperPath, "check"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private func appleScriptEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

private final class SleepController {
    private let helperInstaller = PrivilegedHelperInstaller()

    func prepareForUse() throws {
        try helperInstaller.ensureInstalled()
    }

    func currentSetting() -> SleepSetting {
        guard let output = runPmset(arguments: ["-g"]) else {
            return .unknown
        }

        if let value = Self.sleepDisabledValue(in: output) {
            return value == "1" ? .disabled : .enabled
        }

        guard let customOutput = runPmset(arguments: ["-g", "custom"]) else {
            return .unknown
        }

        guard let value = Self.disablesleepValue(in: customOutput) else {
            return .enabled
        }

        return value == "1" ? .disabled : .enabled
    }

    func setSleepEnabled(_ isSleepEnabled: Bool) throws {
        try helperInstaller.ensureInstalled()
        do {
            try runHelper(isSleepEnabled: isSleepEnabled)
        } catch {
            try helperInstaller.reinstall()
            try runHelper(isSleepEnabled: isSleepEnabled)
        }
    }

    private func runHelper(isSleepEnabled: Bool) throws {
        let process = Process()
        let output = Pipe()
        let value = isSleepEnabled ? "0" : "1"

        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["-n", helperInstaller.helperExecutablePath, value]
        process.standardOutput = output
        process.standardError = output

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw SleepError.commandFailed(error.localizedDescription)
        }

        guard process.terminationStatus == 0 else {
            let data = output.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw SleepError.commandFailed(message ?? "pmsetの実行に失敗しました。")
        }
    }

    private func runPmset(arguments: [String]) -> String? {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }

    private static func sleepDisabledValue(in output: String) -> String? {
        let pattern = #"(?m)^\s*SleepDisabled\s+([01])\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(output.startIndex..<output.endIndex, in: output)
        guard let match = regex.firstMatch(in: output, range: range),
              let valueRange = Range(match.range(at: 1), in: output) else {
            return nil
        }

        return String(output[valueRange])
    }

    private static func disablesleepValue(in output: String) -> String? {
        let pattern = #"(?m)^\s*disablesleep\s+([01])\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(output.startIndex..<output.endIndex, in: output)
        guard let match = regex.firstMatch(in: output, range: range),
              let valueRange = Range(match.range(at: 1), in: output) else {
            return nil
        }

        return String(output[valueRange])
    }
}

@MainActor
private final class AppModel: ObservableObject {
    @Published var isSleepEnabled = true
    @Published var isReady = false
    @Published var isBusy = false

    var onToggle: ((Bool) -> Void)?

    func setSetting(_ setting: SleepSetting) {
        isSleepEnabled = setting.isSleepEnabled
    }

    func userChangedToggle(to newValue: Bool) {
        guard isReady, !isBusy else {
            isSleepEnabled.toggle()
            return
        }

        onToggle?(newValue)
    }
}

private struct MainView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)

            Toggle(
                model.isSleepEnabled ? "オン" : "オフ",
                isOn: Binding(
                    get: { model.isSleepEnabled },
                    set: { model.userChangedToggle(to: $0) }
                )
            )
            .toggleStyle(.switch)
            .controlSize(.large)
            .font(.system(size: 15, weight: .medium))
            .disabled(!model.isReady || model.isBusy)
        }
        .frame(minWidth: 360, minHeight: 240)
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let sleepController = SleepController()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let model = AppModel()

    private var window: NSWindow?
    private var refreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        model.onToggle = { [weak self] isSleepEnabled in
            self?.setSleepEnabled(isSleepEnabled)
        }

        configureMainMenu()
        configureStatusItem()
        configureWindow()
        prepareAndRefresh()
        startStatusMonitoring()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
    }

    @objc private func showWindow() {
        NSApp.setActivationPolicy(.regular)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func toggleFromStatusItem() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showStatusMenu()
            return
        }

        guard model.isReady, !model.isBusy else {
            return
        }

        setSleepEnabled(!model.isSleepEnabled)
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()

        appMenu.addItem(
            NSMenuItem(
                title: "ウィンドウを表示",
                action: #selector(showWindow),
                keyEquivalent: "0"
            )
        )
        appMenu.addItem(.separator())
        appMenu.addItem(
            NSMenuItem(
                title: "NotSleepを終了",
                action: #selector(quit),
                keyEquivalent: "q"
            )
        )

        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        NSApp.mainMenu = mainMenu
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        button.target = self
        button.action = #selector(toggleFromStatusItem)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.imagePosition = .imageOnly
    }

    private func showStatusMenu() {
        let menu = NSMenu()
        menu.addItem(
            NSMenuItem(
                title: "ウィンドウを表示",
                action: #selector(showWindow),
                keyEquivalent: ""
            )
        )
        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(
                title: "NotSleepを終了",
                action: #selector(quit),
                keyEquivalent: ""
            )
        )

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func configureWindow() {
        let contentRect = NSRect(x: 0, y: 0, width: 360, height: 240)
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.center()
        window.title = "NotSleep"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = NSHostingView(rootView: MainView(model: model))
        window.makeKeyAndOrderFront(nil)

        self.window = window
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    private func prepareAndRefresh() {
        model.isBusy = true
        render()

        do {
            try sleepController.prepareForUse()
            model.isReady = true
            syncSettingFromSystem()
            model.isBusy = false
            render()
        } catch {
            model.isReady = false
            model.isBusy = false
            render()
            present(error: error)
        }
    }

    private func syncSettingFromSystem() {
        model.setSetting(sleepController.currentSetting())
        render()
    }

    private func setSleepEnabled(_ isSleepEnabled: Bool) {
        model.isBusy = true
        model.isSleepEnabled = isSleepEnabled
        render()

        do {
            try sleepController.setSleepEnabled(isSleepEnabled)
            syncSettingFromSystem()
            model.isBusy = false
            render()
        } catch {
            model.setSetting(sleepController.currentSetting())
            model.isBusy = false
            render()
            present(error: error)
        }
    }

    private func startStatusMonitoring() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(
            timeInterval: 2.0,
            target: self,
            selector: #selector(refreshFromTimer),
            userInfo: nil,
            repeats: true
        )
    }

    @objc private func refreshFromTimer() {
        guard model.isReady, !model.isBusy else {
            return
        }

        syncSettingFromSystem()
    }

    private func render() {
        let setting: SleepSetting = model.isSleepEnabled ? .enabled : .disabled

        guard let button = statusItem.button else {
            return
        }

        button.image = NSImage(
            systemSymbolName: setting.statusSymbolName,
            accessibilityDescription: setting.statusDescription
        )
        button.toolTip = model.isSleepEnabled ? "スリープ有効化中" : "スリープ無効化中"
    }

    private func present(error: Error) {
        let alert = NSAlert(error: error)
        alert.messageText = "切り替えできませんでした"
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }
}

let application = NSApplication.shared
private let delegate = AppDelegate()
application.delegate = delegate
application.run()
