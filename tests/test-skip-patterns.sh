#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/test-helpers.sh"

echo "=== Skip Pattern Tests ==="

# Source tmux-thaw to get load_skip_patterns and SKIP_PATTERNS
# (the source guard prevents main logic from running)
source "$REPO_DIR/tmux-thaw"

# is_safe_command is defined after the source guard, so we can't get it by
# sourcing. Extract and eval it from the script directly.
eval "$(sed -n '/^is_safe_command()/,/^}/p' "$REPO_DIR/tmux-thaw")"

# Disable set -e so we can check non-zero return codes
set +e

# Test: load_skip_patterns loads defaults
test_begin "load_skip_patterns loads defaults"
SKIP_PATTERNS=()
load_skip_patterns
if [ "${#SKIP_PATTERNS[@]}" -ge 5 ]; then pass; else fail "expected >=5 defaults, got ${#SKIP_PATTERNS[@]}"; fi

# Test: claude is skipped by default
test_begin "claude is skipped (exact)"
is_safe_command "claude"; rc=$?
assert_eq "$rc" "1"

# Test: claude with args is skipped
test_begin "claude with args is skipped"
is_safe_command "claude --help"; rc=$?
assert_eq "$rc" "1"

# Test: aider is skipped
test_begin "aider is skipped"
is_safe_command "aider"; rc=$?
assert_eq "$rc" "1"

# Test: cursor is skipped
test_begin "cursor is skipped"
is_safe_command "cursor"; rc=$?
assert_eq "$rc" "1"

# Test: safe commands return 0
test_begin "vim is safe"
is_safe_command "vim file.txt"; rc=$?
assert_eq "$rc" "0"

test_begin "htop is safe"
is_safe_command "htop"; rc=$?
assert_eq "$rc" "0"

test_begin "watch is safe"
is_safe_command "watch ls"; rc=$?
assert_eq "$rc" "0"

# Test: dangerous commands return 1
test_begin "rm is dangerous"
is_safe_command "rm -rf /"; rc=$?
assert_eq "$rc" "1"

test_begin "dd is dangerous"
is_safe_command "dd if=/dev/zero"; rc=$?
assert_eq "$rc" "1"

# Test: unknown commands return 2
test_begin "unknown command returns 2"
is_safe_command "my-custom-app"; rc=$?
assert_eq "$rc" "2"

# Test: empty command returns 0
test_begin "empty command returns 0"
is_safe_command ""; rc=$?
assert_eq "$rc" "0"

# Test: custom config file adds patterns
test_begin "custom config file adds skip pattern"
tmpfile=$(mktemp)
echo "^my-stateful-app$" > "$tmpfile"
TMUX_THAW_SKIP_FILE="$tmpfile" load_skip_patterns
is_safe_command "my-stateful-app"; rc=$?
rm -f "$tmpfile"
assert_eq "$rc" "1"

# Test: config file comments and blanks are ignored
test_begin "config comments and blanks ignored"
tmpfile=$(mktemp)
cat > "$tmpfile" << 'EOF'
# This is a comment
  # Indented comment

^specific-tool$
EOF
TMUX_THAW_SKIP_FILE="$tmpfile" load_skip_patterns
count=${#SKIP_PATTERNS[@]}
rm -f "$tmpfile"
# Should have 5 defaults + 1 custom = 6
assert_eq "$count" "6"

# Test: nonexistent config file is fine (just uses defaults)
test_begin "missing config file uses defaults only"
TMUX_THAW_SKIP_FILE="/nonexistent/file" load_skip_patterns
if [ "${#SKIP_PATTERNS[@]}" -ge 5 ]; then pass; else fail "expected >=5, got ${#SKIP_PATTERNS[@]}"; fi

test_summary
