#!/usr/bin/env bash
# Minimal test helpers

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

test_begin() {
  printf "  %-50s " "$1"
  TESTS_RUN=$((TESTS_RUN + 1))
}

pass() {
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "OK"
}

fail() {
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "FAIL${1:+: $1}"
}

skip() {
  TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
  echo "SKIP${1:+: $1}"
}

assert_eq() {
  if [ "$1" = "$2" ]; then
    pass
  else
    fail "expected '$2', got '$1'"
  fi
}

assert_contains() {
  if echo "$1" | grep -qF "$2"; then
    pass
  else
    fail "output does not contain '$2'"
  fi
}

assert_exit() {
  local expected="$1"; shift
  local actual
  "$@" >/dev/null 2>&1
  actual=$?
  if [ "$actual" -eq "$expected" ]; then
    pass
  else
    fail "expected exit $expected, got $actual"
  fi
}

test_summary() {
  echo ""
  echo "Results: $TESTS_PASSED passed, $TESTS_FAILED failed, $TESTS_SKIPPED skipped (of $TESTS_RUN)"
  [ "$TESTS_FAILED" -eq 0 ]
}
