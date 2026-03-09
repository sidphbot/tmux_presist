#!/usr/bin/env bash
#
# Run all tests for tmux-freeze/tmux-thaw
#
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
overall_exit=0

echo "tmux-freeze/tmux-thaw test suite"
echo "================================"
echo ""

for test_file in "$TESTS_DIR"/test-*.sh; do
  [ -f "$test_file" ] || continue

  if [ "${1:-}" = "--unit" ] && [[ "$(basename "$test_file")" != "test-skip-patterns.sh" ]]; then
    echo "=== Skipping $(basename "$test_file") (--unit mode) ==="
    echo ""
    continue
  fi

  bash "$test_file"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    overall_exit=1
  fi
  echo ""
done

if [ "$overall_exit" -eq 0 ]; then
  echo "All test suites passed."
else
  echo "Some tests failed."
fi

exit $overall_exit
