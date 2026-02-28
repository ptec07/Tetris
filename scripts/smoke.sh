#!/usr/bin/env bash
set -euo pipefail

set +e
cd "$(cd "$(dirname "$0")/.." && pwd)"

zig build run > /tmp/tetris-smoke.log 2>&1 &
pid=$!

sleep 5
kill "$pid" >/dev/null 2>&1 || true
wait "$pid" >/dev/null 2>&1 || true

echo "Smoke test complete. Log:" >&2
cat /tmp/tetris-smoke.log >&2
