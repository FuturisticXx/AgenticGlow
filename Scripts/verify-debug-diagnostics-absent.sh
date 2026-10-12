#!/usr/bin/env bash
set -euo pipefail

# Proves that the DEBUG-only CloudKit verification facilities did not ship
# in a Release product, by searching every Mach-O in the bundle for their
# markers. Usage:
#
#   verify-debug-diagnostics-absent.sh absent  <Release .app> [...]
#   verify-debug-diagnostics-absent.sh present <Debug .app> [...]
#
# `present` is the control: it asserts the same markers ARE in a Debug
# build, so a passing `absent` cannot be explained by a stale marker list.

mode="${1:-}"
shift || true
[ "$mode" = "absent" ] || [ "$mode" = "present" ] || {
  echo "usage: $0 absent|present <bundle> [...]" >&2
  exit 2
}
[ "$#" -ge 1 ] || { echo "no bundles given" >&2; exit 2; }

# String literals the facilities emit, which survive in any build that
# compiled them and cannot be optimized away. Type and method names are
# deliberately not used: mangling and stripping make them unreliable.
markers=(
  "--verify-cloudkit-sync"
  "Publish & Verify"
  "Refresh & Verify"
  "Diagnostics (debug build)"
  "Published snapshot hash"
  "unexpected fields"
  "forbidden fields"
  "App Group cache read-back"
)

status=0
for bundle in "$@"; do
  test -d "$bundle" || { echo "not a bundle: $bundle" >&2; exit 2; }
  found=()
  table="$(mktemp)"
  while IFS= read -r -d '' binary; do
    file "$binary" | grep -q "Mach-O" || continue
    # One pass per binary into a file: a `strings | grep -q` pipeline
    # under pipefail reports the early-closed pipe as a miss.
    strings -a "$binary" > "$table" || true
    for marker in "${markers[@]}"; do
      if grep -Fq -- "$marker" "$table"; then
        found+=("$marker (${binary#"$bundle"/})")
      fi
    done
  done < <(find "$bundle" -type f \( -perm -u+x -o -name "*.dylib" \) -print0)
  rm -f "$table"

  if [ "$mode" = "absent" ]; then
    if [ "${#found[@]}" -eq 0 ]; then
      echo "PASS: no debug diagnostics in $bundle"
    else
      echo "FAIL: debug diagnostics present in $bundle:" >&2
      printf '  %s\n' "${found[@]}" >&2
      status=1
    fi
  else
    # The verifier's own report strings are shared by both platforms; the
    # action titles differ per platform, so only the shared set is required.
    missing=()
    for marker in "Published snapshot hash" "unexpected fields" "forbidden fields"; do
      printf '%s\n' "${found[@]:-}" | grep -Fq -- "$marker" || missing+=("$marker")
    done
    if [ "${#missing[@]}" -eq 0 ]; then
      echo "PASS: debug diagnostics present in $bundle (${#found[@]} hits)"
    else
      echo "FAIL: control markers missing from the Debug build $bundle:" >&2
      printf '  %s\n' "${missing[@]}" >&2
      status=1
    fi
  fi
done
exit "$status"
