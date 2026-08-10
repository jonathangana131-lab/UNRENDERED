#!/usr/bin/env bash
set -euo pipefail

scan_root="${1:-src/shared}"

if [[ ! -d "$scan_root" ]]; then
  echo "ERROR canonical randomness guard: scan root does not exist: $scan_root" >&2
  exit 2
fi

mapfile -t source_files < <(find "$scan_root" -type f \( -name '*.luau' -o -name '*.lua' \) -print | LC_ALL=C sort)

if (( ${#source_files[@]} == 0 )); then
  echo "ERROR canonical randomness guard: no Luau/Lua source files found under $scan_root" >&2
  exit 2
fi

forbidden_pattern='(^|[^[:alnum:]_])math[[:space:]]*\.[[:space:]]*(random|randomseed)[[:space:]]*\(|(^|[^[:alnum:]_])Random[[:space:]]*\.[[:space:]]*new[[:space:]]*\('
violations_file="$(mktemp)"
trap 'rm -f "$violations_file"' EXIT

if grep -nHE "$forbidden_pattern" "${source_files[@]}" >"$violations_file"; then
  echo "ERROR canonical randomness guard: uncontrolled RNG API found in shared canonical source." >&2
  echo "Use the project deterministic/scoped RNG contract instead of math.random, math.randomseed, or Random.new." >&2
  cat "$violations_file" >&2
  exit 1
fi

echo "PASS canonical randomness guard: ${#source_files[@]} source file(s) checked under $scan_root"
