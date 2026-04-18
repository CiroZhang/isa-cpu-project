#!/usr/bin/env bash
# =============================================================================
#  run.sh  —  assemble + simulate the 9-bit ISA CPU
#
#  Usage:
#    ./run.sh <program.asm> <input_mem.txt> [output_mem.txt]
#
#  Inputs:
#    program.asm   — assembly source (see assembler.py for syntax)
#    input_mem.txt — initial data memory; two accepted formats:
#                      • 256 lines of 8-bit binary  (00001010 ...)
#                      • sparse addr:value pairs    (64: 0xFF  or  64: 100)
#                      • empty file → all zeros
#
#  Output:
#    output_mem.txt (default) — final data memory, 256 lines of 8-bit binary
#    Non-zero locations are also printed to stdout for quick inspection.
# =============================================================================
set -euo pipefail

# ---- locate files relative to this script ------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RTL_DIR="$SCRIPT_DIR/rtl"
ASM_PY="$SCRIPT_DIR/assembler.py"

# ---- usage -------------------------------------------------------------------
usage() {
  sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^#  \{0,1\}//'
  exit 1
}
[[ $# -lt 2 ]] && usage

# ---- args --------------------------------------------------------------------
ASM_FILE="$1"
INPUT_MEM="$2"
OUTPUT_MEM="${3:-output_mem.txt}"

# make OUTPUT_MEM absolute so it still works after cd to TMPDIR
[[ "$OUTPUT_MEM" != /* ]] && OUTPUT_MEM="$(pwd)/$OUTPUT_MEM"

# ---- sanity checks -----------------------------------------------------------
[[ -f "$ASM_FILE"  ]] || { echo "Error: assembly file not found: $ASM_FILE"   >&2; exit 1; }
[[ -f "$INPUT_MEM" ]] || { echo "Error: input memory file not found: $INPUT_MEM" >&2; exit 1; }
[[ -f "$ASM_PY"    ]] || { echo "Error: assembler.py not found at $ASM_PY"    >&2; exit 1; }
command -v python3   >/dev/null || { echo "Error: python3 not found" >&2; exit 1; }
command -v iverilog  >/dev/null || { echo "Error: iverilog not found" >&2; exit 1; }
command -v vvp       >/dev/null || { echo "Error: vvp not found" >&2; exit 1; }

# ---- temp workspace ----------------------------------------------------------
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "=============================="
echo "  CSE 141L CPU Runner"
echo "=============================="
printf "  Source  : %s\n"   "$ASM_FILE"
printf "  Mem in  : %s\n"   "$INPUT_MEM"
printf "  Mem out : %s\n\n" "$OUTPUT_MEM"

# ==============================================================================
# Step 1 — Assemble
# ==============================================================================
echo "[1/3] Assembling..."
python3 "$ASM_PY" "$ASM_FILE" -o "$WORK/program.txt" -q 2>&1 \
  || { echo "Assembler failed." >&2; exit 1; }
echo "      OK — $(grep -c '^[01]' "$WORK/program.txt") instructions"

# ==============================================================================
# Step 2 — Convert input memory to full 256-line binary file
# ==============================================================================
echo "[2/3] Preparing data memory..."
python3 - "$INPUT_MEM" "$WORK/input_mem.txt" <<'PYEOF'
import sys, re

src_path = sys.argv[1]
dst_path = sys.argv[2]
mem = [0] * 256

try:
    raw = open(src_path).read().splitlines()
except FileNotFoundError:
    raw = []

# strip comments and blank lines
lines = []
for l in raw:
    l = l.split(';')[0].split('//')[0].strip()
    if l:
        lines.append(l)

def parse_val(s):
    s = s.strip()
    if s.startswith(('0x', '0X')): return int(s, 16)
    if s.startswith(('0b', '0B')): return int(s, 2)
    return int(s)

if lines:
    # detect format: if every line is 1-8 binary chars → full binary dump
    if all(re.fullmatch(r'[01]{1,8}', l) for l in lines):
        for i, l in enumerate(lines[:256]):
            mem[i] = int(l, 2)
    else:
        # sparse addr: value format
        for l in lines:
            if ':' not in l:
                sys.exit(f"Bad memory line (expected 'addr: value'): {l!r}")
            a, v = l.split(':', 1)
            addr = parse_val(a)
            val  = parse_val(v)
            if not 0 <= addr < 256:
                sys.exit(f"Memory address {addr} out of range 0-255")
            mem[addr] = val & 0xFF

with open(dst_path, 'w') as f:
    for b in mem:
        f.write(f'{b:08b}\n')
PYEOF
echo "      OK"

# ==============================================================================
# Step 3 — Generate runner testbench
# ==============================================================================
cat > "$WORK/runner_tb.sv" <<'SVEOF'
`timescale 1ns/1ps
// Auto-generated runner testbench
module runner_tb;

  reg  clk   = 0;
  reg  start = 1;
  wire done;

  DUT dut (.clk, .start, .done);

  always #5 clk = ~clk;   // 10 ns / 100 MHz

  // ---------- timeout watchdog (50 000 cycles = 500 µs) ----------
  initial begin
    #500000;
    $display("ERROR: simulation timeout — DONE never asserted.");
    $display("       Check that your program ends with DONE.");
    $finish;
  end

  // ---------- main ----------
  integer f, i;

  initial begin
    // initialise data memory from file
    $readmemb("input_mem.txt", dut.dm.core);
    // match official test bench: min starts at max, max starts at 0
    dut.dm.core[66] = 8'hff;
    dut.dm.core[67] = 8'hff;

    // hold start=1 for 10 clock cycles (resets PC and flags)
    #100;
    start = 0;

    // run until DONE
    wait (done);
    #20;   // let the last write settle

    // write final memory to file (256 lines of 8-bit binary)
    f = $fopen("final_mem.txt", "w");
    for (i = 0; i < 256; i = i + 1)
      $fdisplay(f, "%08b", dut.dm.core[i]);
    $fclose(f);

    // print non-zero locations for quick inspection
    $display("--- Non-zero memory after execution ---");
    for (i = 0; i < 256; i = i + 1)
      if (dut.dm.core[i] !== 8'h00)
        $display("  mem[%0d] = %0d  (0x%02h  %08b)",
                 i, dut.dm.core[i], dut.dm.core[i], dut.dm.core[i]);

    $display("Simulation complete.");
    $finish;
  end

endmodule
SVEOF

# ==============================================================================
# Step 3 — Compile
# ==============================================================================
echo "[3/3] Compiling RTL..."
iverilog -g2012 \
  -o "$WORK/sim" \
  "$WORK/runner_tb.sv" \
  "$RTL_DIR/DUT.sv" \
  "$RTL_DIR/execute.sv" \
  "$RTL_DIR/reg_file.sv" \
  "$RTL_DIR/dat_mem.sv" \
  "$RTL_DIR/inst_mem.sv" \
  2>"$WORK/iverilog_stderr.txt" || {
    # on failure, show errors (filter out harmless "sorry:" warnings)
    grep -v "^$" "$WORK/iverilog_stderr.txt" | grep -v "sorry:" >&2 || true
    echo "Compilation failed." >&2
    exit 1
  }
# show any real warnings (not the "sorry:" iverilog quirks)
grep -v "sorry:" "$WORK/iverilog_stderr.txt" | grep -v "^$" || true
echo "      OK"

# ==============================================================================
# Step 4 — Simulate (run from WORK so $readmemb paths resolve correctly)
# ==============================================================================
echo ""
echo "--- Simulation output ---"
(cd "$WORK" && vvp sim)

# ==============================================================================
# Step 5 — Copy output
# ==============================================================================
cp "$WORK/final_mem.txt" "$OUTPUT_MEM"
echo ""
echo "Final memory → $OUTPUT_MEM"
