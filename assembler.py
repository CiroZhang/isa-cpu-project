#!/usr/bin/env python3
"""
Assembler for the custom 9-bit ISA (execute.sv is the source of truth).

Usage
-----
    python assembler.py program.asm [-o program.txt] [-m data_mem.txt] [-q]

Instruction syntax
------------------
  Type 1  [op(4)|Rd(3)|Rs(2)]  — Rs must be R0-R3
    ADD   Rd, Rs    Rd = Rd + Rs + carry_in
    ADDX  Rd, Rs    Rd = Rd + Rs + carry_in   (Rs must be R4-R7; encoded as Rs-4)
    SUB   Rd, Rs    Rd = Rd - Rs - borrow_in
    SUBX  Rd, Rs    Rd = Rd - Rs - borrow_in  (Rs must be R4-R7; encoded as Rs-4)
    MUL   Rd, Rs    Rd = (Rd * Rs)[7:0]
    MULC  Rd, Rs    Rd = (Rd * Rs)[15:8]
    STR   Rd, Rs    mem[Rs] = Rd              (Rs is address register, R0-R3 only)
    LD    Rd, Rs    Rd = mem[Rs]              (Rs is address register, R0-R3 only)
    XOR  Rd, Rs    Rd = d ^ Rs

  Type 2  [op(4)|Rd(3)|imm(2)]  — Rd can be R0-R7, imm is 0-3
    SHIFT Rd, L1|L2|R1|R2       L1=left×1, L2=left×2, R1=right×1, R2=right×2
    LDI   Rd, #imm               Rd = imm  (0-3)
    ADDI  Rd, #imm               Rd = Rd + imm
    SUBI  Rd, #imm               Rd = Rd - imm

  Type 3  [op(4)|offset(5)]  — PC-relative, step = offset*2, range -32..+30
    BBS   label    if borrow: branch
    J     label    unconditional jump
    (target must be at an even address offset from the branch instruction)

  Type 4  [1111|Rd(3)|func(2)]
    NOT   Rd        Rd = ~Rd              (func=00)
    COU   Rd        Rd = popcount(Rd)     (func=01)
    SIGN  Rd        borrow = Rd[7]        (func=10, borrow=1 if negative)
    DONE            signal program done   (func=11, writes mem[192])

Directives
----------
    .text           switch to code section (default)
    .data           switch to memory-init section
    .org <addr>     set current code address (decimal / 0xHH / 0bBB)
    label:          define label at current instruction address

Memory init (.data section)
    <addr>: <value>     addr and value can be decimal, 0xHH, or 0bBB

ADDX / SUBX note
----------------
  ADDX reads the source from R4-R7; specify the actual high register:
    ADDX R2, R5    →  R2 = R2 + R5 + carry_in  (encodes Rs field = 5-4 = 1)
    ADDX R0, R7    →  R0 = R0 + R7 + carry_in  (encodes Rs field = 7-4 = 3)
  Rs must be R4-R7.  Rd can be any register R0-R7.
  (Same rules apply to SUBX.)

Branch offset constraint
------------------------
  BBS/J use next_pc = pc + offset*2. The target label must be at an even
  address offset from the branch instruction. The assembler reports an error
  if this is violated.
"""

import sys
import re
import argparse
from pathlib import Path

# ---------------------------------------------------------------------------
# ISA constants
# ---------------------------------------------------------------------------
OPCODE = {
    'ADD':   0b0000, 'ADDX':  0b0001,
    'SUB':   0b0010, 'SUBX':  0b0011,
    'MUL':   0b0100, 'MULC':  0b0101,
    'STR':   0b0110, 'LD':    0b0111,
    'XOR':   0b1000,
    'SHIFT': 0b1001, 'LDI':   0b1010,
    'ADDI':  0b1011, 'SUBI':  0b1100,
    'BBS':   0b1101,
    'J':     0b1110,
    # opcode 1111 = Type 4, handled separately via TYPE4_FUNC
}

# Type 4 function field (opcode always 0b1111)
TYPE4_FUNC = {
    'NOT':  0b00,
    'COU':  0b01,
    'SIGN': 0b10,
    'DONE': 0b11,
}

# SHIFT imm encoding: direction + amount
SHIFT_IMM = {'L1': 0b00, 'L2': 0b01, 'R1': 0b10, 'R2': 0b11}

INST_MEM_DEPTH = 256
DATA_MEM_DEPTH = 256

# ---------------------------------------------------------------------------
# Utility helpers
# ---------------------------------------------------------------------------
def parse_int(s):
    """Parse decimal, 0xHH, or 0bBB integer string."""
    s = s.strip()
    if s.startswith(('0x', '0X')):
        return int(s, 16)
    if s.startswith(('0b', '0B')):
        return int(s, 2)
    return int(s)


def parse_reg(s):
    """'R0'-'R7' → 0-7, raises ValueError on bad input."""
    s = s.strip().upper()
    if not re.fullmatch(r'R[0-7]', s):
        raise ValueError(f"invalid register '{s}' (expected R0-R7)")
    return int(s[1])


def strip_comment(line):
    """Remove ; or // line comments. # is NOT a comment char (used for immediates)."""
    i = line.find(';')
    if i != -1:
        line = line[:i]
    i = line.find('//')
    if i != -1:
        line = line[:i]
    return line.strip()


# ---------------------------------------------------------------------------
# Instruction encoding functions
# ---------------------------------------------------------------------------
def enc_t1(op, rd, rs):
    """Type 1: [op(4) | Rd(3) | Rs(2)] → 9-bit int."""
    return (op << 5) | ((rd & 0x7) << 2) | (rs & 0x3)


def enc_t2(op, rd, imm):
    """Type 2: [op(4) | Rd(3) | imm(2)] → 9-bit int."""
    return (op << 5) | ((rd & 0x7) << 2) | (imm & 0x3)


def enc_t3(op, offset):
    """Type 3: [op(4) | offset(5)] → 9-bit int. offset is signed [-16, 15]."""
    return (op << 5) | (offset & 0x1F)


def enc_t4(rd, func):
    """Type 4: [1111 | Rd(3) | func(2)] → 9-bit int."""
    return (0b1111 << 5) | ((rd & 0x7) << 2) | (func & 0x3)


def fmt9(v):
    return f'{v & 0x1FF:09b}'


def fmt8(v):
    return f'{v & 0xFF:08b}'


# ---------------------------------------------------------------------------
# Assembler
# ---------------------------------------------------------------------------
class AsmError(Exception):
    pass


class Assembler:
    def __init__(self):
        self.stmts = []         # list of (addr, lineno, text)
        self.data_mem = {}      # addr → byte value
        self.labels = {}        # name → addr
        self._errors = []       # (lineno_or_None, message)

    # -------- error helpers --------
    def _err(self, msg, lineno=None):
        self._errors.append((lineno, msg))

    def errors_as_strings(self):
        out = []
        for lineno, msg in self._errors:
            prefix = f"line {lineno}: " if lineno else ""
            out.append(prefix + msg)
        return out

    # -------- pass 1: collect labels, data, build stmt list --------
    def pass1(self, lines):
        section = 'text'
        addr = 0

        for lineno, raw in enumerate(lines, 1):
            line = strip_comment(raw)
            if not line:
                continue

            low = line.lower()

            # section switch
            if low == '.text':
                section = 'text'
                continue
            if low == '.data':
                section = 'data'
                continue

            # .org directive
            m = re.fullmatch(r'\.org\s+(\S+)', low)
            if m:
                try:
                    addr = parse_int(m.group(1))
                except ValueError:
                    self._err(f"bad .org value '{m.group(1)}'", lineno)
                continue

            # data section: addr: value
            if section == 'data':
                self._parse_data(line, lineno)
                continue

            # label-only line: "name:"
            if re.fullmatch(r'[A-Za-z_]\w*\s*:', line):
                lbl = line.rstrip(':').strip()
                self._define_label(lbl, addr, lineno)
                continue

            # inline label: "name: INSTR ..."
            m = re.match(r'([A-Za-z_]\w*)\s*:(.*)', line)
            if m:
                lbl  = m.group(1)
                rest = m.group(2).strip()
                self._define_label(lbl, addr, lineno)
                if rest:
                    self.stmts.append((addr, lineno, rest))
                    addr += 1
                continue

            # plain instruction
            self.stmts.append((addr, lineno, line))
            addr += 1

    def _define_label(self, name, addr, lineno):
        if name in self.labels:
            self._err(f"duplicate label '{name}'", lineno)
        else:
            self.labels[name] = addr

    def _parse_data(self, line, lineno):
        if ':' not in line:
            self._err(f"malformed .data line (expected 'addr: value'): {line!r}", lineno)
            return
        addr_s, val_s = line.split(':', 1)
        try:
            addr = parse_int(addr_s.strip())
            val  = parse_int(val_s.strip())
        except ValueError as e:
            self._err(str(e), lineno)
            return
        if not 0 <= addr < DATA_MEM_DEPTH:
            self._err(f"data address {addr} out of range 0-{DATA_MEM_DEPTH-1}", lineno)
            return
        if not 0 <= val <= 255:
            self._err(f"data value {val} out of range 0-255", lineno)
            return
        self.data_mem[addr] = val

    # -------- pass 2: encode each instruction --------
    def pass2(self):
        """Returns list of (addr, encoded_bits, original_text, note)."""
        result = []
        for addr, lineno, text in self.stmts:
            bits, note = self._encode(text, addr, lineno)
            result.append((addr, bits, text, note))
        return result

    def _encode(self, text, addr, lineno):
        tokens = text.split()
        mnemonic = tokens[0].upper()
        args = [t.rstrip(',').strip() for t in tokens[1:]]
        bits = 0
        note = ''
        try:
            if mnemonic in ('ADD', 'SUB'):
                bits, note = self._enc_addsub_auto(mnemonic, args)
            elif mnemonic in ('MUL', 'MULC', 'STR', 'LD', 'XOR'):
                bits = self._enc_type1(mnemonic, args)
            elif mnemonic == 'SHIFT':
                bits = self._enc_shift(args)
            elif mnemonic in ('LDI', 'ADDI', 'SUBI'):
                bits = self._enc_type2_imm(mnemonic, args)
            elif mnemonic in TYPE4_FUNC:
                bits = self._enc_type4(mnemonic, args)
            elif mnemonic in ('BBS', 'J'):
                bits, note = self._enc_branch(mnemonic, args, addr, lineno)
            else:
                self._err(f"unknown mnemonic '{mnemonic}'", lineno)
        except (ValueError, AsmError) as e:
            self._err(str(e), lineno)
        return bits, note

    # ---- Type 1: ADD / SUB — auto-select opcode based on Rs ----
    # ADD: Rs R0-R3 → opcode 0000 (direct)
    #      Rs R4-R7 → opcode 0001 (ADDX, encoded as Rs-4)
    # SUB: Rs R0-R3 → opcode 0011 (direct)
    #      Rs R4-R7 → opcode 0010 (encoded as Rs-4, hardware adds 4)
    def _enc_addsub_auto(self, mnemonic, args):
        if len(args) != 2:
            raise AsmError(f"{mnemonic}: expected Rd, Rs  (Rs can be R0-R7)")
        rd = parse_reg(args[0])
        rs = parse_reg(args[1])
        if mnemonic == 'ADD':
            if rs <= 3:
                return enc_t1(OPCODE['ADD'],  rd, rs), ''
            else:
                return enc_t1(OPCODE['ADDX'], rd, rs - 4), f'(auto ADDX, Rs field={rs-4})'
        else:  # SUB
            if rs <= 3:
                return enc_t1(OPCODE['SUBX'], rd, rs), ''
            else:
                return enc_t1(OPCODE['SUB'],  rd, rs - 4), f'(auto SUB high, Rs field={rs-4})'

    # ---- Type 1: MUL, MULC, STR, LD, BDIF (Rs must be R0-R3) ----
    def _enc_type1(self, mnemonic, args):
        if len(args) != 2:
            raise AsmError(f"{mnemonic}: expected Rd, Rs")
        rd = parse_reg(args[0])
        rs = parse_reg(args[1])
        if rs > 3:
            raise AsmError(
                f"{mnemonic}: Rs must be R0-R3 (got R{rs}). "
                "The Rs field is only 2 bits and can address R0-R3."
            )
        return enc_t1(OPCODE[mnemonic], rd, rs)

    # ---- Type 2: SHIFT ----
    def _enc_shift(self, args):
        if len(args) != 2:
            raise AsmError("SHIFT: expected  Rd, L1|L2|R1|R2")
        rd  = parse_reg(args[0])
        key = args[1].upper()
        if key not in SHIFT_IMM:
            raise AsmError(
                f"SHIFT: second arg must be L1, L2, R1, or R2 (got '{args[1]}')\n"
                "  L1=left×1  L2=left×2  R1=right×1  R2=right×2"
            )
        return enc_t2(OPCODE['SHIFT'], rd, SHIFT_IMM[key])

    # ---- Type 2: LDI, ADDI, SUBI ----
    def _enc_type2_imm(self, mnemonic, args):
        if len(args) != 2:
            raise AsmError(f"{mnemonic}: expected Rd, #imm")
        rd    = parse_reg(args[0])
        imm_s = args[1].lstrip('#')
        imm   = parse_int(imm_s)
        if not 0 <= imm <= 3:
            raise AsmError(f"{mnemonic}: immediate must be 0-3 (got {imm})")
        return enc_t2(OPCODE[mnemonic], rd, imm)

    # ---- Type 4: NOT, COU, DONE ----
    def _enc_type4(self, mnemonic, args):
        if mnemonic == 'DONE':
            if len(args) != 0:
                raise AsmError("DONE takes no arguments")
            return enc_t4(0, TYPE4_FUNC['DONE'])   # Rd field is don't-care
        else:
            if len(args) != 1:
                raise AsmError(f"{mnemonic}: expected Rd")
            rd = parse_reg(args[0])
            return enc_t4(rd, TYPE4_FUNC[mnemonic])

    # ---- Type 3: BBS / J ----
    def _enc_branch(self, mnemonic, args, addr, lineno):
        if len(args) != 1:
            raise AsmError(f"{mnemonic}: expected label or even step (-32..+30)")
        target_name = args[0]

        # numeric step: user writes the actual instruction-slot count (must be even, -32..+30)
        try:
            step = int(target_name)
            if step % 2 != 0:
                self._err(
                    f"{mnemonic}: numeric step {step} must be even "
                    "(hardware does PC + offset*2, so only even steps are reachable). "
                    "Valid range: -32..+30 in steps of 2.",
                    lineno
                )
                return 0, ''
            offset = step // 2
            if not -16 <= offset <= 15:
                self._err(
                    f"{mnemonic}: step {step} out of range -32..+30",
                    lineno
                )
                return 0, ''
            note = f"(offset={offset:+d}, step={step:+d})"
            return enc_t3(OPCODE[mnemonic], offset), note
        except ValueError:
            pass  # not a number — fall through to label lookup

        if target_name not in self.labels:
            self._err(f"undefined label '{target_name}'", lineno)
            return 0, ''
        target = self.labels[target_name]
        diff   = target - addr
        if diff % 2 != 0:
            self._err(
                f"{mnemonic}: target '{target_name}' is at odd offset {diff} "
                f"(branch@{addr}, target@{target}). "
                "ISA requires next_pc = pc + offset*2, so (target-pc) must be even.",
                lineno
            )
            return 0, ''
        offset = diff // 2
        if not -16 <= offset <= 15:
            self._err(
                f"{mnemonic}: offset {offset} out of 5-bit signed range [-16,15] "
                f"(branch@{addr}, target@{target}, diff={diff})",
                lineno
            )
            return 0, ''
        note = f"(offset={offset:+d}, step={diff:+d})"
        return enc_t3(OPCODE[mnemonic], offset), note

    # ---- top-level driver ----
    def assemble(self, source):
        self.pass1(source.splitlines())
        return self.pass2()


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
def write_program(encoded, path):
    prog = ['000000000'] * INST_MEM_DEPTH
    for addr, bits, _text, _note in encoded:
        if 0 <= addr < INST_MEM_DEPTH:
            prog[addr] = fmt9(bits)
        else:
            print(f"  Warning: instruction at address {addr} exceeds depth {INST_MEM_DEPTH}",
                  file=sys.stderr)
    path.write_text('\n'.join(prog) + '\n')


def write_data_mem(data_mem, path):
    mem = ['00000000'] * DATA_MEM_DEPTH
    for addr, val in data_mem.items():
        mem[addr] = fmt8(val)
    path.write_text('\n'.join(mem) + '\n')


def print_labels(labels):
    if not labels:
        return
    print("\n--- Labels ---")
    for name, addr in sorted(labels.items(), key=lambda x: x[1]):
        print(f"  [{addr:3d}]  0x{addr:02X}  {name}")


def print_listing(encoded, labels):
    # invert: addr → list of label names
    by_addr = {}
    for name, addr in labels.items():
        by_addr.setdefault(addr, []).append(name)

    print("\n--- Instruction Listing ---")
    print(f"  {'Addr':>4}  {'Binary':>9}  {'Source':<36}  Note")
    print(f"  {'-'*4}  {'-'*9}  {'-'*36}  {'-'*30}")
    for addr, bits, text, note in encoded:
        lbls = ', '.join(by_addr.get(addr, []))
        lbl_str = f"{lbls}:" if lbls else ''
        source  = f"{lbl_str:10s}{text}"
        print(f"  [{addr:3d}]  {fmt9(bits)}  {source:<36}  {note}")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(
        description='Assembler for the custom 9-bit ISA (execute.sv)',
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    ap.add_argument('input',  help='Assembly source file (.asm)')
    ap.add_argument('-o', '--output', default=None,
                    help='Program output file (default: <input>.txt)')
    ap.add_argument('-m', '--mem', default=None,
                    help='Data memory output file (default: data_mem.txt)')
    ap.add_argument('-q', '--quiet', action='store_true',
                    help='Suppress listing and label table')
    args = ap.parse_args()

    src_path = Path(args.input)
    if not src_path.exists():
        print(f"Error: '{src_path}' not found", file=sys.stderr)
        sys.exit(1)

    out_path = Path(args.output) if args.output else src_path.with_suffix('.txt')
    mem_path = Path(args.mem)    if args.mem    else Path('data_mem.txt')

    asm     = Assembler()
    encoded = asm.assemble(src_path.read_text())

    errs = asm.errors_as_strings()
    if errs:
        for e in errs:
            print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    write_program(encoded, out_path)
    print(f"Wrote {len(encoded)} instruction(s) → {out_path}")

    if asm.data_mem:
        write_data_mem(asm.data_mem, mem_path)
        print(f"Wrote {len(asm.data_mem)} data memory entries → {mem_path}")

    if not args.quiet:
        print_labels(asm.labels)
        print_listing(encoded, asm.labels)


if __name__ == '__main__':
    main()
