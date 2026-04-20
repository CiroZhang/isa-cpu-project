LDI   r4 0                      ; r4 = 0
LDI   r7 1                      ; r7 = 1
SHIFT r7 L2                     ; r7 = 4
SHIFT r7 L2                     ; r7 = 16
SHIFT r7 L2                     ; r7 = 64

LDI  r0 0                       ; input_addr = 0

LDI  r1 0
ADD  r1 r0                      ; r1 = r0
ADD  r1 r7                      ; output_addr = r0 + 64
LDI   r2 0
ADD   r2 r0
SUB   r2 r7
BBS   2                         ; while input_addr  < 64
DONE
    
; -------- mem[output_addr + 3] --------
ADDI r1 3                   

ADDI r0 1                   
LD   r2 r0                  ; r2 = low1 = mem[input_addr+1] 
ADDI r0 2
LD   r3 r0                  ; r3 = low2 = mem[input_addr+3]
SUBI r0 3
MUL  r2 r3                  ; r2 = (low1 * low2)low
               
STR  r2 r1                  ; mem[output_addr + 3] = (low1 * low2)low


; -------- mem[output_addr + 2] --------
SUBI r1 1                

LDI  r6 0                  ; sum = 0
LDI  r5 0                  ; carry_sum = 0

ADDI r0 1                   
LD   r2 r0                  ; r2 = low1 = mem[input_addr+1] 
ADDI r0 2
LD   r3 r0                  ; r3 = low2 = mem[input_addr+3]
SUBI r0 3
MULC r2 r3                 ; r2 = (low1 * low2)high
ADD  r6 r2                 ; Sum += (low1 * low2)high
ADD  r5 r4                 ; carry_sum += carry

ADDI r0 1                   
LD   r2 r0                 ; r2 = low1 = mem[input_addr+1] 
ADDI r0 1
LD   r3 r0                 ; r3 = high2 = mem[input_addr+2]

J    2
J    -32


SUBI r0 2
MUL  r2 r3                 ; r2 = (low1 * high2)low
ADD  r6 r2                 ; Sum += (low1 * high2)low
ADD  r5 r4                 ; carry_sum += carry

ADDI r0 0
LD   r2 r0                 ; r2 = high1 = mem[input_addr]
ADDI r0 3
LD   r3 r0                 ; r3 = low2 = mem[input_addr+3]
SUBI r0 3
MUL  r2 r3                 ; r2 = (high1 * low2)low
ADD  r6 r2                 ; Sum += (high1 * low2)low
ADD  r5 r4                 ; carry_sum += carry

STR  r6 r1                 ; mem[output_addr + 2] = Sum

; -------- mem[output_addr + 1] --------
SUBI r1 1              

LDI  r6 0                  ; sum = 0
ADD  r6 r5                 ; sum += carry_sum 
LDI  r5 0                  ; carry_sum = 0

ADDI r0 0                   
LD   r2 r0                  ; r2 = high1 = mem[input_addr] 
ADDI r0 2
LD   r3 r0                  ; r3 = high2 = mem[input_addr+2]
SUBI r0 2
MUL  r2 r3                 ; r2 = (high1 * high2)low
ADD  r6 r2                 ; Sum += (high1 * high2)low
ADD  r5 r4                 ; carry_sum += carry

ADDI r0 1                   
LD   r2 r0                 ; r2 = low1 = mem[input_addr+1] 
ADDI r0 1
LD   r3 r0                 ; r3 = high2 = mem[input_addr+2]
SUBI r0 2

J    2
J    -32

MULC r2 r3                 ; r2 = (low1 * high2)high
ADD  r6 r2                 ; Sum += (low1 * high2)high
ADD  r5 r4                 ; carry_sum += carry

ADDI r0 0
LD   r2 r0                 ; r2 = high1 = mem[input_addr]
ADDI r0 3
LD   r3 r0                 ; r3 = low2 = mem[input_addr+3]
SUBI r0 3
MULC r2 r3                 ; r2 = (high1 * low2)high
ADD  r6 r2                 ; Sum += (high1 * low2)high
ADD  r5 r4                 ; carry_sum += carry

STR  r6 r1                 ; mem[output_addr + 1] = Sum

; -------- mem[output_addr + 1] --------
SUBI r1 1               

LDI  r6 0                  ; sum = 0
ADD  r6 r5                 ; sum += carry_sum 

ADDI r0 0                   
LD   r2 r0                  ; r2 = high1 = mem[input_addr] 
ADDI r0 2
LD   r3 r0                  ; r3 = high2 = mem[input_addr+2]
SUBI r0 2
MULC r2 r3                 ; r2 = (high1 * high2)high
ADD  r6 r2                 ; Sum += (high1 * high2)high

STR  r6 r1                 ; mem[output_addr] = Sum

; -------- sign correction --------
; r5 holds mem[output] as data temp; r1 is address for output+1 during SUBs,
; then SUBI r1 1 restores it to output AFTER both SUBs (borrow already consumed).
LD    r2 r0                     ; r2 = A_high
SIGN  r2                        ; borrow = A_high[7]
BBS   2                         ; if A neg → A_corr
J     16                        ; else → check_B

; A_corr (13 instrs): {mem[output], mem[output+1]} -= {B_high, B_low}
ADDI  r0 2                      ; r0 = B_high addr
LD    r2 r0                     ; r2 = B_high
ADDI  r0 1                      ; r0 = B_low addr

J     2
J     -32

LD    r3 r0                     ; r3 = B_low

SUBI  r0 3                      ; r0 = input_addr  (SUBI before SUB chain)
LD    r5 r1                     ; r5 = mem[output]        (r1 = output)
ADDI  r1 1                      ; r1 = output+1
LD    r6 r1                     ; r6 = mem[output+1]
SUB   r6 r3                     ; r6 -= B_low             (sets borrow)
STR   r6 r1                     ; mem[output+1] = r6      (borrow preserved)
SUB   r5 r2                     ; r5 -= B_high - borrow   (borrow consumed)
SUBI  r1 1                      ; r1 = output             (safe: borrow consumed)
STR   r5 r1                     ; mem[output] = r5

; check_B (6 instrs)
ADDI  r0 2                      ; r0 = B_high addr
LD    r3 r0                     ; r3 = B_high
SUBI  r0 2                      ; r0 = input_addr
SIGN  r3                        ; borrow = B_high[7]
BBS   2                         ; if B neg → B_corr
J     14                        ; else → DONE

; B_corr (13 instrs): {mem[output], mem[output+1]} -= {A_high, A_low}
ADDI  r0 1                      ; r0 = A_low addr
LD    r3 r0                     ; r3 = A_low
SUBI  r0 1                      ; r0 = input_addr  (SUBI before SUB chain)
LD    r2 r0                     ; r2 = A_high
ADDI  r0 0                      ; NOP (alignment)
LD    r5 r1                     ; r5 = mem[output]        (r1 = output)
ADDI  r1 1                      ; r1 = output+1
LD    r6 r1                     ; r6 = mem[output+1]
SUB   r6 r3                     ; r6 -= A_low             (sets borrow)
STR   r6 r1                     ; mem[output+1] = r6      (borrow preserved)
SUB   r5 r2                     ; r5 -= A_high - borrow   (borrow consumed)
SUBI  r1 1                      ; r1 = output             (safe: borrow consumed)
STR   r5 r1                     ; mem[output] = r5

ADDI  r0 2
ADDI  r0 2                      ; input_addr = input_addr + 4
J     -32
