LDI   r4 0                      ; r4 = 0
LDI   r7 1                      ; r7 = 1
SHIFT r7 L2                     ; r7 = 4
SHIFT r7 L2                     ; r7 = 16
SHIFT r7 L2                     ; r7 = 64

LDI  r0 0                       ; input_addr = 0
LDI  r1 0
ADD  r1 r7                      ; output_addr = 64

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
SUBI r0 2
MUL  r2 r3                 ; r2 = (low1 * high2)low
ADD  r6 r2                 ; Sum += (low1 * high2)low
ADD  r5 r4                 ; carry_sum += carry

ADDI r0 0                   
LD   r2 r0                 ; r2 = high1 = mem[input_addr] 
ADDI r0 3
LD   r3 r0                 ; r3 = low2 = mem[input_addr+3]
SUBI r0 2
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
MULC r2 r3                 ; r2 = (low1 * high2)high
ADD  r6 r2                 ; Sum += (low1 * high2)high
ADD  r5 r4                 ; carry_sum += carry

ADDI r0 0                   
LD   r2 r0                 ; r2 = high1 = mem[input_addr] 
ADDI r0 3
LD   r3 r0                 ; r3 = low2 = mem[input_addr+3]
SUBI r0 2
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


DONE