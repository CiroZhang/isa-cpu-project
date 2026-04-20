LDI   r7 1                      ; r7 = 1
SHIFT r7 L2                     ; r7 = 4
SHIFT r7 L2                     ; r7 = 16
SHIFT r7 L2                     ; r7 = 64
LDI   r0 0                      ; i = 0
LDI   r1 2                      ; j = 2

LDI   r2 0                   
ADD   r2 r0                    
SUB   r2 r7                    
BBS   2                         ; while i < 64:
DONE
LDI   r2 0
LDI   r2 0
ADD   r2 r1                     
SUB   r2 r7                    


BBS   2                         ; while j < 64:
J     18

LDI   r4 0                      ; count = 0
LD    r2 r0                     ; r2 = mem[i]
LD    r3 r1                     ; r3 = mem[j]
XOR   r2 r3                     ; r2 = mem[i] ^ mem[j]
COU   r2                        ; r2 = popcount(r2)
ADD   r4 r2                     ; count += low-byte hamming
ADDI  r0 1
ADDI  r1 1
LD    r2 r0                     ; r2 = mem[i+1]
LD    r3 r1                     ; r3 = mem[j+1]
XOR   r2 r3                     ; r2 = mem[i+1] ^ mem[j+1]
COU   r2                        ; r2 = popcount(r2)
ADD   r4 r2                     ; count += high-byte hamming
SUBI  r0 1
SUBI  r1 1
LDI   r2 0

J     4                         ; Jump Trampoline
J     16                        ; j forward jump → i-increment
J     -24                       ; j return jump
J     -30                       ; i return jump

ADD   r2 r7                     ; r2 = 64           
LD    r3 r2                     ; r3 = current_min = mem[64]
SUB   r3 r4
BBS   2                         ; if count < current_min:
STR   r4 r2                     ;     mem[64] = count
ADDI  r2 1                      ; r2 = 65
LD    r3 r2                     ; r3 = current_max = mem[65]
SUB   r3 r4
BBS   2                         ; if count < current_max:
J     2
STR   r4 r2                     ;     mem[65] = count

ADDI  r1 2                      ; j = j + 2
J     -14

ADDI  r0 2                      ; i = i + 2
LDI   r1 0
ADD   r1 r0
ADDI  r1 2                      ; j = i + 2

J     -18