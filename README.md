# Custom 8-bit ISA Specification

## Overview
This ISA defines a compact 9-bit instruction format with four instruction types:
- Register–Register
- Register–Immediate
- Control Flow
- Special Operations

Registers are 8-bit. Arithmetic supports carry and borrow flags.

---

## Instruction Formats

### Type 1: Register–Register  
Format: `[4-bit opcode | 3-bit Rd | 2-bit Rs]`

| Instruction | Opcode | Description |
|------------|--------|------------|
| ADD  | 0000 | Rd = Rd + Rs + carry |
| ADDX | 0001 | Rd = Rd + Rs{+4} + carry |
| SUB  | 0010 | Rd = Rd - Rs{+4} - borrow |
| SUBX | 0011 | Rd = Rd - Rs - borrow |
| MUL  | 0100 | Rd = (Rd × Rs)[7:0] |
| MULC | 0101 | Rd = (Rd × Rs)[15:8] |
| STR  | 0110 | mem[Rs] = Rd |
| LD   | 0111 | Rd = mem[Rs] |
| XOR  | 1000 | Rd = Rd ^ Rs |

---

### Type 2: Register–Immediate  
Format: `[4-bit opcode | 3-bit Rd | 2-bit imm]`  
Immediate range: 0–3

| Instruction | Opcode | Description |
|------------|--------|------------|
| SHIFT | 1001 | If imm[1]=0 → Rd << (imm[0]+1) |
|       |      | If imm[1]=1 → Rd >> (imm[0]+1) |
| LDI   | 1010 | Rd = imm |
| ADDI  | 1011 | Rd = Rd + imm + carry |
| SUBI  | 1100 | Rd = Rd - imm - borrow |

---

### Type 3: Control Flow  
Format: `[4-bit opcode | 5-bit offset]`  
Offset range: -32 to +30 (step size = 2)

| Instruction | Opcode | Description |
|------------|--------|------------|
| BBS | 1101 | If borrow == 1 → PC = PC + offset × 2 |
| J   | 1110 | PC = PC + offset × 2 |

---

### Type 4: Special Operations  
Format: `[1111 | 3-bit Rd | 2-bit func]`

| Function | Code | Description |
|----------|------|------------|
| NOT  | 00 | Rd = ~Rd |
| COU  | 01 | Rd = popcount(Rd) |
| SIGN | 10 | borrow = sign(Rd) |
| DONE | 11 | Signal program completion |

---
