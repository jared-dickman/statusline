#!/bin/bash
# Claude Code StatusLine - Rich git context for Claude Code CLI
# Features: worktree, branch, commit, files, Jira, PR, stash, localhost, MCP
# Reads JSON from stdin, outputs ANSI + OSC 8 hyperlink status

# Ensure homebrew binaries (gh, jq, etc) are in PATH
export PATH="/opt/homebrew/bin:$PATH"

# --- Doctor mode: verify setup ---
if [ "${1:-}" = "--doctor" ]; then
    ok=0 warn=0 fail=0
    check() {
        local label="$1" status="$2" detail="$3"
        case "$status" in
            ok)   printf "  ✓ %s\n" "$label"; ((ok++));;
            warn) printf "  ⚠ %s — %s\n" "$label" "$detail"; ((warn++));;
            fail) printf "  ✗ %s — %s\n" "$label" "$detail"; ((fail++));;
        esac
    }
    echo "statusline doctor"
    echo ""

    [ -x "$HOME/.claude/statusline/statusline.sh" ] \
        && check "statusline.sh installed" ok \
        || check "statusline.sh installed" fail "run: bash install.sh"

    settings="$HOME/.claude/settings.json"
    if [ -f "$settings" ]; then
        if grep -q '"statusLine"' "$settings" 2>/dev/null; then
            check "settings.json configured" ok
        else
            check "settings.json configured" fail "missing statusLine block — run: bash install.sh"
        fi
    else
        check "settings.json configured" fail "$settings not found — run: bash install.sh"
    fi

    command -v jq >/dev/null 2>&1 \
        && check "jq (JSON parser)" ok \
        || { command -v python3 >/dev/null 2>&1 \
            && check "jq (JSON parser)" warn "using python3 fallback (slower)" \
            || check "jq (JSON parser)" fail "install jq or python3"; }

    command -v git >/dev/null 2>&1 \
        && check "git" ok \
        || check "git" fail "required for all git features"

    command -v gh >/dev/null 2>&1 \
        && check "gh CLI (PR status)" ok \
        || check "gh CLI (PR status)" warn "optional — install for PR status"

    command -v claude >/dev/null 2>&1 \
        && check "claude CLI (MCP detection)" ok \
        || check "claude CLI (MCP detection)" warn "optional — install for MCP server list"

    [ -x "$HOME/.local/bin/active-mcps" ] \
        && check "bin/active-mcps" ok \
        || check "bin/active-mcps" warn "not found in ~/.local/bin/"

    [ -x "$HOME/.local/bin/localhost-ports" ] \
        && check "bin/localhost-ports" ok \
        || check "bin/localhost-ports" warn "not found in ~/.local/bin/"

    if [ -n "$TMUX" ]; then
        check "tmux detected" ok
        _tv=$(tmux -V 2>/dev/null | grep -oE '[0-9]+\.[0-9a-z]+' | head -1)
        _tmaj="${_tv%%.*}"
        if [ "${_tmaj:-0}" -ge 3 ]; then
            check "tmux version ($_tv)" ok
        else
            check "tmux version ($_tv)" warn "3.4+ recommended for native hyperlinks"
        fi
    fi

    echo ""
    printf "  %d ok" "$ok"
    [ "$warn" -gt 0 ] && printf ", %d warnings" "$warn"
    [ "$fail" -gt 0 ] && printf ", %d failed" "$fail"
    echo ""
    [ "$fail" -gt 0 ] && exit 1
    exit 0
fi

input=$(cat)
echo "$input" > /tmp/claude-statusline-debug.json 2>/dev/null

# --- Portable JSON helper (jq > python3) ---
json_val() {
    if command -v jq >/dev/null 2>&1; then
        echo "$input" | jq -r "$1" 2>/dev/null
    elif command -v python3 >/dev/null 2>&1; then
        echo "$input" | python3 -c "
import sys, json
d = json.load(sys.stdin)
keys = '$1'.replace(' // empty', '').replace(' // 0', '').strip('.').split('.')
v = d
for k in keys:
    if isinstance(v, dict):
        v = v.get(k)
    else:
        v = None
        break
if v is None:
    fallback = '0' if '// 0' in '$1' else ''
    print(fallback)
else:
    print(v)
" 2>/dev/null
    fi
}

# Change to session's working directory for git/gh commands
session_cwd=$(json_val '.cwd // empty')
[ -n "$session_cwd" ] && [ -d "$session_cwd" ] && cd "$session_cwd"

# Claude Code context from JSON input
# compact_threshold: 200k window - 45k autocompact buffer ≈ 77.5%
COMPACT_THRESHOLD=${STATUSLINE_COMPACT_THRESHOLD:-77}
raw_context_pct=$(json_val '.context_window.used_percentage // 0')
raw_context_pct=${raw_context_pct%%.*}
raw_context_pct=${raw_context_pct:-0}

# Scale: if used_percentage=75% and threshold=77%, we're at ~97% toward compaction
if [ "$COMPACT_THRESHOLD" -gt 0 ] 2>/dev/null; then
    context_pct=$(( (raw_context_pct * 100) / COMPACT_THRESHOLD ))
    [ "$context_pct" -gt 100 ] && context_pct=100
else
    context_pct="$raw_context_pct"
fi

cost_raw=$(json_val '.cost.total_cost_usd // 0')
cost_usd=""
if [ -n "$cost_raw" ] && [ "$cost_raw" != "0" ] && [ "$cost_raw" != "null" ]; then
    cost_usd=$(printf "%.2f" "$cost_raw" 2>/dev/null || echo "$cost_raw")
fi

# --- Cache helpers (cross-platform stat) ---
CACHE_DIR="/tmp/claude-statusline"
mkdir -p "$CACHE_DIR" 2>/dev/null

file_mtime() {
    stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0
}

cache_stale() {
    local file="$1" max_age="$2"
    [ ! -f "$file" ] && return 0
    [ ! -s "$file" ] && return 0
    local file_age=$(( $(date +%s) - $(file_mtime "$file") ))
    [ "$file_age" -gt "$max_age" ]
}

# --- Git context (all git ops behind a single lock to prevent index.lock contention) ---
_repo_hash=$(printf '%s' "${session_cwd:-none}" | md5 -q 2>/dev/null || printf '%s' "${session_cwd:-none}" | md5sum 2>/dev/null | cut -c1-8)
_repo_hash="${_repo_hash:0:8}"
GIT_LOCK="$CACHE_DIR/git-${_repo_hash}.lock"
GIT_BRANCH_CACHE="$CACHE_DIR/git-branch-${_repo_hash}"
GIT_STATUS_CACHE="$CACHE_DIR/git-status-${_repo_hash}"
STASH_CACHE="$CACHE_DIR/git-stash-${_repo_hash}"

_write_cache() { echo "$2" > "$1.tmp.$$" && mv "$1.tmp.$$" "$1"; }

acquire_git_lock() {
    if ( set -o noclobber; echo $$ > "$GIT_LOCK" ) 2>/dev/null; then
        return 0
    fi
    local lock_pid lock_age
    lock_age=$(( $(date +%s) - $(file_mtime "$GIT_LOCK") ))
    lock_pid=$(cat "$GIT_LOCK" 2>/dev/null)
    if [ "$lock_age" -gt 30 ] || { [ -n "$lock_pid" ] && ! kill -0 "$lock_pid" 2>/dev/null; }; then
        rm -f "$GIT_LOCK"
        if ( set -o noclobber; echo $$ > "$GIT_LOCK" ) 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

branch="no-git"
worktree=""
branch_suffix=""
files_modified=0
files_added=0
stash_count=0

needs_refresh=false
cache_stale "$GIT_BRANCH_CACHE" 10 && needs_refresh=true
cache_stale "$GIT_STATUS_CACHE" 5 && needs_refresh=true
cache_stale "$STASH_CACHE" 30 && needs_refresh=true

if $needs_refresh && acquire_git_lock; then
    if cache_stale "$GIT_BRANCH_CACHE" 10; then
        _b=$(git branch --show-current 2>/dev/null)
        _t=$(git rev-parse --show-toplevel 2>/dev/null)
        _write_cache "$GIT_BRANCH_CACHE" "${_b:-no-git}|${_t}"
    fi
    if cache_stale "$GIT_STATUS_CACHE" 5; then
        git_short=$(git status --short 2>/dev/null)
        if [ -n "$git_short" ]; then
            gs_added=$(echo "$git_short" | grep -c '^?' 2>/dev/null || echo 0)
            gs_modified=$(echo "$git_short" | grep -cv '^?' 2>/dev/null || echo 0)
        else
            gs_added=0; gs_modified=0
        fi
        _write_cache "$GIT_STATUS_CACHE" "${gs_modified}|${gs_added}"
    fi
    if cache_stale "$STASH_CACHE" 30; then
        _stash=$(git stash list 2>/dev/null | wc -l | tr -d ' ')
        _write_cache "$STASH_CACHE" "$_stash"
    fi
    rm -f "$GIT_LOCK"
fi

git_branch_raw=$(cat "$GIT_BRANCH_CACHE" 2>/dev/null || echo "no-git|")
branch="${git_branch_raw%|*}"
toplevel="${git_branch_raw#*|}"
branch=${branch:-no-git}
[ -n "$toplevel" ] && worktree="${toplevel##*/}"
[[ "$branch" == *"/"* ]] && branch_suffix="${branch##*/}"

git_status_raw=$(cat "$GIT_STATUS_CACHE" 2>/dev/null || echo "0|0")
files_modified="${git_status_raw%|*}"
files_added="${git_status_raw#*|}"
files_modified=${files_modified:-0}
files_added=${files_added:-0}

stash_count=$(cat "$STASH_CACHE" 2>/dev/null || echo 0)
stash_count=${stash_count:-0}

# Test status
test_icon=""
[ -f ".test-results" ] && ! grep -q "PASS" .test-results 2>/dev/null && test_icon="❌"

# Jira ticket from branch
jira_ticket=""
jira_link=""
if [ "$branch" != "no-git" ] && [[ "$branch" =~ (^|/)(([A-Z]+)-([0-9]+)) ]]; then
    jira_ticket="${BASH_REMATCH[2]}"
    jira_link="https://rokt.atlassian.net/browse/${jira_ticket}"
fi

# --- PR status (cached 45s) ---
pr_status=""
pr_link=""
pr_commits=""
pr_number=""
pr_url=""
PR_CACHE="$CACHE_DIR/gh-pr-${worktree:-none}-${branch//\//_}"
PR_CHECKS_CACHE="$CACHE_DIR/gh-checks-${worktree:-none}-${branch//\//_}"

if command -v gh >/dev/null 2>&1 && [ "$branch" != "no-git" ]; then
    if cache_stale "$PR_CACHE" 120; then
        gh pr view --json number,url,commits > "$PR_CACHE" 2>/dev/null || : > "$PR_CACHE"
    fi
    pr_data=$(cat "$PR_CACHE" 2>/dev/null)

    if [ -n "$pr_data" ] && [ "$pr_data" != "" ]; then
        if command -v jq >/dev/null 2>&1; then
            pr_number=$(echo "$pr_data" | jq -r '.number // empty' 2>/dev/null)
            pr_url=$(echo "$pr_data" | jq -r '.url // empty' 2>/dev/null)
            pr_commits=$(echo "$pr_data" | jq -r '.commits | length' 2>/dev/null)
        elif command -v python3 >/dev/null 2>&1; then
            pr_number=$(echo "$pr_data" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('number',''))" 2>/dev/null)
            pr_url=$(echo "$pr_data" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('url',''))" 2>/dev/null)
            pr_commits=$(echo "$pr_data" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('commits',[])))" 2>/dev/null)
        fi

        if [ -n "$pr_number" ]; then
            if cache_stale "$PR_CHECKS_CACHE" 120; then
                if command -v jq >/dev/null 2>&1; then
                    gh pr checks --json state,link 2>/dev/null | jq -r '
                        if length == 0 then "unknown||"
                        elif any(.state == "FAILURE" or .state == "ERROR") then
                            (map(select(.state == "FAILURE" or .state == "ERROR"))[0] | "fail||\(.link // "")")
                        elif any(.state == "PENDING" or .state == "QUEUED" or .state == "IN_PROGRESS" or .state == "WAITING") then
                            (map(select(.state == "PENDING" or .state == "QUEUED" or .state == "IN_PROGRESS" or .state == "WAITING"))[0] | "pending||\(.link // "")")
                        elif all(.state == "SUCCESS" or .state == "SKIPPED" or .state == "NEUTRAL") then "pass||"
                        else "unknown||"
                        end
                    ' > "$PR_CHECKS_CACHE" 2>/dev/null || echo "unknown||" > "$PR_CHECKS_CACHE"
                elif command -v python3 >/dev/null 2>&1; then
                    gh pr checks --json state,link 2>/dev/null | python3 -c "
import sys, json
try:
    checks = json.load(sys.stdin)
    if not checks: print('unknown||')
    elif any(c.get('state') in ['FAILURE', 'ERROR'] for c in checks):
        failed = next((c for c in checks if c.get('state') in ['FAILURE', 'ERROR']), None)
        print(f\"fail||{failed.get('link', '') if failed else ''}\")
    elif any(c.get('state') in ['PENDING', 'QUEUED', 'IN_PROGRESS', 'WAITING'] for c in checks):
        running = next((c for c in checks if c.get('state') in ['PENDING', 'QUEUED', 'IN_PROGRESS', 'WAITING']), None)
        print(f\"pending||{running.get('link', '') if running else ''}\")
    elif all(c.get('state') in ['SUCCESS', 'SKIPPED', 'NEUTRAL'] for c in checks):
        print('pass||')
    else: print('unknown||')
except: print('unknown||')
" > "$PR_CHECKS_CACHE" 2>/dev/null || echo "unknown||" > "$PR_CHECKS_CACHE"
                fi
            fi
            check_result=$(cat "$PR_CHECKS_CACHE" 2>/dev/null)
            check_status="${check_result%%||*}"
            check_url="${check_result##*||}"
            case "$check_status" in
                "pass") pr_status="✓"; pr_link="${check_url:-$pr_url}";;
                "fail") pr_status="✗"; pr_link="${check_url:-$pr_url}";;
                "pending") pr_status="○"; pr_link="${check_url:-$pr_url}";;
            esac
        fi
    fi
fi

# Colors
reset=$'\e[0m'
gray=$'\e[38;5;240m'
cyan=$'\e[38;5;51m'
blue=$'\e[38;5;75m'
purple=$'\e[38;5;141m'
red=$'\e[38;5;196m'
green=$'\e[38;5;114m'
orange=$'\e[38;5;208m'
yellow=$'\e[38;5;220m'

# Detect tmux hyperlink strategy (native OSC 8 for 3.4+, DCS passthrough for older)
TMUX_LINK_MODE=""
if [ -n "$TMUX" ]; then
    _tv=$(tmux -V 2>/dev/null | grep -oE '[0-9]+\.[0-9a-z]+' | head -1)
    _tmaj="${_tv%%.*}" _tmin="${_tv#*.}" _tmin="${_tmin%%[a-z]*}"
    if [ "${_tmaj:-0}" -gt 3 ] || { [ "${_tmaj:-0}" -eq 3 ] && [ "${_tmin:-0}" -ge 4 ]; }; then
        TMUX_LINK_MODE="native"
    else
        TMUX_LINK_MODE="passthrough"
    fi
fi

# OSC 8 hyperlink — ST terminator (\e\\) for best compatibility
# tmux 3.4+: native OSC 8 (requires `set -ga terminal-features "*:hyperlinks"`)
# tmux <3.4: DCS passthrough (requires `set -g allow-passthrough on` for 3.3+)
link() {
    local url="$1" text="$2"
    if [ "$TMUX_LINK_MODE" = "passthrough" ]; then
        printf '%s' $'\e'"Ptmux;"$'\e\e'"]8;;${url}"$'\e\e'"\\""${text}"$'\e\e'"]8;;"$'\e\e'"\\"$'\e'"\\"
    else
        printf '%s' $'\e]8;;'"${url}"$'\e\\'"${text}"$'\e]8;;\e\\'
    fi
}

status=""

# Worktree
[ -n "$worktree" ] && status="${cyan}${worktree}${reset}"

# Branch (skip if matches worktree)
if [ -z "$branch_suffix" ] || [ "$worktree" != "$branch_suffix" ]; then
    [ -n "$status" ] && status="${status} ${gray}|${reset}"
    status="${status} ${blue}${branch}${reset}"
fi

# Test icon
[ -n "$test_icon" ] && status="${status} ${gray}|${reset} ${test_icon}"

# Files changed
files_str=""
[ "$files_modified" -gt 0 ] 2>/dev/null && files_str="${purple}~${files_modified}${reset}"
[ "$files_added" -gt 0 ] 2>/dev/null && files_str="${files_str:+${files_str} }${green}+${files_added}${reset}"
[ -n "$files_str" ] && status="${status} ${files_str}"

# Jira link
if [ -n "$jira_ticket" ] && [ -n "$jira_link" ]; then
    jira_hyperlink=$(link "$jira_link" "$jira_ticket")
    status="${status} ${gray}|${reset} ${purple}${jira_hyperlink}${reset}"
fi

# PR section
if [ -n "$pr_number" ]; then
    pr_num_hyperlink=$(link "$pr_url" "#${pr_number}")
    status="${status} ${gray}|${reset} ${purple}${pr_num_hyperlink}${reset}"
    [ -n "$pr_status" ] && status="${status} $(link "$pr_link" "$pr_status")"
    [ -n "$pr_commits" ] && [ "$pr_commits" -gt 0 ] 2>/dev/null && status="${status} ${gray}${pr_commits}${reset}"
fi

# Stash warning
[ "$stash_count" -gt 0 ] 2>/dev/null && status="${status} ${gray}|${reset} ${red}stash:${stash_count}${reset}"

# Localhost servers
if [ -x "$HOME/.local/bin/localhost-ports" ]; then
    localhost_ports=$("$HOME/.local/bin/localhost-ports" 2>/dev/null)
    if [ -n "$localhost_ports" ]; then
        server_links=""
        for port in $localhost_ports; do
            url="http://localhost:${port}"
            server_links="${server_links}${green}$(link "$url" "$port")${reset} "
        done
        status="${status} ${gray}|${reset} ${server_links% }"
    fi
fi

# Active MCP servers
if [ -x "$HOME/.local/bin/active-mcps" ]; then
    active_mcps=$("$HOME/.local/bin/active-mcps" 2>/dev/null)
    [ -n "$active_mcps" ] && status="${status} ${gray}|${reset} ${orange}mcp:${active_mcps}${reset}"
fi

# Context window (color: green <50%, yellow 50-80%, red >80%)
if [ "$context_pct" -gt 0 ] 2>/dev/null; then
    if [ "$context_pct" -lt 50 ]; then ctx_color="$green"
    elif [ "$context_pct" -lt 80 ]; then ctx_color="$yellow"
    else ctx_color="$red"
    fi
    status="${status} ${gray}|${reset} ${ctx_color}ctx:${context_pct}%${reset}"
fi

# Session cost
[ -n "$cost_usd" ] && [ "$cost_usd" != "0.00" ] && status="${status} ${gray}\$${cost_usd}${reset}"

printf '%s\n' "$status"
