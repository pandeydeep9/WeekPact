#!/bin/bash
# WeekPact's own two-minute hosts-file blocking spike for macOS.
# Installed as a root-owned launchd job so expiry is checked after a reboot.
set -euo pipefail
PATH=/usr/bin:/bin:/usr/sbin:/sbin

directory='/Library/Application Support/WeekPact'
installed="$directory/local-blocker.sh"
expires="$directory/trial-expires"
job='/Library/LaunchDaemons/com.weekpact.local-blocker.plist'
hosts='/etc/hosts'
begin='# BEGIN WEEKPACT LOCAL TEST'
end='# END WEEKPACT LOCAL TEST'

if [[ $(id -u) != 0 ]]; then
    echo 'Run with sudo: sudo bash scripts/test-weekpact-block.sh trial [youtube|example]' >&2
    exit 1
fi

refresh() {
    local now expiry selected domains active starts ends start_line end_line temporary cleaned policy
    now=$(date +%s)
    active=0
    if [[ -f "$expires" ]]; then
        policy=$(cat "$expires")
        read -r expiry selected <<< "$policy"
        selected=${selected:-example} # The original example-only test stored just a timestamp.
        if [[ "$expiry" =~ ^[0-9]+$ ]] && (( now < expiry )); then
            case "$selected" in
                example) domains='example.com www.example.com' ;;
                youtube) domains='youtube.com www.youtube.com m.youtube.com music.youtube.com youtu.be' ;;
                *) echo 'Invalid WeekPact trial site; leaving /etc/hosts untouched.' >&2; exit 1 ;;
            esac
            active=1
        fi
    fi

    # Leave a hosts file with an unfamiliar/malformed marker untouched.
    starts=$(grep -Fxc "$begin" "$hosts" || true)
    ends=$(grep -Fxc "$end" "$hosts" || true)
    if [[ "$starts" != "$ends" || "$starts" -gt 1 ]]; then
        echo 'WeekPact markers in /etc/hosts need manual inspection.' >&2
        exit 1
    fi
    if [[ "$starts" == 1 ]]; then
        start_line=$(grep -Fnx "$begin" "$hosts" | cut -d: -f1)
        end_line=$(grep -Fnx "$end" "$hosts" | cut -d: -f1)
        if (( start_line >= end_line )); then
            echo 'WeekPact markers in /etc/hosts are out of order.' >&2
            exit 1
        fi
    fi
    if [[ "$active" == 0 && "$starts" == 0 ]]; then
        rm -f "$expires"
        return
    fi

    # Copy preserves the original hosts ownership and permissions on replacement.
    temporary=$(mktemp /private/etc/.weekpact-hosts.XXXXXXXX)
    cleaned=$(mktemp /private/etc/.weekpact-clean.XXXXXXXX)
    trap 'rm -f "$temporary" "$cleaned"' EXIT
    cp -p "$hosts" "$temporary"
    awk -v first="$begin" -v last="$end" '
        $0 == first { inside=1; next }
        $0 == last  { inside=0; next }
        !inside { print }
    ' "$hosts" > "$cleaned"
    cat "$cleaned" > "$temporary"
    if [[ "$active" == 1 ]]; then
        {
            echo "$begin"
            echo "0.0.0.0 $domains"
            echo "::1 $domains"
            echo "$end"
        } >> "$temporary"
    fi
    if ! cmp -s "$hosts" "$temporary"; then
        mv -f "$temporary" "$hosts"
        dscacheutil -flushcache || true
        killall -HUP mDNSResponder 2>/dev/null || true
    fi
    rm -f "$temporary" "$cleaned"
    trap - EXIT
    if [[ "$active" == 0 ]]; then rm -f "$expires"; fi
}

case "${1:-}" in
    refresh)
        refresh
        ;;
    trial)
        if [[ ! -f "$hosts" ]]; then echo '/etc/hosts was not found.' >&2; exit 1; fi
        selected=${2:-youtube}
        case "$selected" in
            example|youtube) ;;
            *) echo 'Choose example or youtube.' >&2; exit 2 ;;
        esac
        if [[ -f "$expires" ]]; then refresh; fi
        if [[ -f "$expires" ]]; then
            echo 'A WeekPact test is already pending; wait for it to end.' >&2
            exit 1
        fi
        echo "WeekPact will block $selected for two minutes using /etc/hosts."
        echo 'This requires administrator access. It does not yet enforce daily limits.'
        read -r -p 'Type TEST to continue: ' answer
        if [[ "$answer" != TEST ]]; then echo 'Canceled.'; exit 0; fi

        install -d -o root -g wheel -m 0755 "$directory"
        install -o root -g wheel -m 0755 "$0" "$installed"
        cat > "$job" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>com.weekpact.local-blocker</string>
<key>ProgramArguments</key><array>
    <string>/bin/bash</string>
    <string>/Library/Application Support/WeekPact/local-blocker.sh</string>
    <string>refresh</string>
</array>
<key>RunAtLoad</key><true/>
<key>StartInterval</key><integer>10</integer>
</dict></plist>
PLIST
        chown root:wheel "$job"
        chmod 0644 "$job"
        # Verify the reboot checker is loaded before writing a blocking rule.
        if ! launchctl print system/com.weekpact.local-blocker >/dev/null 2>&1; then
            launchctl bootstrap system "$job"
        fi
        launchctl print system/com.weekpact.local-blocker >/dev/null
        policy_file=$(mktemp "$directory/.trial-expires.XXXXXXXX")
        printf '%s %s\n' "$(date -u -v+120S +%s)" "$selected" > "$policy_file"
        chown root:wheel "$policy_file"
        chmod 0600 "$policy_file"
        mv -f "$policy_file" "$expires"
        refresh
        echo "Test $selected in a fresh Safari or Chrome tab. It should open again in two minutes."
        ;;
    *)
        echo 'Usage: sudo bash scripts/test-weekpact-block.sh trial [youtube|example]' >&2
        exit 2
        ;;
esac
