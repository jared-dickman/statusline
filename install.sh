#!/bin/bash
# Install Claude Code Statusline

set -e

INSTALL_DIR="${HOME}/.claude/statusline"
BIN_DIR="${HOME}/.local/bin"

echo "Installing Claude Code Statusline..."

mkdir -p "$INSTALL_DIR" "$BIN_DIR"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cp "$SCRIPT_DIR/statusline.sh" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/bin/"* "$BIN_DIR/"

chmod +x "$INSTALL_DIR/statusline.sh" "$BIN_DIR/localhost-ports" "$BIN_DIR/active-mcps"

echo "Installed to $INSTALL_DIR"
echo ""
echo "Add to ~/.claude/settings.json:"
echo '  "statusLine": {'
echo '    "type": "command",'
echo "    \"command\": \"$INSTALL_DIR/statusline.sh\""
echo '  }'
