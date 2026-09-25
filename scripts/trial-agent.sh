#!/bin/bash
# Optional user-session continuation of the five-minute UI trial. No sudo.
set -euo pipefail

label='com.weekpact.youtube-trial-agent'
uid=$(id -u)
destination="$HOME/Library/Application Support/WeekPact"
bundle="$destination/WeekPactTrialAgent.app"
executable="$bundle/Contents/MacOS/WeekPactTrialAgent"
plist="$HOME/Library/LaunchAgents/$label.plist"
domain="gui/$uid"

xml_escape() {
    sed -e 's/\&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'
}

case "${1:-}" in
    install)
        cd "$(dirname "$0")/.."
        swift build -c release --product WeekPactTrialAgent
        built="$(swift build -c release --show-bin-path)/WeekPactTrialAgent"
        if launchctl print "$domain/$label" >/dev/null 2>&1; then
            launchctl bootout "$domain/$label"
        fi
        mkdir -p "$bundle/Contents/MacOS" "$(dirname "$plist")"
        install -m 0755 "$built" "$executable"
        cat > "$bundle/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.pandeydeep9.WeekPact.TrialAgent</string>
<key>CFBundleExecutable</key><string>WeekPactTrialAgent</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>NSAppleEventsUsageDescription</key><string>Continue the five-minute YouTube browser trial when the WeekPact window is closed.</string>
</dict></plist>
PLIST
        plutil -lint "$bundle/Contents/Info.plist" >/dev/null
        codesign --force --sign - "$bundle"
        encoded_executable=$(printf '%s' "$executable" | xml_escape)
        encoded_log=$(printf '%s' "$destination/trial-agent.log" | xml_escape)
        cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>$label</string>
<key>ProgramArguments</key><array><string>$encoded_executable</string></array>
<key>RunAtLoad</key><true/>
<key>KeepAlive</key><true/>
<key>StandardErrorPath</key><string>$encoded_log</string>
</dict></plist>
PLIST
        plutil -lint "$plist" >/dev/null
        launchctl bootstrap "$domain" "$plist"
        launchctl print "$domain/$label" >/dev/null
        echo 'Trial agent installed. Start the five-minute trial in the UI, then quit the UI and test YouTube in Safari/Chrome.'
        echo 'Approve any browser Automation prompt for the WeekPact trial agent; check ~/Library/Application Support/WeekPact/trial-agent.log if it fails.'
        ;;
    status)
        if launchctl print "$domain/$label" 2>/dev/null | grep -q 'state = running'; then
            echo 'Trial agent is running.'
        elif launchctl print "$domain/$label" >/dev/null 2>&1; then
            echo 'Trial agent is registered but not running; check the log.'
        else
            echo 'Trial agent is not registered.'
        fi
        ;;
    remove)
        if launchctl print "$domain/$label" >/dev/null 2>&1; then
            launchctl bootout "$domain/$label"
        fi
        rm -f "$plist"
        rm -rf "$bundle"
        echo 'Trial agent removed. The UI trial remains available.'
        ;;
    *)
        echo 'Usage: bash scripts/trial-agent.sh install|status|remove' >&2
        exit 2
        ;;
esac
