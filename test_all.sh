#!/usr/bin/env bash
# Run all three programs against all 10 test cases and print pass/fail summary.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TB_DIR="$SCRIPT_DIR/test benches/test_files"
ASM_DIR="$SCRIPT_DIR/assembly_files"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

pass_p1=0; pass_p2_min=0; pass_p2_max=0; pass_p3=0; total=10

for i in $(seq 0 9); do
  TEST="$TB_DIR/test$i.txt"

  # ── P1 ──────────────────────────────────────────────────────────────
  bash "$SCRIPT_DIR/run.sh" "$ASM_DIR/p1.asm" "$TEST" "$TMP/out.txt" 2>/dev/null
  result=$(python3 "$SCRIPT_DIR/check.py" p1 "$TEST" "$TMP/out.txt")
  echo "$result" | grep -q "PASS" && ((pass_p1++)) || true
  echo "P1 test$i: $result"

  # ── P2 ──────────────────────────────────────────────────────────────
  bash "$SCRIPT_DIR/run.sh" "$ASM_DIR/p2.asm" "$TEST" "$TMP/out.txt" 2>/dev/null
  result=$(python3 "$SCRIPT_DIR/check.py" p2 "$TEST" "$TMP/out.txt")
  echo "$result" | grep -q "min.*PASS" && ((pass_p2_min++)) || true
  echo "$result" | grep -q "max.*PASS" && ((pass_p2_max++)) || true
  echo "P2 test$i: $result"

  # ── P3 ──────────────────────────────────────────────────────────────
  bash "$SCRIPT_DIR/run.sh" "$ASM_DIR/p3.asm" "$TEST" "$TMP/out.txt" 2>/dev/null
  result=$(python3 "$SCRIPT_DIR/check.py" p3 "$TEST" "$TMP/out.txt")
  echo "$result" | grep -q "PASS" && ((pass_p3++)) || true
  echo "P3 test$i: $result"
done

echo ""
echo "============================="
echo "  SUMMARY"
echo "============================="
printf "  P1:      %d/%d\n" $pass_p1 $total
printf "  P2 min:  %d/%d\n" $pass_p2_min $total
printf "  P2 max:  %d/%d\n" $pass_p2_max $total
printf "  P3:      %d/%d\n" $pass_p3 $total
