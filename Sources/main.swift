import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private enum Duration: Hashable {
        case interval(TimeInterval)
        case indefinite

        static let presets: [Duration] = [
            .interval(60),
            .interval(15 * 60),
            .interval(30 * 60),
            .interval(60 * 60),
            .indefinite,
        ]

        static func from(seconds: TimeInterval) -> Duration {
            seconds > 0 ? .interval(seconds) : .indefinite
        }

        var seconds: TimeInterval? {
            switch self {
            case .interval(let seconds): seconds
            case .indefinite: nil
            }
        }

        var title: String {
            switch self {
            case .interval(let seconds):
                let minutes = Int(seconds / 60)
                return minutes % 60 == 0 ? "\(minutes / 60) 小时" : "\(minutes) 分钟"
            case .indefinite:
                return "无限期"
            }
        }
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let statusMenuItem = NSMenuItem()
    private let remainingMenuItem = NSMenuItem()
    private let toggleMenuItem = NSMenuItem()
    private let durationMenuItem = NSMenuItem()
    private let customDurationMenuItem = NSMenuItem()
    private let sleepDisplayMenuItem = NSMenuItem()
    private let closedDisplayMenuItem = NSMenuItem()
    private var customDurationWindow: NSWindow?
    private var customDurationField: NSTextField?
    private var durationMenuItems: [Duration: NSMenuItem] = [:]
    private var caffeinateProcess: Process?
    private var expirationDate: Date?
    private var ticker: Timer?
    private var duration: Duration
    private var sleepDisplayOnTimeout: Bool
    private var keepAwakeWhenLidClosed: Bool

    override init() {
        let defaults = UserDefaults.standard
        if let savedSeconds = defaults.object(forKey: "durationSeconds") as? Double {
            duration = Duration.from(seconds: savedSeconds)
        } else {
            let legacyDurations: [String: TimeInterval] = [
                "1 分钟": 60,
                "15 分钟": 15 * 60,
                "30 分钟": 30 * 60,
                "1 小时": 60 * 60,
            ]
            let legacyDuration = defaults.string(forKey: "duration")
            duration = legacyDuration.flatMap { legacyDurations[$0] }.map(Duration.interval) ?? .indefinite
        }
        sleepDisplayOnTimeout = defaults.object(forKey: "sleepDisplayOnTimeout") as? Bool ?? true
        keepAwakeWhenLidClosed = defaults.object(forKey: "keepAwakeWhenLidClosed") as? Bool ?? true
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

        let durationMenu = NSMenu()
        for duration in Duration.presets {
            let item = NSMenuItem(title: duration.title, action: #selector(selectDuration(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = NSNumber(value: duration.seconds ?? 0)
            durationMenuItems[duration] = item
            durationMenu.addItem(item)
        }
        durationMenu.addItem(.separator())
        customDurationMenuItem.title = "自定义时长…"
        customDurationMenuItem.target = self
        customDurationMenuItem.action = #selector(presentCustomDurationDialog)
        durationMenu.addItem(customDurationMenuItem)
        durationMenuItem.submenu = durationMenu
        menu.addItem(durationMenuItem)

        sleepDisplayMenuItem.target = self
        sleepDisplayMenuItem.action = #selector(toggleSleepDisplayOnTimeout)
        menu.addItem(sleepDisplayMenuItem)

        closedDisplayMenuItem.target = self
        closedDisplayMenuItem.action = #selector(toggleClosedDisplayMode)
        menu.addItem(closedDisplayMenuItem)
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

    @objc private func toggleSleepDisplayOnTimeout() {
        sleepDisplayOnTimeout.toggle()
        UserDefaults.standard.set(sleepDisplayOnTimeout, forKey: "sleepDisplayOnTimeout")
        updateInterface()
    }

    @objc private func toggleClosedDisplayMode() {
        let wasActive = caffeinateProcess != nil
        let previousExpirationDate = expirationDate
        if wasActive {
            stopKeepingAwake()
        }

        keepAwakeWhenLidClosed.toggle()
        UserDefaults.standard.set(keepAwakeWhenLidClosed, forKey: "keepAwakeWhenLidClosed")

        if wasActive {
            startKeepingAwake()
            if caffeinateProcess != nil, let previousExpirationDate {
                expirationDate = previousExpirationDate
                startTicker()
            }
        } else {
            updateInterface()
        }
    }

    @objc private func selectDuration(_ sender: NSMenuItem) {
        guard let seconds = sender.representedObject as? NSNumber else { return }
        setDuration(.from(seconds: seconds.doubleValue))
    }

    @objc private func presentCustomDurationDialog() {
        if let customDurationWindow {
            customDurationWindow.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 156),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "自定义保持时长"
        window.isReleasedWhenClosed = false
        window.delegate = self

        let contentView = NSView(frame: window.contentRect(forFrameRect: window.frame))
        let label = NSTextField(labelWithString: "保持时长（分钟）")
        label.frame = NSRect(x: 20, y: 108, width: 280, height: 20)
        contentView.addSubview(label)

        let input = NSTextField(frame: NSRect(x: 20, y: 72, width: 280, height: 24))
        input.placeholderString = "例如：90"
        input.stringValue = String(Int((duration.seconds ?? 3600) / 60))
        contentView.addSubview(input)

        let hint = NSTextField(labelWithString: "可输入 1–10080 之间的整数")
        hint.frame = NSRect(x: 20, y: 46, width: 280, height: 20)
        hint.textColor = .secondaryLabelColor
        hint.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        contentView.addSubview(hint)

        let cancelButton = NSButton(title: "取消", target: self, action: #selector(closeCustomDurationDialog))
        cancelButton.frame = NSRect(x: 108, y: 10, width: 90, height: 28)
        cancelButton.keyEquivalent = "\u{1b}"
        contentView.addSubview(cancelButton)

        let confirmButton = NSButton(title: "确定", target: self, action: #selector(confirmCustomDuration))
        confirmButton.frame = NSRect(x: 208, y: 10, width: 90, height: 28)
        confirmButton.keyEquivalent = "\r"
        contentView.addSubview(confirmButton)

        window.contentView = contentView
        window.center()
        customDurationWindow = window
        customDurationField = input
        NSApplication.shared.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeFirstResponder(input)
    }

    @objc private func confirmCustomDuration() {
        guard let input = customDurationField else { return }
        let value = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let minutes = Int(value), (1...10080).contains(minutes) else {
            presentError("请输入 1–10080 之间的整数分钟数。")
            return
        }
        setDuration(.interval(TimeInterval(minutes * 60)))
        closeCustomDurationDialog()
    }

    @objc private func closeCustomDurationDialog() {
        customDurationWindow?.close()
    }

    func windowWillClose(_ notification: Notification) {
        customDurationWindow = nil
        customDurationField = nil
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    private func setDuration(_ newDuration: Duration) {
        duration = newDuration
        UserDefaults.standard.set(duration.seconds ?? 0, forKey: "durationSeconds")
        configureExpirationDate()
        updateInterface()
    }

    private func startKeepingAwake() {
        guard caffeinateProcess == nil else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        let assertions = keepAwakeWhenLidClosed ? "-dis" : "-di"
        process.arguments = [assertions, "-w", String(ProcessInfo.processInfo.processIdentifier)]
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
            if sleepDisplayOnTimeout {
                sleepDisplay()
            }
        } else {
            updateInterface()
        }
    }

    private func sleepDisplay() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["displaysleepnow"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { [weak self] terminatedProcess in
            guard terminatedProcess.terminationStatus != 0 else { return }
            DispatchQueue.main.async {
                self?.presentError("无法让显示器息屏。")
            }
        }

        do {
            try process.run()
        } catch {
            presentError("无法让显示器息屏：\(error.localizedDescription)")
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
        durationMenuItem.title = "保持时长：\(duration.title)"
        customDurationMenuItem.state = durationMenuItems[duration] == nil ? .on : .off
        sleepDisplayMenuItem.title = "到时自动息屏"
        sleepDisplayMenuItem.toolTip = "不主动锁屏；系统密码策略仍可能在息屏后锁定"
        sleepDisplayMenuItem.state = sleepDisplayOnTimeout ? .on : .off
        closedDisplayMenuItem.title = "合盖保持唤醒（需接电源）"
        closedDisplayMenuItem.toolTip = "阻止系统合盖睡眠；内置显示屏在合盖后会关闭"
        closedDisplayMenuItem.state = keepAwakeWhenLidClosed ? .on : .off

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
