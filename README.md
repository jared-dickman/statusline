# Claude Code Statusline

Rich, contextual statusline for [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) — git, Jira, PR, MCP, dev server, context window, and cost awareness in one line.

```
🌳 my-project | feature/COMP-123 | "fix auth bug" 2h 📝 3 | COMP-123 | #42 ✓ 5 | 3000 | mcp:chrome guru | ctx:42% $3.21
```

## How it works

Claude Code has a [`statusLine` feature](https://code.claude.com/docs/en/statusline) that pipes JSON session data (cwd, context window %, cost) to an external command. This repo is that command — a bash script that combines Claude Code's JSON with local git/gh/mcp data into one ANSI-formatted status line.

```
Claude Code  ──JSON on stdin──▶  statusline.sh  ──ANSI──▶  terminal status line
                                      │
                                 git, gh, claude CLI
                                 bin/active-mcps
                                 bin/localhost-ports
```

**Without the `statusLine` config in `settings.json`, the script has no data source and context/cost segments will be empty.**

See the [official Claude Code statusline docs](https://code.claude.com/docs/en/statusline) for the latest on supported JSON fields, `padding` options, and the `/statusline` slash command.

## Install

```bash
git clone https://github.com/jared-dickman/statusline.git ~/statusline
cd ~/statusline && bash install.sh
```

The installer:
- Copies `statusline.sh` to `~/.claude/statusline/`
- Copies helper scripts to `~/.local/bin/`
- **Auto-configures `~/.claude/settings.json`** with the required `statusLine` block (uses `jq` or `python3`)
- If a `statusLine` command already exists in settings.json, the installer **will not overwrite it** — it prints both the current and new commands with options to replace, wrap, or skip

Verify your setup:

```bash
~/.claude/statusline/statusline.sh --doctor
```

Restart Claude Code after installing.

### Existing statusline conflict

Claude Code only supports **one** `statusLine.command`. If the user already has a statusline configured, the installer detects this and stops with a clear summary of what's set and what options exist. The user (or their agent) should decide:

- **Replace**: Update `statusLine.command` in `~/.claude/settings.json` to `~/.claude/statusline/statusline.sh`
- **Wrap**: Create a wrapper script that calls both statuslines and merges output (advanced — Claude Code expects a single line of ANSI output)
- **Skip**: Keep the existing statusline unchanged

### Manual setup (if auto-config fails)

Add to `~/.claude/settings.json`:
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

### tmux users

Add to `~/.tmux.conf` based on your version:

```bash
# tmux 3.4+ (native OSC 8 — recommended)
set -ga terminal-features "*:hyperlinks"

# tmux 3.3 (DCS passthrough)
set -g allow-passthrough on
```

The script auto-detects tmux version and uses the correct hyperlink strategy.

## Troubleshooting

Run `--doctor` to check your setup:

```bash
~/.claude/statusline/statusline.sh --doctor
```

Common issues:
- **Context/cost empty**: `statusLine` not configured in `~/.claude/settings.json` — re-run `bash install.sh`
- **No git info**: Script can't `cd` to project dir — check that Claude Code is sending JSON with `cwd`
- **No PR status**: Install `gh` CLI and authenticate with `gh auth login`
- **No MCP servers**: Install `claude` CLI, or check `~/.local/bin/active-mcps` exists

Debug: raw JSON input is logged to `/tmp/claude-statusline-debug.json`

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

- bash 4+, git
- JSON parsing: `jq` (fastest) or `python3` (fallback) — basic git features work without either
- `gh` CLI (PR status, optional)
- `claude` CLI (MCP detection, optional)
- `lsof` (localhost detection, optional)
- Cross-platform: macOS, Linux, Windows (Git Bash/WSL)

## License

MIT
