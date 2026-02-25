#!/bin/bash
# Install Claude Code Statusline

set -e

INSTALL_DIR="${HOME}/.claude/statusline"
BIN_DIR="${HOME}/.local/bin"
SETTINGS_FILE="${HOME}/.claude/settings.json"

echo "Installing Claude Code Statusline..."

mkdir -p "$INSTALL_DIR" "$BIN_DIR"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cp "$SCRIPT_DIR/statusline.sh" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/bin/"* "$BIN_DIR/"

chmod +x "$INSTALL_DIR/statusline.sh" "$BIN_DIR/localhost-ports" "$BIN_DIR/active-mcps"

echo "Installed to $INSTALL_DIR"

# Auto-configure ~/.claude/settings.json
configure_settings() {
    local cmd="$INSTALL_DIR/statusline.sh"

    if [ ! -f "$SETTINGS_FILE" ]; then
        mkdir -p "$(dirname "$SETTINGS_FILE")"
        cat > "$SETTINGS_FILE" <<EOF
{
  "statusLine": {
    "type": "command",
    "command": "$cmd"
  }
}
EOF
        echo "Created $SETTINGS_FILE with statusLine config"
        return
    fi

    # Check if statusLine already configured
    local existing_cmd=""
    if command -v jq >/dev/null 2>&1; then
        existing_cmd=$(jq -r '.statusLine.command // empty' "$SETTINGS_FILE" 2>/dev/null)
    elif command -v python3 >/dev/null 2>&1; then
        existing_cmd=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('statusLine',{}).get('command',''))" "$SETTINGS_FILE" 2>/dev/null)
    fi

    if [ -n "$existing_cmd" ]; then
        if [ "$existing_cmd" = "$cmd" ]; then
            echo "statusLine already configured correctly in $SETTINGS_FILE"
            return
        fi
        echo ""
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║  EXISTING STATUSLINE DETECTED                              ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo ""
        echo "  File: $SETTINGS_FILE"
        echo "  Current command: $existing_cmd"
        echo "  New command:     $cmd"
        echo ""
        echo "  Options:"
        echo "    1) Replace — use this repo's statusline instead"
        echo "    2) Wrap — create a script that chains both (advanced)"
        echo "    3) Skip — keep your current statusline, no changes"
        echo ""
        echo "  To replace manually, update statusLine.command in:"
        echo "    $SETTINGS_FILE"
        echo ""
        echo "  Claude Code only supports one statusLine command."
        echo "  If you want to combine statuslines, create a wrapper script"
        echo "  that calls both and merges their output."
        echo ""
        return
    fi

    # No statusLine configured — add it
    if command -v jq >/dev/null 2>&1; then
        local tmp=$(mktemp)
        jq --arg cmd "$cmd" '. + {"statusLine": {"type": "command", "command": $cmd}}' "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"
        echo "Added statusLine config to $SETTINGS_FILE"
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c "
import json, sys
with open(sys.argv[1], 'r') as f:
    d = json.load(f)
d['statusLine'] = {'type': 'command', 'command': sys.argv[2]}
with open(sys.argv[1], 'w') as f:
    json.dump(d, f, indent=2)
    f.write('\n')
" "$SETTINGS_FILE" "$cmd"
        echo "Added statusLine config to $SETTINGS_FILE"
    else
        echo ""
        echo "Could not auto-configure (install jq or python3). Manually add to $SETTINGS_FILE:"
        echo '  "statusLine": {'
        echo '    "type": "command",'
        echo "    \"command\": \"$cmd\""
        echo '  }'
    fi
}

configure_settings

echo ""
echo "Done! Restart Claude Code to activate the statusline."
echo "Run 'statusline --doctor' to verify your setup."
