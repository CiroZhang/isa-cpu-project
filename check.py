#!/usr/bin/env python3
"""Verify simulation output against expected answers for P1, P2, P3."""
import sys

def load_mem(path):
    lines = open(path).read().split()
    mem = [int(l, 2) for l in lines if l.strip()]
    while len(mem) < 256: mem.append(0)
    return mem

def load_input(path):
    return load_mem(path)

def load_output(path):
    return load_mem(path)

def signed16(v):
    return v - 65536 if v >= 32768 else v

program = sys.argv[1]
input_path = sys.argv[2]
output_path = sys.argv[3]

mem_in  = load_input(input_path)
mem_out = load_output(output_path)

if program == 'p1':
    vals = [(mem_in[2*k] << 8) | mem_in[2*k+1] for k in range(32)]
    diffs = [bin(vals[a] ^ vals[b]).count('1')
             for a in range(32) for b in range(a+1, 32)]
    exp_min, exp_max = min(diffs), max(diffs)
    got_min, got_max = mem_out[64], mem_out[65]
    ok = got_min == exp_min and got_max == exp_max
    print(f"min={got_min}(exp {exp_min}) max={got_max}(exp {exp_max}) → {'PASS' if ok else 'FAIL'}")

elif program == 'p2':
    vals = [signed16((mem_in[2*k] << 8) | mem_in[2*k+1]) for k in range(32)]
    diffs = [abs(vals[a] - vals[b]) for a in range(32) for b in range(a+1, 32)]
    exp_min, exp_max = min(diffs), max(diffs)
    got_min = (mem_out[66] << 8) | mem_out[67]
    got_max = (mem_out[68] << 8) | mem_out[69]
    min_ok = got_min == exp_min
    max_ok = got_max == exp_max
    print(f"min={got_min}(exp {exp_min}) → {'PASS' if min_ok else 'FAIL'}  "
          f"max={got_max}(exp {exp_max}) → {'PASS' if max_ok else 'FAIL'}")

elif program == 'p3':
    correct = 0
    for j in range(16):
        A = signed16((mem_in[4*j] << 8) | mem_in[4*j+1])
        B = signed16((mem_in[4*j+2] << 8) | mem_in[4*j+3])
        p = (A * B) & 0xFFFFFFFF
        base = 64 + 4*j
        got = ((mem_out[base] << 24) | (mem_out[base+1] << 16) |
               (mem_out[base+2] << 8) | mem_out[base+3])
        if got == p:
            correct += 1
    print(f"{correct}/16 pairs → {'PASS' if correct == 16 else 'FAIL'}")
