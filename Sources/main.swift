import Foundation
import AppKit

// Handle SIGTERM/SIGINT — exit cleanly when parent bash script is interrupted
signal(SIGTERM) { _ in exit(0) }
signal(SIGINT) { _ in exit(0) }

let scriptsDir = NSHomeDirectory() + "/scripts/"
let configFile = scriptsDir + ".gpconnect_config"
let resultFile = scriptsDir + ".gpconnect_result"

// Read mode from args or mode file
var mode = "connect"
if CommandLine.arguments.count > 1 {
    mode = CommandLine.arguments[1]
} else {
    let modeFile = scriptsDir + ".gpconnect_mode"
    if let modeStr = try? String(contentsOfFile: modeFile, encoding: .utf8) {
        mode = modeStr.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

func writeResult(_ text: String) {
    try? text.write(toFile: resultFile, atomically: true, encoding: .utf8)
}

func runAppleScript(_ source: String) -> (Bool, String) {
    var error: NSDictionary?
    let script = NSAppleScript(source: source)
    let result = script?.executeAndReturnError(&error)
    if let error = error {
        let msg = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
        return (false, msg)
    }
    return (true, result?.stringValue ?? "")
}

func isWindowOpen() -> Bool {
    let (ok, _) = runAppleScript("""
        tell application "System Events"
            tell process "GlobalProtect"
                get window 1
            end tell
        end tell
    """)
    return ok
}

func openWindow() -> Bool {
    // If already open, just return true
    if isWindowOpen() { return true }
    for _ in 0..<3 {
        _ = runAppleScript("""
            tell application "System Events"
                tell process "GlobalProtect"
                    click menu bar item 1 of menu bar 2
                end tell
            end tell
        """)
        Thread.sleep(forTimeInterval: 1.5)
        if isWindowOpen() { return true }
        Thread.sleep(forTimeInterval: 0.5)
    }
    return false
}

func closeWindow() {
    // Only click if the window is actually open
    if !isWindowOpen() { return }
    _ = runAppleScript("""
        tell application "System Events"
            tell process "GlobalProtect"
                click menu bar item 1 of menu bar 2
            end tell
        end tell
    """)
}

func getStatus() -> String {
    let (_, result) = runAppleScript("""
        tell application "System Events"
            tell process "GlobalProtect"
                return value of static text 1 of window 1
            end tell
        end tell
    """)
    return result
}

// --- Status ---
if mode == "status" {
    if !openWindow() { writeResult("WINDOW_ERROR"); exit(0) }
    let status = getStatus()
    closeWindow()
    writeResult(status)
    exit(0)
}

// --- Disconnect ---
if mode == "disconnect" {
    if !openWindow() { writeResult("WINDOW_ERROR"); exit(0) }
    let status = getStatus()
    if status != "Connected" {
        closeWindow()
        writeResult("NOT_CONNECTED")
        exit(0)
    }
    _ = runAppleScript("""
        tell application "System Events"
            tell process "GlobalProtect"
                click button "Disconnect" of window 1
            end tell
        end tell
    """)
    Thread.sleep(forTimeInterval: 3)
    if !openWindow() { writeResult("FAILED"); exit(0) }
    let newStatus = getStatus()
    closeWindow()
    writeResult(newStatus == "Not Connected" ? "DISCONNECTED" : "FAILED")
    exit(0)
}

// --- Connect ---
let isCLI = mode == "cli"

// Read config
guard let configData = try? String(contentsOfFile: configFile, encoding: .utf8),
      let accountLine = configData.components(separatedBy: "\n").first(where: { $0.contains("GP_ACCOUNT") }) else {
    if isCLI { writeResult("NO_CONFIG") }
    exit(0)
}
let gpAccount = accountLine
    .replacingOccurrences(of: "GP_ACCOUNT=", with: "")
    .replacingOccurrences(of: "\"", with: "")
    .trimmingCharacters(in: .whitespacesAndNewlines)

// Read password from Keychain
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/security")
task.arguments = ["find-generic-password", "-a", gpAccount, "-s", "GlobalProtect", "-w"]
let pipe = Pipe()
task.standardOutput = pipe
task.standardError = FileHandle.nullDevice
do {
    try task.run()
    task.waitUntilExit()
} catch {
    if isCLI { writeResult("NO_PASSWORD") }
    exit(0)
}
let gpPass = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
if gpPass.isEmpty {
    if isCLI { writeResult("NO_PASSWORD") }
    exit(0)
}

// Open and check status
if !openWindow() {
    if isCLI { writeResult("WINDOW_ERROR") }
    exit(0)
}
let currentStatus = getStatus()
if currentStatus == "Connected" {
    closeWindow()
    if isCLI { writeResult("ALREADY_CONNECTED") }
    exit(0)
}

// Click Connect on initial screen, fill credentials
let escapedAccount = gpAccount.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
let escapedPass = gpPass.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
_ = runAppleScript("""
    tell application "System Events"
        tell process "GlobalProtect"
            try
                click button "Connect" of window 1
                delay 2
            end try
            set value of text field 1 of window 1 to "\(escapedAccount)"
            set value of text field 2 of window 1 to "\(escapedPass)"
            delay 0.5
            click button "Connect" of window 1
        end tell
    end tell
""")

// Close the window before waiting — don't keep toggling during Duo wait
Thread.sleep(forTimeInterval: 2)
closeWindow()

// Wait for connection (up to 60 seconds)
// Poll by briefly opening the window, reading status, and closing
for _ in 0..<12 {
    Thread.sleep(forTimeInterval: 5)
    if openWindow() {
        let status = getStatus()
        closeWindow()
        if status == "Connected" {
            if isCLI { writeResult("CONNECTED") }
            exit(0)
        } else if status.contains("Authentication Failed") {
            if isCLI { writeResult("AUTH_FAILED") }
            exit(0)
        }
    }
}

if isCLI { writeResult("TIMEOUT") }
