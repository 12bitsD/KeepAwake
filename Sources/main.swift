import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private enum Duration: String, CaseIterable {
        case oneMinute = "1 分钟"
        case fifteenMinutes = "15 分钟"
        case thirtyMinutes = "30 分钟"
        case oneHour = "1 小时"
        case indefinite = "无限期"

        var seconds: TimeInterval? {
            switch self {
            case .oneMinute: 60
            case .fifteenMinutes: 15 * 60
            case .thirtyMinutes: 30 * 60
            case .oneHour: 60 * 60
            case .indefinite: nil
            }
        }
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let statusMenuItem = NSMenuItem()
    private let remainingMenuItem = NSMenuItem()
    private let toggleMenuItem = NSMenuItem()
    private var durationMenuItems: [Duration: NSMenuItem] = [:]
    private var caffeinateProcess: Process?
    private var expirationDate: Date?
    private var ticker: Timer?
    private var duration: Duration

    override init() {
        let savedDuration = UserDefaults.standard.string(forKey: "duration")
        duration = Duration(rawValue: savedDuration ?? "") ?? .indefinite
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMenu()
        updateInterface()
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopKeepingAwake()
    }

    private func configureMenu() {
        let menu = NSMenu()
        statusItem.menu = menu

        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        remainingMenuItem.isEnabled = false
        remainingMenuItem.isHidden = true
        menu.addItem(remainingMenuItem)
        menu.addItem(.separator())

        toggleMenuItem.target = self
        toggleMenuItem.action = #selector(toggleKeepingAwake)
        menu.addItem(toggleMenuItem)

        let durationItem = NSMenuItem(title: "保持时长", action: nil, keyEquivalent: "")
        let durationMenu = NSMenu()
        for duration in Duration.allCases {
            let item = NSMenuItem(title: duration.rawValue, action: #selector(selectDuration(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = duration.rawValue
            durationMenuItems[duration] = item
            durationMenu.addItem(item)
        }
        durationItem.submenu = durationMenu
        menu.addItem(durationItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出不熄屏", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
    }

    @objc private func toggleKeepingAwake() {
        if caffeinateProcess == nil {
            startKeepingAwake()
        } else {
            stopKeepingAwake()
        }
    }

    @objc private func selectDuration(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let selectedDuration = Duration(rawValue: rawValue)
        else {
            return
        }

        duration = selectedDuration
        UserDefaults.standard.set(rawValue, forKey: "duration")
        configureExpirationDate()
        updateInterface()
    }

    private func startKeepingAwake() {
        guard caffeinateProcess == nil else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        process.arguments = ["-di", "-w", String(ProcessInfo.processInfo.processIdentifier)]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { [weak self] terminatedProcess in
            DispatchQueue.main.async {
                guard let self, self.caffeinateProcess === terminatedProcess else { return }
                self.caffeinateProcess = nil
                self.expirationDate = nil
                self.stopTicker()
                self.updateInterface()
            }
        }

        do {
            try process.run()
            caffeinateProcess = process
            configureExpirationDate()
            updateInterface()
        } catch {
            presentError("无法开启防熄屏：\(error.localizedDescription)")
        }
    }

    private func stopKeepingAwake() {
        expirationDate = nil
        stopTicker()

        if let process = caffeinateProcess {
            caffeinateProcess = nil
            if process.isRunning {
                process.terminate()
            }
        }
        updateInterface()
    }

    private func configureExpirationDate() {
        if let seconds = duration.seconds, caffeinateProcess != nil {
            expirationDate = Date().addingTimeInterval(seconds)
            startTicker()
        } else {
            expirationDate = nil
            stopTicker()
        }
    }

    private func startTicker() {
        stopTicker()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        if let expirationDate, Date() >= expirationDate {
            stopKeepingAwake()
        } else {
            updateInterface()
        }
    }

    private func updateInterface() {
        let isActive = caffeinateProcess != nil
        let symbolName = isActive ? "cup.and.saucer.fill" : "cup.and.saucer"
        statusItem.button?.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "不熄屏")
        statusItem.button?.image?.isTemplate = true
        statusItem.button?.toolTip = isActive ? "不熄屏：保持唤醒中" : "不熄屏：已关闭"

        statusMenuItem.title = isActive ? "状态：保持唤醒中" : "状态：已关闭"
        toggleMenuItem.title = isActive ? "关闭防熄屏" : "开启防熄屏"

        if let expirationDate {
            let remainingSeconds = max(0, Int(expirationDate.timeIntervalSinceNow.rounded(.up)))
            let hours = remainingSeconds / 3600
            let minutes = (remainingSeconds % 3600) / 60
            let seconds = remainingSeconds % 60
            remainingMenuItem.title = hours > 0
                ? String(format: "剩余：%d:%02d:%02d", hours, minutes, seconds)
                : String(format: "剩余：%02d:%02d", minutes, seconds)
            remainingMenuItem.isHidden = false
        } else {
            remainingMenuItem.isHidden = true
        }

        for (duration, item) in durationMenuItems {
            item.state = duration == self.duration ? .on : .off
        }
    }

    private func presentError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "不熄屏"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "好")
        NSApplication.shared.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
