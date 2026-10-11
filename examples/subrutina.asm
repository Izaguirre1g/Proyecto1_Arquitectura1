# Subrutinas: "contar" se llama dos veces con sye y vuelve con syer x0,ra,0
# (equivale a ret) al bundle siguiente al de cada llamada.
# Éxito: x5=2 (llamadas), x6=1 y x7=1 (retornos), x8=0x30 (ra de la 2.a llamada).
nop | nop | sye ra,contar | nop
sumai x6,x0,1 | nop | nop | nop
nop | nop | sye ra,contar | nop
sumai x7,x0,1 | nop | nop | nop
mov x8,ra | nop | nop | nop
fin: nop | nop | sye x0,fin | nop
contar: sumai x5,x5,1 | nop | nop | nop
nop
nop | nop | syer x0,ra,0 | nop
