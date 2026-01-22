#!/bin/bash
# Claude Code StatusLine - Rich git context for Claude Code CLI
# Features: worktree, branch, commit, files, Jira, PR, stash, localhost, MCP
# Reads JSON from stdin, outputs ANSI + OSC 8 hyperlink status

input=$(cat)
echo "$input" > /tmp/claude-statusline-debug.json 2>/dev/null

# Claude Code context from JSON input
context_pct=$(echo "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(int(d.get('context_window',{}).get('used_percentage',0)))" 2>/dev/null || echo "0")
cost_usd=$(echo "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); c=d.get('cost',{}).get('total_cost_usd',0); print(f'{c:.2f}' if c else '')" 2>/dev/null)

# Git context
branch=$(git branch --show-current 2>/dev/null)
branch=${branch:-no-git}
toplevel=$(git rev-parse --show-toplevel 2>/dev/null)
worktree=""
[ -n "$toplevel" ] && worktree="${toplevel##*/}"

branch_suffix=""
[[ "$branch" == *"/"* ]] && branch_suffix="${branch##*/}"

# Last commit
last_commit_msg=""
commit_age=""
if [ "$branch" != "no-git" ]; then
    last_commit_msg=$(git log -1 --pretty=format:'%s' 2>/dev/null | cut -c1-30)
    commit_timestamp=$(git log -1 --pretty=format:'%ct' 2>/dev/null)
    if [ -n "$commit_timestamp" ]; then
        current_time=$(date +%s)
        age_seconds=$((current_time - commit_timestamp))
        age_minutes=$((age_seconds / 60))
        age_hours=$((age_seconds / 3600))
        age_days=$((age_seconds / 86400))
        if [ $age_days -gt 0 ]; then commit_age="${age_days}d"
        elif [ $age_hours -gt 0 ]; then commit_age="${age_hours}h"
        elif [ $age_minutes -gt 0 ]; then commit_age="${age_minutes}m"
        else commit_age="now"
        fi
    fi
fi

files_changed=$(git status --short 2>/dev/null | wc -l | tr -d ' ')

# Test status
test_icon=""
[ -f ".test-results" ] && ! grep -q "PASS" .test-results 2>/dev/null && test_icon="$'\xe2\x9d\x8c'"

# Jira ticket from branch
jira_ticket=""
jira_link=""
if [ "$branch" != "no-git" ] && [[ "$branch" =~ (^|/)(([A-Z]+)-([0-9]+)) ]]; then
    jira_ticket="${BASH_REMATCH[2]}"
    jira_link="https://rokt.atlassian.net/browse/${jira_ticket}"
fi

# PR status
pr_status=""
pr_link=""
pr_commits=""
pr_number=""
pr_url=""
if command -v gh >/dev/null 2>&1 && [ "$branch" != "no-git" ]; then
    pr_data=$(gh pr view --json number,url,commits 2>/dev/null)
    if [ -n "$pr_data" ]; then
        pr_number=$(echo "$pr_data" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('number', ''))
except: print('')
" 2>/dev/null)
        pr_url=$(echo "$pr_data" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('url', ''))
except: print('')
" 2>/dev/null)
        pr_commits=$(echo "$pr_data" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(len(data.get('commits', [])))
except: print('')
" 2>/dev/null)

        if [ -n "$pr_number" ]; then
            check_result=$(gh pr checks --json state,link 2>/dev/null | python3 -c "
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
" 2>/dev/null)
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

# OSC 8 hyperlink
link() {
    local url="$1" text="$2"
    printf '%s' $'\e]8;;'"${url}"$'\e\\'"${text}"$'\e]8;;\e\\'
}

status=""

# Worktree
[ -n "$worktree" ] && status="${cyan}🌳 ${worktree}${reset}"

# Branch (skip if matches worktree)
if [ -z "$branch_suffix" ] || [ "$worktree" != "$branch_suffix" ]; then
    [ -n "$status" ] && status="${status} ${gray}|${reset}"
    status="${status} ${blue}${branch}${reset}"
fi

# Last commit
if [ -n "$last_commit_msg" ]; then
    status="${status} ${gray}|${reset} ${purple}\"${last_commit_msg}\"${reset}"
    [ -n "$commit_age" ] && status="${status} ${gray}${commit_age}${reset}"
fi

# Test icon
[ -n "$test_icon" ] && status="${status} ${gray}|${reset} ${test_icon}"

# Files changed
[ $files_changed -gt 0 ] && status="${status} ${purple}📝 ${files_changed}${reset}"

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
stash_count=$(git stash list 2>/dev/null | wc -l | tr -d ' ')
[ "$stash_count" -gt 0 ] 2>/dev/null && status="${status} ${gray}|${reset} ${red}stash:${stash_count}${reset}"

# Localhost servers
if [ -x "$HOME/.local/bin/localhost-ports" ]; then
    localhost_ports=$("$HOME/.local/bin/localhost-ports" 2>/dev/null)
    if [ -n "$localhost_ports" ]; then
        server_links=""
        for port in $localhost_ports; do
            url="http://localhost:${port}"
            server_links="${server_links}$(link "$url" "$port") "
        done
        status="${status} ${gray}|${reset} ${green}${server_links% }${reset}"
    fi
fi

# Active MCP servers
if [ -x "$HOME/.local/bin/active-mcps" ]; then
    active_mcps=$("$HOME/.local/bin/active-mcps" 2>/dev/null)
    [ -n "$active_mcps" ] && status="${status} ${gray}|${reset} ${orange}mcp:${active_mcps}${reset}"
fi

# Context window (color: green <50%, yellow 50-80%, red >80%)
yellow=$'\e[38;5;220m'
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
