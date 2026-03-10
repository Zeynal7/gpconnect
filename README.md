# gpconnect

CLI tool for connecting to GlobalProtect VPN on macOS. Automates the login flow using a Swift helper app and macOS Keychain.

Supports Duo MFA (waits for push approval).

## Features

- Connect/disconnect GlobalProtect from the terminal
- Check connection status
- Credentials stored securely in macOS Keychain
- Interactive first-time setup
- Password update prompt on auth failure
- No hardcoded credentials — fully portable
- Does **not** require giving your terminal Accessibility access

## Requirements

- macOS
- GlobalProtect app installed
- Xcode Command Line Tools (`xcode-select --install`)

## Setup

```bash
# 1. Clone the repo
git clone https://github.com/Zeynal7/gpconnect.git ~/Documents/gpconnect

# 2. Run the install script
cd ~/Documents/gpconnect
./install.sh
```

The install script will:
1. Build a Swift helper app (`GPConnectHelper.app`)
2. Prompt you to add it to **Accessibility** permissions
3. Optionally create a global symlink

## Usage

```bash
gpconnect                 # Connect to VPN
gpconnect -d              # Disconnect
gpconnect -s              # Check status
gpconnect --password      # Update password
gpconnect --username      # Update username
gpconnect --reset         # Remove all config and credentials
gpconnect -h              # Show help
```

## How it works

1. Reads your username from `~/scripts/.gpconnect_config` (created on first run)
2. Reads your password from macOS Keychain (encrypted)
3. Launches `GPConnectHelper.app` as an independent process (not a child of the terminal)
4. The helper opens GlobalProtect's menu bar popup via AppleScript
5. Fills in credentials using `set value` (no keystrokes — secure)
6. Clicks Connect and waits for Duo MFA approval
7. Reports connection status back to the CLI

### Why a Swift helper app?

macOS ties Accessibility permissions to the process that controls the UI. Running AppleScript directly from the terminal requires giving the terminal app Accessibility access — which you may not want (e.g., if AI tools run in your terminal).

The Swift helper app (`GPConnectHelper.app`) runs as an independent process via `open -a`, so only the helper needs Accessibility — not your terminal.

## Security

- Password is stored in **macOS Keychain** (encrypted by the OS)
- Config file only contains your username, with `600` permissions (owner-only)
- No keystrokes — credentials are set via AppleScript `set value` (cannot leak to wrong window)
- No hardcoded credentials in source code
- Terminal does **not** need Accessibility access

## License

MIT
