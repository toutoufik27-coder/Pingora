#!/usr/bin/env bash
# Syntax-checks every Luau file and runs the unit tests for src/shared.
# Builds the small Rust-based Luau runner on first use (needs cargo).
set -euo pipefail
cd "$(dirname "$0")/.."
RUNNER="${LUAU_RUNNER:-tools/luau-runner/target/release/luau-runner}"
if [ ! -x "$RUNNER" ]; then
  cargo build --release --manifest-path tools/luau-runner/Cargo.toml -q
fi
"$RUNNER" check src tests
"$RUNNER" run tests/harness.luau
