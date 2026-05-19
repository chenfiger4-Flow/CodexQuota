import AppKit
import Foundation

struct QuotaConfig: Codable {
    var source: String
    var totalQuota: Int?
    var remainingQuota: Int?
    var resetAt: Date?
    var refreshIntervalSeconds: TimeInterval
    var windowDurationSeconds: TimeInterval?
    var proxyURL: String?

    static let fallback = QuotaConfig(
        source: "codexRPC",
        totalQuota: nil,
        remainingQuota: nil,
        resetAt: nil,
        refreshIntervalSeconds: 30,
        windowDurationSeconds: nil,
        proxyURL: nil
    )
}

struct RateLimitWindowSnapshot {
    var label: String
    var remainingPercent: Int
    var usedPercent: Int
    var resetAt: Date

    var countdownText: String {
        let seconds = max(Int(resetAt.timeIntervalSinceNow), 0)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, remainingSeconds)
        }
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    var compactResetTimeText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: resetAt)
    }
}

struct QuotaSnapshot {
    var primary: RateLimitWindowSnapshot?
    var secondary: RateLimitWindowSnapshot?
    var refreshIntervalSeconds: TimeInterval
    var sourceDescription: String
    var planType: String?
    var creditsBalance: String?
    var errorMessage: String?

    static func loading(refreshIntervalSeconds: TimeInterval = 30) -> QuotaSnapshot {
        QuotaSnapshot(
            primary: nil,
            secondary: nil,
            refreshIntervalSeconds: refreshIntervalSeconds,
            sourceDescription: "Codex CLI RPC",
            planType: nil,
            creditsBalance: nil,
            errorMessage: "正在读取"
        )
    }

    static func failure(_ message: String, refreshIntervalSeconds: TimeInterval = 30) -> QuotaSnapshot {
        QuotaSnapshot(
            primary: nil,
            secondary: nil,
            refreshIntervalSeconds: refreshIntervalSeconds,
            sourceDescription: "Codex CLI RPC",
            planType: nil,
            creditsBalance: nil,
            errorMessage: message
        )
    }
}

@MainActor
final class QuotaStatusView: NSView {
    var snapshot = QuotaSnapshot.loading() {
        didSet {
            needsDisplay = true
        }
    }

    var onClick: (() -> Void)?

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 142, height: 28))
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 142, height: 28)
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let bounds = bounds.insetBy(dx: 1, dy: 2)
        backgroundColor.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6).fill()

        drawBrand(in: NSRect(x: 7, y: 5, width: 38, height: 18))
        drawSeparator(x: 50, in: bounds)
        drawMetrics(in: NSRect(x: 57, y: 4, width: bounds.width - 63, height: 20))
    }

    private var backgroundColor: NSColor {
        guard let percent = snapshot.primary?.remainingPercent else {
            return NSColor(calibratedRed: 0.34, green: 0.39, blue: 0.48, alpha: 1)
        }
        if percent <= 10 {
            return NSColor(calibratedRed: 0.70, green: 0.12, blue: 0.16, alpha: 1)
        }
        if percent <= 30 {
            return NSColor(calibratedRed: 0.78, green: 0.39, blue: 0.08, alpha: 1)
        }
        return NSColor(calibratedRed: 0.09, green: 0.45, blue: 0.72, alpha: 1)
    }

    private func drawBrand(in rect: NSRect) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11.5, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        drawCentered("Codex", in: rect, attrs: attrs)
    }

    private func drawSeparator(x: CGFloat, in rect: NSRect) {
        NSColor.white.withAlphaComponent(0.24).setStroke()
        let path = NSBezierPath()
        path.lineWidth = 1
        path.move(to: NSPoint(x: x, y: rect.minY + 4))
        path.line(to: NSPoint(x: x, y: rect.maxY - 4))
        path.stroke()
    }

    private func drawMetrics(in rect: NSRect) {
        let percentColumn = NSRect(x: rect.minX, y: rect.minY, width: 34, height: rect.height)
        let valueColumn = NSRect(x: percentColumn.maxX + 6, y: rect.minY, width: rect.maxX - percentColumn.maxX - 6, height: rect.height)

        let primaryAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        let secondaryAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.white
        ]

        if let primary = snapshot.primary {
            drawRightAligned("\(primary.remainingPercent)%", in: NSRect(x: percentColumn.minX, y: rect.midY, width: percentColumn.width, height: 10), attrs: primaryAttrs)
            drawRightAligned(primary.compactResetTimeText, in: NSRect(x: valueColumn.minX, y: rect.midY, width: valueColumn.width, height: 10), attrs: primaryAttrs)
        } else {
            drawRightAligned("读取", in: NSRect(x: percentColumn.minX, y: rect.midY, width: percentColumn.width, height: 10), attrs: primaryAttrs)
            drawRightAligned("失败", in: NSRect(x: valueColumn.minX, y: rect.midY, width: valueColumn.width, height: 10), attrs: primaryAttrs)
        }

        if let secondary = snapshot.secondary {
            drawRightAligned("\(secondary.remainingPercent)%", in: NSRect(x: percentColumn.minX, y: rect.minY, width: percentColumn.width, height: 10), attrs: secondaryAttrs)
            drawRightAligned(shortDate(secondary.resetAt), in: NSRect(x: valueColumn.minX, y: rect.minY, width: valueColumn.width, height: 10), attrs: secondaryAttrs)
        } else if let errorMessage = snapshot.errorMessage {
            drawRightAligned(shortError(errorMessage), in: NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: 10), attrs: secondaryAttrs)
        }
    }

    private func drawCentered(_ string: String, in rect: NSRect, attrs: [NSAttributedString.Key: Any]) {
        let attributed = NSAttributedString(string: string, attributes: attrs)
        let size = attributed.size()
        attributed.draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2))
    }

    private func drawRightAligned(_ string: String, in rect: NSRect, attrs: [NSAttributedString.Key: Any]) {
        let attributed = NSAttributedString(string: string, attributes: attrs)
        let size = attributed.size()
        attributed.draw(at: NSPoint(x: rect.maxX - size.width, y: rect.midY - size.height / 2))
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }

    private func shortError(_ message: String) -> String {
        if message.contains("超时") {
            return "超时"
        }
        if message.contains("启动") {
            return "启动失败"
        }
        return "错误"
    }
}

final class ConfigStore {
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let searchURLs: [URL]

    init() {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let homeConfig = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex-menubar/config.json")
        let workingConfig = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("config.example.json")
        let bundledConfig = Bundle.main.url(forResource: "config.example", withExtension: "json")
        searchURLs = [homeConfig, workingConfig] + [bundledConfig].compactMap { $0 }
    }

    var primaryConfigURL: URL {
        searchURLs[0]
    }

    func load() -> QuotaConfig {
        for url in searchURLs {
            guard let data = try? Data(contentsOf: url) else { continue }
            do {
                return try decoder.decode(QuotaConfig.self, from: data)
            } catch {
                NSLog("CodexQuotaMenuBar: failed to decode config at \(url.path): \(error)")
            }
        }
        return .fallback
    }

    func ensurePrimaryConfig(using config: QuotaConfig) {
        let directory = primaryConfigURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            guard !FileManager.default.fileExists(atPath: primaryConfigURL.path) else { return }
            let data = try encoder.encode(config)
            try data.write(to: primaryConfigURL, options: .atomic)
        } catch {
            NSLog("CodexQuotaMenuBar: failed to create primary config: \(error)")
        }
    }
}

final class QuotaProvider {
    private let configStore = ConfigStore()
    private let rpcClient = CodexRPCClient()

    var primaryConfigURL: URL {
        configStore.primaryConfigURL
    }

    func load() -> QuotaSnapshot {
        let config = configStore.load()
        return rpcClient.fetchRateLimits(config: config)
    }

    func ensurePrimaryConfig(using snapshot: QuotaSnapshot) {
        let config = QuotaConfig(
            source: "codexRPC",
            totalQuota: nil,
            remainingQuota: nil,
            resetAt: nil,
            refreshIntervalSeconds: snapshot.refreshIntervalSeconds,
            windowDurationSeconds: nil,
            proxyURL: nil
        )
        configStore.ensurePrimaryConfig(using: config)
    }
}

final class RPCReadState: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()
    private var responses: [Int: [String: Any]] = [:]
    private var waiters: [Int: DispatchSemaphore] = [:]

    func registerWaiter(for id: Int, semaphore: DispatchSemaphore) {
        lock.lock()
        defer { lock.unlock() }
        waiters[id] = semaphore
    }

    func append(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }

        buffer.append(data)
        while let newlineRange = buffer.firstRange(of: Data([0x0A])) {
            let lineData = buffer.subdata(in: buffer.startIndex..<newlineRange.lowerBound)
            buffer.removeSubrange(buffer.startIndex...newlineRange.lowerBound)
            guard !lineData.isEmpty else { continue }

            guard
                let object = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                let id = object["id"] as? Int
            else {
                continue
            }

            responses[id] = object
            waiters[id]?.signal()
        }
    }

    func takeResponse(for id: Int) -> [String: Any]? {
        lock.lock()
        defer { lock.unlock() }
        waiters[id] = nil
        return responses.removeValue(forKey: id)
    }

    func reset() {
        lock.lock()
        let currentWaiters = waiters.values
        buffer.removeAll()
        responses.removeAll()
        waiters.removeAll()
        lock.unlock()

        for waiter in currentWaiters {
            waiter.signal()
        }
    }
}

final class CodexRPCClient: @unchecked Sendable {
    private let timeoutSeconds: TimeInterval = 25
    private let codexExecutableURL: URL
    private let processPath: String
    private let logURL: URL
    private let lock = NSLock()
    private let readState = RPCReadState()
    private var process: Process?
    private var inputPipe: Pipe?
    private var nextRequestId = 1
    private var activeProxyURL: String?

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        logURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex-menubar/rpc.log")
        let candidates = [
            "\(home)/.npm-global/bin/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "/usr/bin/codex"
        ]

        if let path = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            codexExecutableURL = URL(fileURLWithPath: path)
            processPath = path
        } else {
            codexExecutableURL = URL(fileURLWithPath: "/usr/bin/env")
            processPath = "codex"
        }
    }

    deinit {
        stopProcess()
    }

    func fetchRateLimits(config: QuotaConfig) -> QuotaSnapshot {
        do {
            try ensureProcess(proxyURL: config.proxyURL)
            let response = try request(method: "account/rateLimits/read", params: nil)
            return parseSnapshot(response, refreshIntervalSeconds: config.refreshIntervalSeconds)
        } catch {
            stopProcess()
            do {
                try ensureProcess(proxyURL: config.proxyURL)
                let response = try request(method: "account/rateLimits/read", params: nil)
                return parseSnapshot(response, refreshIntervalSeconds: config.refreshIntervalSeconds)
            } catch {
                return .failure(error.localizedDescription, refreshIntervalSeconds: config.refreshIntervalSeconds)
            }
        }
    }

    private func ensureProcess(proxyURL: String?) throws {
        let normalizedProxyURL = normalizeProxyURL(proxyURL)

        lock.lock()
        let runningProcess = process
        let runningProxyURL = activeProxyURL
        lock.unlock()

        if runningProcess?.isRunning == true, runningProxyURL == normalizedProxyURL {
            return
        }

        if runningProcess?.isRunning == true {
            stopProcess()
        }

        try startProcess(proxyURL: normalizedProxyURL)
        _ = try request(
            method: "initialize",
            params: [
                "clientInfo": [
                    "name": "codex-quota-menubar",
                    "version": "0.2.0"
                ],
                "capabilities": [
                    "experimentalApi": true,
                    "optOutNotificationMethods": []
                ]
            ]
        )
        try notification(method: "initialized")
    }

    private func startProcess(proxyURL: String?) throws {
        try prepareLog()
        appendLog("starting \(processPath)")

        let newProcess = Process()
        newProcess.executableURL = codexExecutableURL
        let rpcArguments = [
            "--disable", "plugins",
            "--disable", "remote_plugin",
            "--disable", "tool_suggest",
            "-s", "read-only",
            "-a", "untrusted",
            "app-server"
        ]
        if codexExecutableURL.path == "/usr/bin/env" {
            newProcess.arguments = ["codex"] + rpcArguments
        } else {
            newProcess.arguments = rpcArguments
        }
        newProcess.environment = rpcEnvironment(proxyURL: proxyURL)

        let newInputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        newProcess.standardInput = newInputPipe
        newProcess.standardOutput = outputPipe
        newProcess.standardError = errorPipe
        newProcess.terminationHandler = { [weak self] _ in
            self?.appendLog("codex app-server terminated")
            self?.readState.reset()
        }

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.readState.append(data)
        }
        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.appendLog("codex app-server stderr omitted (\(data.count) bytes)")
        }

        do {
            try newProcess.run()
        } catch {
            appendLog("run failed: \(error.localizedDescription)")
            throw RPCError("无法启动 \(processPath)")
        }

        lock.lock()
        process = newProcess
        inputPipe = newInputPipe
        activeProxyURL = proxyURL
        lock.unlock()
    }

    private func request(method: String, params: Any?) throws -> [String: Any] {
        let id = nextId()
        appendLog("request \(id): \(method)")
        let semaphore = DispatchSemaphore(value: 0)
        readState.registerWaiter(for: id, semaphore: semaphore)

        var object: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id,
            "method": method
        ]
        if let params {
            object["params"] = params
        }

        try send(object)

        let result = semaphore.wait(timeout: .now() + timeoutSeconds)
        let response = readState.takeResponse(for: id)
        guard result == .success, let response else {
            appendLog("request \(id) timeout: \(method)")
            throw RPCError("读取超时")
        }
        appendLog("response \(id): \(method)")
        return response
    }

    private func notification(method: String) throws {
        try send([
            "jsonrpc": "2.0",
            "method": method
        ])
    }

    private func parseSnapshot(_ response: [String: Any], refreshIntervalSeconds: TimeInterval) -> QuotaSnapshot {
        if let error = response["error"] as? [String: Any] {
            let message = error["message"] as? String ?? "读取失败"
            return .failure(message, refreshIntervalSeconds: refreshIntervalSeconds)
        }

        guard
            let resultObject = response["result"] as? [String: Any],
            let rateLimits = resultObject["rateLimits"] as? [String: Any]
        else {
            return .failure("响应格式不匹配", refreshIntervalSeconds: refreshIntervalSeconds)
        }

        return QuotaSnapshot(
            primary: parseWindow(rateLimits["primary"], fallbackLabel: "5 小时"),
            secondary: parseWindow(rateLimits["secondary"], fallbackLabel: "1 周"),
            refreshIntervalSeconds: refreshIntervalSeconds,
            sourceDescription: "Codex CLI RPC",
            planType: rateLimits["planType"] as? String,
            creditsBalance: parseCreditsBalance(rateLimits["credits"]),
            errorMessage: nil
        )
    }

    private func send(_ object: [String: Any]) throws {
        guard let data = try? JSONSerialization.data(withJSONObject: object) else {
            throw RPCError("请求编码失败")
        }

        lock.lock()
        let pipe = inputPipe
        lock.unlock()

        guard let pipe else {
            throw RPCError("RPC 未启动")
        }

        pipe.fileHandleForWriting.write(data)
        pipe.fileHandleForWriting.write(Data([0x0A]))
    }

    private func nextId() -> Int {
        lock.lock()
        defer { lock.unlock() }
        nextRequestId += 1
        return nextRequestId
    }

    private func stopProcess() {
        lock.lock()
        let currentProcess = process
        process = nil
        inputPipe = nil
        activeProxyURL = nil
        lock.unlock()

        readState.reset()
        currentProcess?.terminate()
    }

    private func prepareLog() throws {
        let directory = logURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }
    }

    private func appendLog(_ message: String) {
        let line = "[\(Date())] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        do {
            try prepareLog()
            let handle = try FileHandle(forWritingTo: logURL)
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.close()
        } catch {
            NSLog("CodexQuotaMenuBar: failed to write RPC log: \(error)")
        }
    }

    private func rpcEnvironment(proxyURL: String?) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let existingPath = environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        let extraPaths = [
            "\(home)/.npm-global/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ]
        environment["PATH"] = (extraPaths + [existingPath]).joined(separator: ":")
        environment["HOME"] = home
        if let proxyURL {
            environment["HTTP_PROXY"] = proxyURL
            environment["HTTPS_PROXY"] = proxyURL
            environment["ALL_PROXY"] = proxyURL
            environment["http_proxy"] = proxyURL
            environment["https_proxy"] = proxyURL
            environment["all_proxy"] = proxyURL
            appendLog("using proxy \(redactedProxyURL(proxyURL))")
        }
        return environment
    }

    private func normalizeProxyURL(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func redactedProxyURL(_ value: String) -> String {
        guard var components = URLComponents(string: value) else {
            return "<configured>"
        }
        if components.password != nil {
            components.password = "***"
        }
        return components.string ?? "<configured>"
    }

    private func parseWindow(_ value: Any?, fallbackLabel: String) -> RateLimitWindowSnapshot? {
        guard
            let object = value as? [String: Any],
            let usedPercent = object["usedPercent"] as? Int,
            let resetsAt = object["resetsAt"] as? Int
        else {
            return nil
        }

        let durationMinutes = object["windowDurationMins"] as? Int
        return RateLimitWindowSnapshot(
            label: label(for: durationMinutes) ?? fallbackLabel,
            remainingPercent: max(0, min(100, 100 - usedPercent)),
            usedPercent: max(0, min(100, usedPercent)),
            resetAt: Date(timeIntervalSince1970: TimeInterval(resetsAt))
        )
    }

    private func label(for durationMinutes: Int?) -> String? {
        guard let durationMinutes else { return nil }
        if durationMinutes % 10_080 == 0 {
            return "\(durationMinutes / 10_080) 周"
        }
        if durationMinutes % 60 == 0 {
            return "\(durationMinutes / 60) 小时"
        }
        return "\(durationMinutes) 分钟"
    }

    private func parseCreditsBalance(_ value: Any?) -> String? {
        guard let object = value as? [String: Any] else { return nil }
        if object["unlimited"] as? Bool == true {
            return "无限"
        }
        return object["balance"] as? String
    }
}

struct RPCError: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let statusView = QuotaStatusView()
    private let quotaProvider = QuotaProvider()
    private var snapshot = QuotaSnapshot.loading()
    private var timer: Timer?
    private var menu: NSMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem.length = statusView.intrinsicContentSize.width
        installStatusView()
        reloadConfig()
        rebuildMenu()
        startTimer()
    }

    private func installStatusView() {
        guard let button = statusItem.button else { return }
        button.title = ""
        button.image = nil
        button.addSubview(statusView)
        statusView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            statusView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            statusView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            statusView.topAnchor.constraint(equalTo: button.topAnchor),
            statusView.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(handleTimer(_:)),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer!, forMode: .common)
    }

    @objc private func handleTimer(_ timer: Timer) {
        tick()
    }

    private func tick() {
        updateTitle()

        let now = Date()
        let interval = max(5, snapshot.refreshIntervalSeconds)
        if Int(now.timeIntervalSince1970) % Int(interval) == 0 {
            let previous = snapshot
            snapshot = quotaProvider.load()
            if previous.primary?.remainingPercent != snapshot.primary?.remainingPercent ||
                previous.primary?.resetAt != snapshot.primary?.resetAt ||
                previous.secondary?.remainingPercent != snapshot.secondary?.remainingPercent ||
                previous.errorMessage != snapshot.errorMessage {
                rebuildMenu()
            }
        }
    }

    @objc private func reloadConfig() {
        snapshot = quotaProvider.load()
        updateStatusView()
    }

    private func updateTitle() {
        updateStatusView()
    }

    private func updateStatusView() {
        statusView.snapshot = snapshot
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        if let primary = snapshot.primary {
            menu.addItem(disabledItem("\(primary.label)：剩余 \(primary.remainingPercent)%"))
            menu.addItem(disabledItem("\(primary.label)：已用 \(primary.usedPercent)%"))
            menu.addItem(disabledItem("\(primary.label)：完整重置 \(formatDate(primary.resetAt))"))
        } else {
            menu.addItem(disabledItem("5 小时：\(snapshot.errorMessage ?? "无数据")"))
        }

        if let secondary = snapshot.secondary {
            menu.addItem(disabledItem("\(secondary.label)：剩余 \(secondary.remainingPercent)% · \(formatDateShort(secondary.resetAt))"))
            menu.addItem(disabledItem("\(secondary.label)：已用 \(secondary.usedPercent)%"))
        }

        if let planType = snapshot.planType {
            menu.addItem(disabledItem("计划：\(planType)"))
        }
        if let creditsBalance = snapshot.creditsBalance {
            menu.addItem(disabledItem("Credits：\(creditsBalance)"))
        }
        menu.addItem(disabledItem("来源：\(snapshot.sourceDescription)"))
        if let errorMessage = snapshot.errorMessage {
            menu.addItem(disabledItem("状态：\(errorMessage)"))
        }
        menu.addItem(.separator())

        let refreshItem = NSMenuItem(title: "刷新配置", action: #selector(handleRefresh), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let openConfigItem = NSMenuItem(title: "在访达中显示配置文件", action: #selector(handleRevealConfig), keyEquivalent: "o")
        openConfigItem.target = self
        menu.addItem(openConfigItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        self.menu = menu
        statusItem.menu = menu
        updateStatusView()
    }

    @objc private func handleRefresh() {
        reloadConfig()
        rebuildMenu()
    }

    @objc private func handleRevealConfig() {
        quotaProvider.ensurePrimaryConfig(using: snapshot)
        NSWorkspace.shared.activateFileViewerSelecting([quotaProvider.primaryConfigURL])
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func titleText() -> String {
        guard let primary = snapshot.primary else {
            return "Codex 读取中"
        }
        if primary.resetAt <= Date() {
            return "Codex 待刷新"
        }
        return "Codex \(primary.remainingPercent)% · \(primary.countdownText)"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    private func formatNumber(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func formatDateShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.setLocalizedDateFormatFromTemplate("Md")
        return formatter.string(from: date)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
