#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
guard="$repo_root/scripts/check-canonical-randomness.sh"
fixture_root="$(mktemp -d)"
trap 'rm -rf "$fixture_root"' EXIT

mkdir -p "$fixture_root/allowed/nested"
cat >"$fixture_root/allowed/nested/Deterministic.luau" <<'LUAU'
local DeterministicRng = {}

function DeterministicRng.nextU32(state)
	return bit32.bxor(state, 0x9E3779B9)
end

return DeterministicRng
LUAU

bash "$guard" "$fixture_root/allowed" >/dev/null

assert_rejected() {
  local name="$1"
  local source="$2"
  local case_root="$fixture_root/$name"
  local output="$fixture_root/$name.out"

  mkdir -p "$case_root"
  printf '%s\n' "$source" >"$case_root/Forbidden.luau"

  if bash "$guard" "$case_root" >"$output" 2>&1; then
    echo "FAIL canonical randomness guard self-test: $name was accepted" >&2
    cat "$output" >&2
    exit 1
  fi

  if ! grep -q 'Forbidden.luau:1:' "$output"; then
    echo "FAIL canonical randomness guard self-test: $name did not report file and line" >&2
    cat "$output" >&2
    exit 1
  fi
}

assert_rejected "math-random" 'local value = math.random()'
assert_rejected "math-randomseed" 'math.randomseed(1234)'
assert_rejected "roblox-random" 'local rng = Random.new(1234)'

echo "PASS canonical randomness guard self-test"
