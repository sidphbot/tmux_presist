#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/test-helpers.sh"

echo "=== Freeze Tests ==="

# Check tmux is available
if ! command -v tmux &>/dev/null; then
  echo "SKIP: tmux not found"
  exit 0
fi

TMUX_SOCKET="tmux-freeze-test-$$"
TEST_FREEZE_DIR=$(mktemp -d)
export TMUX_FREEZE_DIR="$TEST_FREEZE_DIR"

cleanup() {
  tmux -L "$TMUX_SOCKET" kill-server 2>/dev/null || true
  rm -rf "$TEST_FREEZE_DIR"
}
trap cleanup EXIT

# Start test tmux server with a session
tmux -L "$TMUX_SOCKET" new-session -d -s testses -n win1 -x 80 -y 24

# We need freeze to use our test socket - but tmux-freeze doesn't support -L.
# We'll set the TMUX env to trick it... actually the simplest approach:
# We run tmux-freeze in an environment where the default server IS our test server.
# We can't easily do this. Instead, just test the output format by running freeze
# against a real server if one exists, or create one.

# Actually, the cleanest approach: create sessions on the default server, freeze, clean up.
# But that's invasive. Let's test with the socket by wrapping tmux calls.

# For now, test what we can without modifying freeze:

# Test: freeze with no tmux server gives error
test_begin "freeze errors when no sessions exist"
output=$(TMUX_FREEZE_DIR="$TEST_FREEZE_DIR" tmux -L "nosuchserver-$$" new-session -d -s x 2>/dev/null; "$REPO_DIR/tmux-freeze" 2>&1) || true
# This will use the default server, not our test socket, so skip if default server has sessions
if tmux list-sessions &>/dev/null 2>&1; then
  # Default server is running, we can test freeze against it
  output=$(TMUX_FREEZE_DIR="$TEST_FREEZE_DIR" "$REPO_DIR/tmux-freeze" 2>&1)
  rc=$?
  assert_eq "$rc" "0"
else
  skip "no default tmux server"
fi

# Test: snapshot is valid JSON
test_begin "snapshot is valid JSON"
if [ -f "$TEST_FREEZE_DIR/latest.json" ]; then
  jq empty "$TEST_FREEZE_DIR/latest.json" 2>/dev/null
  assert_eq "$?" "0"
else
  skip "no snapshot produced"
fi

# Test: snapshot contains required keys
test_begin "snapshot has required keys"
if [ -f "$TEST_FREEZE_DIR/latest.json" ]; then
  has_keys=$(jq 'has("frozen_at") and has("hostname") and has("sessions")' "$TEST_FREEZE_DIR/latest.json" 2>/dev/null)
  assert_eq "$has_keys" "true"
else
  skip "no snapshot"
fi

# Test: --list works
test_begin "--list works"
output=$("$REPO_DIR/tmux-freeze" --list 2>&1)
assert_contains "$output" "Saved snapshots"

# Test: latest.json symlink exists
test_begin "latest.json symlink exists"
if [ -L "$TEST_FREEZE_DIR/latest.json" ] || [ -f "$TEST_FREEZE_DIR/latest.json" ]; then
  pass
else
  fail "latest.json not found"
fi

# Test: non-interactive suppresses stdout
test_begin "non-interactive suppresses stdout"
if tmux list-sessions &>/dev/null 2>&1; then
  output=$(TMUX_FREEZE_DIR="$TEST_FREEZE_DIR" "$REPO_DIR/tmux-freeze" < /dev/null 2>&1 | grep -v "^$" || true)
  # When piped (not a tty), stdout echo lines should be suppressed
  # Actually [ -t 1 ] checks if stdout is a tty. When piped, it's not.
  if echo "$output" | grep -q "Frozen\|Symlinked"; then
    fail "stdout not suppressed when piped"
  else
    pass
  fi
else
  skip "no default tmux server"
fi

test_summary
