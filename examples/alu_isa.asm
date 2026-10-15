# Las 18 instrucciones ALU, mov, not, nop y descarte de escrituras a x0.
# Los resultados se comparan contra alu_isa.expected.json.
# Orden: slot 0 ALU | slot 1 LSU | slot 2 BRU | slot 3 CRIPTO.

sumai x1, x0, 12   | nop | nop | nop
sumai x2, x0, -8   | nop | nop | nop
sumai x3, x0, 2    | nop | nop | nop
sumai x4, x0, 5    | nop | nop | nop
suma x5, x1, x2    | nop | nop | nop
resta x6, x1, x2   | nop | nop | nop
cizq x7, x4, x3    | nop | nop | nop
cder x8, x1, x3    | nop | nop | nop
cader x9, x2, x3   | nop | nop | nop
xor x10, x1, x4    | nop | nop | nop
and x11, x1, x4    | nop | nop | nop
or x12, x1, x4     | nop | nop | nop
mrq x13, x2, x1    | nop | nop | nop
myq x14, x1, x2    | nop | nop | nop
restai x15, x1, 3  | nop | nop | nop
cizqi x16, x4, 3   | nop | nop | nop
cderi x17, x1, 2   | nop | nop | nop
caderi x18, x2, 2  | nop | nop | nop
xori x19, x1, -1   | nop | nop | nop
andi x20, x1, 7    | nop | nop | nop
ori x21, x1, 3     | nop | nop | nop
mov x22, x1       | nop | nop | nop
not x23, x4       | nop | nop | nop
sumai x0, x0, 99   | nop | nop | nop
