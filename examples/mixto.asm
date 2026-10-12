# Preparación de contraseña/llave de prueba. Requiere INIT=1 al arrancar.
# La cripto FU todavía no está conectada en la rama base.
sumai x4,x0,7 | nop | nop | nop
sumai x6,x0,42 | nop | nop | nop
nop
nop
nop | guardap x0,x4,256 | nop | setpwd x4
nop
nop
nop | nop | nop | vcr 256
nop
nop
nop | nop | nop | ell 0,0,x4,x6
nop
nop
nop | nop | nop | ell 0,2,x4,x6
nop
nop
# Cuatro unidades en un bundle. El branch no se toma.
sumai x12,x0,1 | guardap x0,x6,260 | igualno x0,x0,fin | fsl x8,x4,0,0
nop
nop
nop | nop | nop | fsli x10,x8,0,0
nop
nop
nop | nop | nop | camcon 256,1
fin: nop | nop | sye x0,fin | nop
# Tras fsl/fsli: x10=7, x11=0; x12=1 y mem[260]=42.
