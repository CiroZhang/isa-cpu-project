// ================================================================================
// Type 1: [4-bit opcode | 3-bit Rd | 2-bit Rs]
// ================================================================================
// ADD     0000    Rd = Rd + Rs + carry            sets carry  
// ADDX    0001    Rd = Rd + Rs{+4} + carry            sets carry  
// SUB     0010    Rd = Rd - Rs{+4} - borrow           sets borrow
// SUBX    0011    Rd = Rd - Rs - borrow       sets borrow
// MUL     0100    Rd = Rd * Rs 'b{8:0}
// MULC    0101    Rd = Rd * Rs 'b{16:8}  
// STR     0110    mem[Rs] = Rd              
// LD      0111    Rd = mem[Rs] 
// XOR     1000    Rd = Rd ^ Rs
// ================================================================================
// Type 2: [4-bit opcode | 3-bit Rd | 2-bit imm]      imm range: 0-3  (2-bit)
// ================================================================================
// SHIFT   1001    if imm[1]=0: Rd = Rd << (imm[0]+1)   shift left  by 1 or 2
//                 if imm[1]=1: Rd = Rd >> (imm[0]+1)   shift right by 1 or 2
// LDI     1010    Rd = imm                              
// ADDI    1011    Rd = Rd + imm + carry         
// SUBI    1100    Rd = Rd - imm - borrow                   
// ================================================================================
// Type 3: [4-bit opcode | 5-bit offset]
// ================================================================================
// BBS     1101    if borrow == 1: PC = PC + offset * 2        offset range -32..+30
// J       1110    PC = PC + offset * 2                        offset range -32..+30
// ================================================================================
// Type 4: [1111 | 3-bit Rd | 2-bit fun]
// ================================================================================
// NOT     00    Rd = Not(Rd)       
// COU     01    Rd = count(Rd)               
// Sign    10    borrow = Sign(Rd)
// DONE    11    Set Done             
