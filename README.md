# Claude Code Statusline

Rich, contextual statusline for [Claude Code CLI](https://claude.ai/claude-code) with git, Jira, PR, and dev server awareness.

```
🌳 my-project | feature/COMP-123 | "fix auth bug" 2h 📝 3 | COMP-123 | #42 ✓ 5 | 3000 | mcp:chrome
```

## Features

| Feature | Description |
|---------|-------------|
| **Worktree** | Shows current git worktree name |
| **Branch** | Smart display (hides when matches worktree) |
| **Last commit** | Message (30 char) + relative age |
| **Changed files** | Count of modified files |
| **Test status** | Shows ❌ when tests fail |
| **Jira ticket** | Extracts from branch, clickable OSC 8 link |
| **PR status** | Number + CI status (✓/✗/○) + commit count |
| **Stash warning** | Red indicator when stashes exist |
| **Localhost servers** | Detects project dev servers, clickable ports |
| **Active MCPs** | Shows running MCP servers |

All links are OSC 8 hyperlinks - clickable in iTerm, WezTerm, Kitty, JetBrains terminals.

## Installation

```bash
# Clone
git clone https://github.com/ROKT/statusline.git ~/.claude/statusline

# Install helper scripts
mkdir -p ~/.local/bin
cp ~/.claude/statusline/bin/* ~/.local/bin/
chmod +x ~/.local/bin/localhost-ports ~/.local/bin/active-mcps

# Configure Claude Code (~/.claude/settings.json)
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline/statusline.sh"
  }
}
```

## Customization

### Jira Domain

Edit `statusline.sh` line with `jira_link=` to use your Jira instance.

### Colors

Modify the color escape codes section to match your theme.

## Requirements

- `bash` 4+
- `git`
- `gh` CLI (for PR status)
- `python3` (for JSON parsing)
- `lsof` (for localhost detection)

## License

MIT
