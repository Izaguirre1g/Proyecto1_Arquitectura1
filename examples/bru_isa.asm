# Éxito: x6=7, x7=0. La ruta fallo escribe x7=1.
sumai x4,x0,1 | nop | nop | nop
sumai x5,x0,2 | nop | nop | nop
nop
nop
nop | nop | igualsi x4,x5,fallo | nop
nop | nop | igualno x4,x5,menor | nop
nop | nop | sye x0,fallo | nop
menor: nop | nop | menora x4,x5,mayor | nop
nop | nop | sye x0,fallo | nop
mayor: nop | nop | mayoroigual x5,x4,bien | nop
fallo: sumai x7,x0,1 | nop | sye x0,fin | nop
bien: sumai x6,x0,7 | nop | sye x0,fin | nop
fin: nop | nop | sye x0,fin | nop
