# Resultado esperado: x5=127, x6=-1; mem[256]=127, byte mem[260]=255.
sumai x4,x0,127 | nop | nop | nop
sumai x7,x0,-1 | nop | nop | nop
nop
nop | guardap x0,x4,256 | nop | nop
nop | guardab x0,x7,260 | nop | nop
nop | cargai x5,x0,256 | nop | nop
nop | cargabai x6,x0,260 | nop | nop
nop
nop
fin: nop | nop | sye x0,fin | nop
