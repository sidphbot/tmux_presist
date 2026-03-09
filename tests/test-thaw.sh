#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/test-helpers.sh"

echo "=== Thaw Tests ==="

if ! command -v tmux &>/dev/null; then
  echo "SKIP: tmux not found"
  exit 0
fi

if ! command -v jq &>/dev/null; then
  echo "SKIP: jq not found"
  exit 0
fi

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# Create a minimal test snapshot
create_test_snapshot() {
  local file="$1"
  local session_name="${2:-test-session}"
  cat > "$file" << SNAPSHOT
{
  "frozen_at": "2026-01-01T00:00:00+00:00",
  "hostname": "testhost",
  "tmux_version": "3.4",
  "sessions": [
    {
      "session_name": "$session_name",
      "base_index": 0,
      "active_window": 0,
      "windows": [
        {
          "index": 0,
          "name": "editor",
          "layout": null,
          "active": true,
          "active_pane": 0,
          "panes": [
            {
              "index": 0,
              "path": "$HOME",
              "command": "",
              "shell": "bash",
              "width": 80,
              "height": 24
            },
            {
              "index": 1,
              "path": "$HOME",
              "command": "",
              "shell": "bash",
              "width": 80,
              "height": 24
            }
          ]
        },
        {
          "index": 1,
          "name": "shell",
          "layout": null,
          "active": false,
          "active_pane": 0,
          "panes": [
            {
              "index": 0,
              "path": "$HOME",
              "command": "",
              "shell": "bash",
              "width": 80,
              "height": 24
            }
          ]
        }
      ]
    }
  ]
}
SNAPSHOT
}

# Test: --dry-run shows windows without creating session
test_begin "--dry-run shows layout without creating"
snapshot="$TEST_DIR/test1.json"
create_test_snapshot "$snapshot" "thaw-dryrun-$$"
output=$("$REPO_DIR/tmux-thaw" --dry-run "$snapshot" 2>&1)
rc=$?
# Should not have created the session
if tmux has-session -t "thaw-dryrun-$$" 2>/dev/null; then
  tmux kill-session -t "thaw-dryrun-$$" 2>/dev/null
  fail "session was created during dry-run"
else
  assert_eq "$rc" "0"
fi

# Test: dry-run output contains window info
test_begin "--dry-run output contains window info"
assert_contains "$output" "Window 0"

# Test: thaw creates session with correct windows
test_begin "thaw creates session with correct windows"
snapshot="$TEST_DIR/test2.json"
create_test_snapshot "$snapshot" "thaw-test-$$"
"$REPO_DIR/tmux-thaw" "$snapshot" >/dev/null 2>&1
win_count=$(tmux list-windows -t "thaw-test-$$" 2>/dev/null | wc -l)
tmux kill-session -t "thaw-test-$$" 2>/dev/null
assert_eq "$win_count" "2"

# Test: thaw creates correct number of panes
test_begin "thaw creates correct pane count"
snapshot="$TEST_DIR/test3.json"
create_test_snapshot "$snapshot" "thaw-panes-$$"
"$REPO_DIR/tmux-thaw" "$snapshot" >/dev/null 2>&1
pane_count=$(tmux list-panes -t "thaw-panes-$$:0" 2>/dev/null | wc -l)
tmux kill-session -t "thaw-panes-$$" 2>/dev/null
assert_eq "$pane_count" "2"

# Test: existing session is skipped
test_begin "existing session is skipped"
snapshot="$TEST_DIR/test4.json"
create_test_snapshot "$snapshot" "thaw-exists-$$"
tmux new-session -d -s "thaw-exists-$$" -x 80 -y 24 2>/dev/null
output=$("$REPO_DIR/tmux-thaw" "$snapshot" 2>&1)
tmux kill-session -t "thaw-exists-$$" 2>/dev/null
assert_contains "$output" "already exists"

# Test: invalid JSON is rejected
test_begin "invalid JSON is rejected"
echo "not json" > "$TEST_DIR/bad.json"
output=$("$REPO_DIR/tmux-thaw" "$TEST_DIR/bad.json" 2>&1) || true
assert_contains "$output" "invalid JSON"

# Test: missing file errors
test_begin "missing snapshot file errors"
output=$("$REPO_DIR/tmux-thaw" "$TEST_DIR/nonexistent.json" 2>&1) || true
assert_contains "$output" "not found"

# Test: --no-commands skips command execution
test_begin "--no-commands skips commands"
snapshot="$TEST_DIR/test5.json"
# Create snapshot with a command
cat > "$snapshot" << SNAPSHOT
{
  "frozen_at": "2026-01-01T00:00:00+00:00",
  "hostname": "testhost",
  "tmux_version": "3.4",
  "sessions": [{
    "session_name": "thaw-nocmd-$$",
    "base_index": 0,
    "active_window": 0,
    "windows": [{
      "index": 0,
      "name": "test",
      "layout": null,
      "active": true,
      "active_pane": 0,
      "panes": [{
        "index": 0,
        "path": "$HOME",
        "command": "echo thaw-marker-nocmd",
        "shell": "bash",
        "width": 80,
        "height": 24
      }]
    }]
  }]
}
SNAPSHOT
output=$("$REPO_DIR/tmux-thaw" --no-commands "$snapshot" 2>&1)
tmux kill-session -t "thaw-nocmd-$$" 2>/dev/null
# Should not contain the arrow indicating command was executed
if echo "$output" | grep -q "echo thaw-marker-nocmd"; then
  fail "command was shown as executed"
else
  pass
fi

test_summary
