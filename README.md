CSE 141L Term Project — README
Student: Ciro Zhang
===============================================================

PROGRAMS — WHAT WORKS
---------------------------------------------------------------

All three programs are fully implemented and pass all 10/10
test cases provided by the course Test branch.

Program 1 — Minimum and Maximum Hamming Distance
  Computes the minimum and maximum Hamming (bit-difference)
  distance across all pairs of 32 signed 16-bit values stored
  in data memory [0:63].
  Results: mem[64] = min Hamming distance
           mem[65] = max Hamming distance
  Status: PASS 10/10

Program 2 — Minimum and Maximum Arithmetic Distance
  Computes the minimum and maximum absolute arithmetic difference
  across all pairs of 32 signed 16-bit values stored in data
  memory [0:63]. Results are stored as unsigned 16-bit values.
  Results: mem[66:67] = min |diff| (big-endian)
           mem[68:69] = max |diff| (big-endian)
  Status: PASS 10/10 (min and max)

Program 3 — 16-bit × 16-bit Signed Multiplication
  Computes 16 signed 32-bit products from 16 pairs of signed
  16-bit values stored in data memory [0:63].
  Results: mem[64+4k .. 67+4k] = product k, big-endian (k=0..15)
  Status: PASS 10/10 (16/16 pairs per test)

PROGRAMS — WHAT DOESN'T WORK
---------------------------------------------------------------

All three programs pass all provided test cases. No known
failures.

DESIGN NOTES
---------------------------------------------------------------

ISA:
  - 9-bit fixed-length instructions
  - 8-bit data path
  - 14 opcodes across 4 instruction types
  - Custom instructions: SIGN (sets borrow = sign bit of Rd),
    used for signed multiplication correction in Program 3

Instruction Memory:
  - 512 entries (9-bit address), well within the 2^10 soft limit
  - P1 starts at address 0, P2 at 64, P3 at 192

HOW TO RUN
---------------------------------------------------------------

Assemble and simulate a single program:
  bash run.sh assembly_files/p1.asm <test_input.txt>
  bash run.sh assembly_files/p2.asm <test_input.txt>
  bash run.sh assembly_files/p3.asm <test_input.txt>

Run all programs against all 10 test cases:
  bash test_all.sh

Test input files are in: test benches/test_files/test0.txt .. test9.txt

ZOOM VIDEO LINK
---------------------------------------------------------------

.....
