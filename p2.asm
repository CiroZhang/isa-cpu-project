LDI   r7 1                      ; r7 = 1
SHIFT r7 L2                     ; r7 = 4
SHIFT r7 L2                     ; r7 = 16
SHIFT r7 L2                     ; r7 = 64

LDI   r0 0                      ; i = 0
LDI   r1 2                      ; j = 2

LDI   r2 0
ADD   r2 r0
SUB   r2 r7
BBS   2                         ; while i < 64
DONE

LDI   r2 0
LDI   r2 0
ADD   r2 r1
SUB   r2 r7
BBS   2                         ; while j < 64
J     18                        ; go to i-update block

; -------- diff = | val[i] - val[j] | --------
LD    r2 r0                     ; r2 = mem[i]   = highA
LD    r3 r1                     ; r3 = mem[j]   = highB
ADDI  r0 1
ADDI  r1 1
LD    r4 r0                     ; r4 = mem[i+1] = lowA
LD    r5 r1                     ; r5 = mem[j+1] = lowB
SUBI  r0 1
SUBI  r1 1


SIGN r2        
BBS  6
SIGN r3        
BBS  16                      

SUB   r4 r5                     ; r4 = lowA - lowB
SUB   r2 r3                     ; r2 = highA - highB - borrow
J    20   

SIGN r3

J     4                         ; Jump Trampoline 1
J     26                        ; j forward jump → i-increment
J     -24                       ; j return jump
J     -30                       ; i return jump

BBS  -8                       ; if sign(r3) != sign(r2): 


; -------- diff = | val[i] | + | val[j] | --------
NOT   r4                        ; if sign(r2) -1: flip sign
NOT   r2
ADDI  r4 1                     
LDI   r6 0
ADD   r2 r6 
J 6
                    
NOT   r5                          ; if sign(r3) -1: flip sign
NOT   r3
ADDI  r5 1                     
LDI   r6 0
ADD   r3 r6                           

ADD  r4 r5
ADD  r2 r3                     ; diff = | val[i] | + | val[j] |       

; -------- if negative, negate 16-bit diff --------
BBS   2
J     4
NOT   r4
NOT   r2
ADDI  r4 1                      ; low += 1

LDI   r6 0
LDI   r6 0
ADD   r2 r6                     ; high += carry

J     4                         ; Jump Trampoline 2
J     30                        ; j forward jump → i-increment
J     -26                       ; j return jump
J     -26                       ; i return jump

; -------- if diff < current_min --------
LDI   r3 2
LDI   r3 2
ADD   r3 r7                     ; r3 = 66
LD    r5 r3                     ; r5 = current_min_high
ADDI  r3 1                      ; r3 = 67
LD    r6 r3                     ; r6 = current_min_low

SUB   r6 r4                     ; current_min_low - diff_low
SUB   r5 r2                     ; current_min_high - diff_high - borrow
BBS   6                         ; if diff >= min (borrow=0), skip update

ADDI  r3 0                      ; NOP
STR   r4 r3                     ; mem[67] = diff_low
SUBI  r3 1
STR   r2 r3                     ; mem[66] = diff_high
ADDI  r3 1

; -------- if diff > current_max --------
ADDI  r3 1                      ; r3 = 68
LD    r5 r3                     ; r5 = current_max_high
ADDI  r3 1                      ; r3 = 69
LD    r6 r3                     ; r6 = current_max_low

SUB   r6 r4                     ; current_max_low - diff_low
SUB   r5 r2                     ; current_max_high - diff_high - borrow
BBS   2

J     4
STR   r4 r3                     ; mem[69] = diff_low
SUBI  r3 1
STR   r2 r3                     ; mem[68] = diff_high

ADDI  r1 2                      ; j = j + 2
J     -28                       ; → addr 35 → j-check

ADDI  r0 2                      ; i = i + 2
LDI   r1 0
ADD   r1 r0                     ; r1 = r0
ADDI  r1 2                      ; j = i + 2
J     -32                       ; → addr 36 → i-check