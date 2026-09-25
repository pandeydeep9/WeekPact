#!/bin/bash
# Test an independent, local macOS block without WeekPact's restricted Network Extension.
set -euo pipefail

cli=/Applications/SelfControl.app/Contents/MacOS/selfcontrol-cli
blocklist=${1:-}

if [[ -z "$blocklist" || ! -f "$blocklist" ]]; then
    echo "Usage: bash scripts/test-local-block.sh /path/to/example-only.selfcontrol" >&2
    echo "Save a blocklist containing only example.com using SelfControl's File > Save Blocklist." >&2
    exit 2
fi
if [[ ! -x "$cli" ]]; then
    echo "Install SelfControl from https://selfcontrolapp.com/ into /Applications first." >&2
    exit 2
fi

running=$("$cli" is-running 2>&1) || {
    echo "$running" >&2
    exit 1
}
if [[ "$running" =~ (^|[[:space:]])YES([[:space:]]|$) ]]; then
    echo "A SelfControl block is already running. Wait for it to expire before testing." >&2
    exit 1
fi

echo "This starts a 2-minute block using the saved file: $blocklist"
echo "Check that the file contains ONLY example.com. SelfControl cannot end a block early."
read -r -p 'Type TEST to start: ' answer
if [[ "$answer" != TEST ]]; then
    echo "Canceled."
    exit 0
fi

# The timestamp includes Z so SelfControl's ISO 8601 parser does not fall back to GUI settings.
end=$(/bin/date -u -v+120S '+%Y-%m-%dT%H:%M:%SZ')
"$cli" start --blocklist "$blocklist" --enddate "$end"
echo "Expected end: $end. Check SelfControl's timer, then test a fresh tab in your browsers."
echo "If the displayed end differs, do not start a longer block."
