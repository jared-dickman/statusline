# Claude Code Statusline

Rich, contextual statusline for [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) — git, Jira, PR, MCP, dev server, context window, and cost awareness in one line.

```
🌳 my-project | feature/COMP-123 | "fix auth bug" 2h 📝 3 | COMP-123 | #42 ✓ 5 | 3000 | mcp:chrome guru | ctx:42% $3.21
```

## Install

```bash
git clone https://github.com/jared-dickman/statusline.git ~/statusline
cd ~/statusline && bash install.sh
```

Then add to `~/.claude/settings.json`:
```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline/statusline.sh"
  }
}
```

## What it shows

```
🌳 worktree | branch | "last commit msg" age 📝 changed | JIRA-123 | #PR status commits | ports | mcp:servers | ctx:% $cost
```

| Segment | Source | Notes |
|---------|--------|-------|
| Worktree | `git rev-parse` | Repo root dirname |
| Branch | `git branch` | Hidden when matches worktree |
| Last commit | `git log -1` | 30 char + relative age (now/m/h/d) |
| Changed files | `git status` | Count of modified/untracked |
| Test status | `.test-results` file | Shows ❌ when present and not PASS |
| Jira ticket | Branch name regex | `(PREFIX-1234)` → clickable OSC 8 link |
| PR | `gh pr view` + `gh pr checks` | Number + CI (✓/✗/○) + commit count |
| Stash | `git stash list` | Red warning when stashes exist |
| Localhost | `lsof` via `bin/localhost-ports` | Clickable port links |
| MCPs | `claude mcp list` via `bin/active-mcps` | Filters disabled per-project, per-cwd cache |
| Context | Statusline JSON input | Scaled to compaction threshold, color-coded |
| Cost | Statusline JSON input | Session total USD |

All links are [OSC 8 hyperlinks](https://gist.github.com/egmontkob/eb114294efbcd5adb1944c9f3cb5feda) — clickable in iTerm, WezTerm, Kitty, JetBrains terminals.

## Architecture

```
statusline.sh          ← Main script, reads JSON from stdin, outputs ANSI
├── bin/active-mcps    ← MCP detection: `claude mcp list` + disabled filtering
└── bin/localhost-ports ← Dev server detection: lsof port scanning
```

`statusline.sh` receives JSON from Claude Code on stdin with `cwd`, `context_window.used_percentage`, `cost.total_cost_usd`. It `cd`s to `cwd` for all git/gh commands.

### MCP filtering

`bin/active-mcps` uses `claude mcp list` as the authoritative source. It cross-references `~/.claude.json` to filter out per-project disabled servers (`projects[path].disabledMcpServers`). Cache is keyed by `$PWD` md5 so different projects get correct results.

Short names map: `chrome-devtools`→`chrome`, `roktgpt`→`gpt`, `rokt code guru`→`guru`, `playwright`→`pw`, etc.

## Customization

**Jira domain** — edit `jira_link=` in `statusline.sh`

**Compaction threshold** — `export STATUSLINE_COMPACT_THRESHOLD=77` (default, scales context % relative to compaction point)

**MCP short names** — edit the `SHORT` dict in `bin/active-mcps`

**Cache TTL** — `CACHE_TTL` in `bin/active-mcps` (default 30s) and `bin/localhost-ports`

## Requirements

- bash 4+, git, python3
- `gh` CLI (PR status)
- `claude` CLI (MCP detection)
- `lsof` (localhost detection)

## License

MIT
