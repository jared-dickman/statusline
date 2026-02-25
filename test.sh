#!/usr/bin/env bash
# Test suite for statusline components
# Usage: bash test.sh

PASS=0
FAIL=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pass() { ((PASS++)); printf "  \033[32m✓\033[0m %s\n" "$1"; }
fail() { ((FAIL++)); printf "  \033[31m✗\033[0m %s\n" "$1"; }
section() { printf "\n\033[1m%s\033[0m\n" "$1"; }

MCP_PYTHON='
import sys
SHORT={"chrome-devtools":"chrome","roktgpt":"gpt","rokt code guru":"guru","playwright":"pw","storybook":"sb","serena":"serena","excalidraw":"excali","atlassian":"atlas","slack":"slack","notion":"notion","figma":"figma","linear":"linear"}
disabled=set()
o=[]
for l in sys.stdin:
 l=l.strip()
 if not l:continue
 n=l.split(" - ")[0].rsplit(": ",1)[0].strip() if " - " in l else l.split(":")[0].strip()
 if n.lower() in disabled:continue
 if n.startswith("claude.ai "):n=n[10:]
 elif n.startswith("plugin:"):n=n.split(":")[-1].strip()
 dl=n.lower();s=next((v for k,v in SHORT.items() if k in dl),dl.replace("mcp-server-","").replace("-mcp","")[:8])
 if s not in o:o.append(s)
print(" ".join(o))
'

MCP_PYTHON_DISABLED='
import sys
disabled={"claude.ai excalidraw"}
SHORT={"chrome-devtools":"chrome","excalidraw":"excali"}
o=[]
for l in sys.stdin:
 l=l.strip()
 if not l:continue
 n=l.split(" - ")[0].rsplit(": ",1)[0].strip() if " - " in l else l.split(":")[0].strip()
 if n.lower() in disabled:continue
 if n.startswith("claude.ai "):n=n[10:]
 elif n.startswith("plugin:"):n=n.split(":")[-1].strip()
 dl=n.lower();s=next((v for k,v in SHORT.items() if k in dl),dl.replace("mcp-server-","").replace("-mcp","")[:8])
 if s not in o:o.append(s)
print(" ".join(o))
'

MCP_PYTHON_MULTI_DISABLED='
import sys
disabled={"claude.ai excalidraw","roktgpt","plugin:serena:serena"}
SHORT={"chrome-devtools":"chrome","roktgpt":"gpt","serena":"serena","excalidraw":"excali"}
o=[]
for l in sys.stdin:
 l=l.strip()
 if not l:continue
 n=l.split(" - ")[0].rsplit(": ",1)[0].strip() if " - " in l else l.split(":")[0].strip()
 if n.lower() in disabled:continue
 if n.startswith("claude.ai "):n=n[10:]
 elif n.startswith("plugin:"):n=n.split(":")[-1].strip()
 dl=n.lower();s=next((v for k,v in SHORT.items() if k in dl),dl.replace("mcp-server-","").replace("-mcp","")[:8])
 if s not in o:o.append(s)
print(" ".join(o))
'

# ── active-mcps: name mapping ─────────────────────────────────────

section "bin/active-mcps — name mapping"

result=$(echo 'chrome-devtools: npx @anthropic-ai/chrome-devtools - Connected' | python3 -c "$MCP_PYTHON")
[[ "$result" == "chrome" ]] && pass "chrome-devtools → chrome" || fail "chrome-devtools → chrome (got: $result)"

result=$(echo 'claude.ai Rokt Code Guru: https://mcp.claude.ai/... - Connected' | python3 -c "$MCP_PYTHON")
[[ "$result" == "guru" ]] && pass "claude.ai Rokt Code Guru → guru" || fail "claude.ai Rokt Code Guru → guru (got: $result)"

result=$(echo 'plugin:serena:serena: uvx serena - Connected' | python3 -c "$MCP_PYTHON")
[[ "$result" == "serena" ]] && pass "plugin:serena:serena → serena" || fail "plugin:serena:serena → serena (got: $result)"

result=$(echo 'roktgpt: npx ... - Connected' | python3 -c "$MCP_PYTHON")
[[ "$result" == "gpt" ]] && pass "roktgpt → gpt" || fail "roktgpt → gpt (got: $result)"

result=$(echo 'playwright: npx @anthropic-ai/playwright - Connected' | python3 -c "$MCP_PYTHON")
[[ "$result" == "pw" ]] && pass "playwright → pw" || fail "playwright → pw (got: $result)"

result=$(echo 'storybook: npx storybook-mcp - Connected' | python3 -c "$MCP_PYTHON")
[[ "$result" == "sb" ]] && pass "storybook → sb" || fail "storybook → sb (got: $result)"

result=$(echo 'claude.ai Excalidraw: https://... - Connected' | python3 -c "$MCP_PYTHON")
[[ "$result" == "excali" ]] && pass "excalidraw → excali" || fail "excalidraw → excali (got: $result)"

result=$(echo 'atlassian: npx ... - Connected' | python3 -c "$MCP_PYTHON")
[[ "$result" == "atlas" ]] && pass "atlassian → atlas" || fail "atlassian → atlas (got: $result)"

result=$(echo 'slack: npx ... - Connected' | python3 -c "$MCP_PYTHON")
[[ "$result" == "slack" ]] && pass "slack → slack" || fail "slack → slack (got: $result)"

result=$(echo 'notion: npx ... - Connected' | python3 -c "$MCP_PYTHON")
[[ "$result" == "notion" ]] && pass "notion → notion" || fail "notion → notion (got: $result)"

result=$(echo 'figma: npx ... - Connected' | python3 -c "$MCP_PYTHON")
[[ "$result" == "figma" ]] && pass "figma → figma" || fail "figma → figma (got: $result)"

result=$(echo 'linear: npx ... - Connected' | python3 -c "$MCP_PYTHON")
[[ "$result" == "linear" ]] && pass "linear → linear" || fail "linear → linear (got: $result)"

# ── active-mcps: prefix/suffix stripping ──────────────────────────

section "bin/active-mcps — prefix/suffix stripping"

result=$(echo 'mcp-server-custom: cmd - Connected' | python3 -c "$MCP_PYTHON")
[[ "$result" == "custom" ]] && pass "mcp-server-* prefix stripped" || fail "mcp-server-* prefix (got: $result)"

result=$(echo 'analytics-mcp: cmd - Connected' | python3 -c "$MCP_PYTHON")
[[ "$result" == "analytic" ]] && pass "-mcp suffix stripped + truncated" || fail "-mcp suffix (got: $result)"

result=$(echo 'mcp-server-chrome-devtools: cmd - Connected' | python3 -c "$MCP_PYTHON")
[[ "$result" == "chrome" ]] && pass "mcp-server- stripped then SHORT matched" || fail "mcp-server- + SHORT (got: $result)"

# ── active-mcps: filtering ────────────────────────────────────────

section "bin/active-mcps — filtering"

result=$(printf 'claude.ai Excalidraw: https://... - Connected\nchrome-devtools: npx ... - Connected\n' | python3 -c "$MCP_PYTHON_DISABLED")
[[ "$result" == "chrome" ]] && pass "disabled server filtered out" || fail "disabled server filtered out (got: $result)"

result=$(printf 'chrome-devtools: npx ... - Connected\nchrome-devtools: npx ... - Connected\n' | python3 -c "$MCP_PYTHON")
[[ "$result" == "chrome" ]] && pass "duplicates deduplicated" || fail "duplicates deduplicated (got: $result)"

result=$(echo 'my-super-long-server-name: cmd - Connected' | python3 -c "$MCP_PYTHON")
[[ ${#result} -le 8 ]] && pass "unknown server truncated ≤8 chars" || fail "unknown server truncated (got: $result, len: ${#result})"

result=$(printf '' | python3 -c "$MCP_PYTHON")
[[ -z "$result" ]] && pass "empty input → empty output" || fail "empty input (got: $result)"

result=$(printf 'claude.ai Excalidraw: ... - Connected\nroktgpt: ... - Connected\nplugin:serena:serena: ... - Connected\nchrome-devtools: ... - Connected\n' | python3 -c "$MCP_PYTHON_MULTI_DISABLED")
[[ "$result" == "chrome" ]] && pass "multiple disabled servers filtered" || fail "multiple disabled (got: $result)"

result=$(printf 'CLAUDE.AI EXCALIDRAW: ... - Connected\nchrome-devtools: ... - Connected\n' | python3 -c "$MCP_PYTHON_DISABLED")
[[ "$result" == "chrome" ]] && pass "disabled check is case-insensitive" || fail "case-insensitive disabled (got: $result)"

# ── active-mcps: ordering ────────────────────────────────────────

section "bin/active-mcps — ordering"

result=$(printf 'chrome-devtools: npx ... - Connected\nplugin:serena:serena: uvx ... - Connected\nroktgpt: npx ... - Connected\n' | python3 -c "$MCP_PYTHON")
[[ "$result" == "chrome serena gpt" ]] && pass "preserves input order" || fail "preserves input order (got: $result)"

# ── active-mcps: project path matching ────────────────────────────

section "bin/active-mcps — config path matching"

tmpconfig=$(mktemp)
cat > "$tmpconfig" << 'CONF'
{
  "projects": {
    "/Users/test/project": {
      "disabledMcpServers": ["roktgpt"]
    },
    "/Users/test/project/packages/web": {
      "disabledMcpServers": ["chrome-devtools", "plugin:serena:serena"]
    }
  }
}
CONF

CONFIG_PYTHON='
import sys, json, os
config_path = sys.argv[1]
cwd = sys.argv[2]
with open(config_path) as f:
    config = json.load(f)
best_match = ""
best_disabled = []
for proj_path, proj_data in config.get("projects", {}).items():
    if cwd == proj_path or cwd.startswith(proj_path + "/"):
        if len(proj_path) > len(best_match):
            best_match = proj_path
            best_disabled = proj_data.get("disabledMcpServers", [])
disabled = {name.lower() for name in best_disabled}
SHORT = {"chrome-devtools":"chrome","roktgpt":"gpt","serena":"serena"}
o = []
for l in sys.stdin:
    l = l.strip()
    if not l: continue
    n = l.split(" - ")[0].rsplit(": ",1)[0].strip() if " - " in l else l.split(":")[0].strip()
    if n.lower() in disabled: continue
    if n.startswith("claude.ai "): n = n[10:]
    elif n.startswith("plugin:"): n = n.split(":")[-1].strip()
    dl = n.lower()
    s = next((v for k,v in SHORT.items() if k in dl), dl[:8])
    if s not in o: o.append(s)
print(" ".join(o))
'

result=$(printf 'roktgpt: npx ... - Connected\nchrome-devtools: npx ... - Connected\n' | python3 -c "$CONFIG_PYTHON" "$tmpconfig" "/Users/test/project/packages/web/src")
[[ "$result" == "gpt" ]] && pass "longest path match filters correct servers" || fail "longest path match (got: $result)"

result=$(printf 'roktgpt: npx ... - Connected\nchrome-devtools: npx ... - Connected\n' | python3 -c "$CONFIG_PYTHON" "$tmpconfig" "/Users/test/project/other")
[[ "$result" == "chrome" ]] && pass "parent path match filters its servers" || fail "parent path match (got: $result)"

result=$(printf 'roktgpt: npx ... - Connected\nchrome-devtools: npx ... - Connected\n' | python3 -c "$CONFIG_PYTHON" "$tmpconfig" "/Users/other")
[[ "$result" == "gpt chrome" ]] && pass "no matching path → nothing filtered" || fail "no match (got: $result)"

rm "$tmpconfig"

# ── active-mcps: script properties ───────────────────────────────

section "bin/active-mcps — script"

[[ -f "$SCRIPT_DIR/bin/active-mcps" ]] && pass "exists" || fail "missing"
[[ -x "$SCRIPT_DIR/bin/active-mcps" ]] && pass "is executable" || fail "not executable"
grep -q 'CACHE_TTL' "$SCRIPT_DIR/bin/active-mcps" && pass "has cache TTL" || fail "missing cache TTL"
grep -q 'claude mcp list' "$SCRIPT_DIR/bin/active-mcps" && pass "uses claude mcp list" || fail "missing claude mcp list"
grep -q 'disabledMcpServers' "$SCRIPT_DIR/bin/active-mcps" && pass "reads disabledMcpServers" || fail "missing disabled config"

# ── statusline.sh ─────────────────────────────────────────────────

section "statusline.sh"

[[ -x "$SCRIPT_DIR/statusline.sh" ]] && pass "is executable" || fail "not executable"

result=$(echo '{}' | bash "$SCRIPT_DIR/statusline.sh" 2>/dev/null) && pass "handles empty JSON" || fail "crashes on empty JSON"

result=$(echo '{"cwd":"/nonexistent"}' | bash "$SCRIPT_DIR/statusline.sh" 2>/dev/null) && pass "handles bad cwd" || fail "crashes on bad cwd"

result=$(echo '{"context_window":{"used_percentage":50}}' | bash "$SCRIPT_DIR/statusline.sh" 2>/dev/null)
echo "$result" | grep -q "ctx:" && pass "context % shown" || fail "context % missing"

result=$(echo '{"cost":{"total_cost_usd":5.67}}' | bash "$SCRIPT_DIR/statusline.sh" 2>/dev/null)
echo "$result" | grep -q "5.67" && pass "cost shown" || fail "cost missing"

result=$(echo '{"cost":{"total_cost_usd":0}}' | bash "$SCRIPT_DIR/statusline.sh" 2>/dev/null)
echo "$result" | grep -qv "0.00" && pass "zero cost hidden" || fail "zero cost should be hidden"

# Context color thresholds (green <50%, yellow 50-80%, red >80%)
# With default threshold=77, raw 30% → scaled ~39% → green
result=$(echo '{"context_window":{"used_percentage":30}}' | bash "$SCRIPT_DIR/statusline.sh" 2>/dev/null)
echo "$result" | grep -q $'\e\[38;5;114m''ctx:' && pass "low context → green" || fail "low context color"

# raw 50% → scaled ~65% → yellow
result=$(echo '{"context_window":{"used_percentage":50}}' | bash "$SCRIPT_DIR/statusline.sh" 2>/dev/null)
echo "$result" | grep -q $'\e\[38;5;220m''ctx:' && pass "mid context → yellow" || fail "mid context color"

# raw 75% → scaled ~97% → red
result=$(echo '{"context_window":{"used_percentage":75}}' | bash "$SCRIPT_DIR/statusline.sh" 2>/dev/null)
echo "$result" | grep -q $'\e\[38;5;196m''ctx:' && pass "high context → red" || fail "high context color"

# ── statusline --doctor ───────────────────────────────────────────

section "statusline.sh --doctor"

result=$(bash "$SCRIPT_DIR/statusline.sh" --doctor 2>/dev/null)
echo "$result" | grep -q "statusline doctor" && pass "--doctor runs" || fail "--doctor didn't run"
echo "$result" | grep -q "git" && pass "--doctor checks git" || fail "--doctor missing git check"
echo "$result" | grep -q "jq" && pass "--doctor checks jq" || fail "--doctor missing jq check"
echo "$result" | grep -q "settings.json" && pass "--doctor checks settings.json" || fail "--doctor missing settings check"

result=$(bash "$SCRIPT_DIR/statusline.sh" --doctor 2>/dev/null)
echo "$result" | grep -qE "[0-9]+ ok" && pass "--doctor shows summary" || fail "--doctor missing summary"

# ── install.sh ────────────────────────────────────────────────────

section "install.sh"

[[ -f "$SCRIPT_DIR/install.sh" ]] && pass "exists" || fail "missing"
grep -q 'chmod +x' "$SCRIPT_DIR/install.sh" && pass "sets executable bits" || fail "missing chmod"
grep -q 'active-mcps' "$SCRIPT_DIR/install.sh" && pass "installs active-mcps" || fail "missing active-mcps install"
grep -q 'settings.json\|SETTINGS_FILE' "$SCRIPT_DIR/install.sh" && pass "auto-configures settings.json" || fail "missing settings.json auto-config"

# ── localhost-ports ───────────────────────────────────────────────

section "bin/localhost-ports"

[[ -f "$SCRIPT_DIR/bin/localhost-ports" ]] && pass "exists" || fail "missing"
[[ -x "$SCRIPT_DIR/bin/localhost-ports" ]] && pass "is executable" || fail "not executable"
grep -q 'lsof' "$SCRIPT_DIR/bin/localhost-ports" && pass "uses lsof" || fail "missing lsof"
grep -q 'CACHE_TTL' "$SCRIPT_DIR/bin/localhost-ports" && pass "has cache TTL" || fail "missing cache TTL"
grep -q 'lock_file' "$SCRIPT_DIR/bin/localhost-ports" && pass "has file locking" || fail "missing lock"

# ── summary ───────────────────────────────────────────────────────

printf "\n\033[1m%d passed, %d failed\033[0m\n" "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
