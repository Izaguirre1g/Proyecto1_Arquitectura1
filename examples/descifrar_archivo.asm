# Descifra con Feistel4 un archivo cargado en la memoria de datos.
#
# Memoria (la prepara tests/rtl/tb_archivo.sv; ver "make archivo"):
#   0x100  contraseña inicial (setpwd)       0x110  llave 0: K0, K1, K2, K3
#   0x104  contraseña candidata (vcr)        0x200  archivo, bloques de 8 bytes
#   0x108  dirección donde termina el archivo (0x200 + tamaño redondeado a 8)
#
# Cada bloque (L, R) se descifra con 4 rondas fsli (RK = 3, 2, 1, 0) y se guarda en
# el mismo lugar. Los NOP respetan la regla N+3 de registros y de ESTADO.

# ---- Preparación: punteros, contraseña, autenticación y llave ----
sumai x16,x0,512 | cargai x6,x0,256  | nop | nop          # p = 0x200
nop              | cargai x17,x0,264 | nop | nop          # fin
nop              | cargai x8,x0,272  | nop | nop          # K0
nop              | cargai x10,x0,276 | nop | setpwd x6    # K1; contraseña de la bóveda
nop              | cargai x12,x0,280 | nop | vcr 0x104    # K2; AUTH = 1 si coincide
nop              | cargai x14,x0,284 | nop | nop          # K3
nop
nop | nop | nop | ell 0,0,x8,x10                           # bóveda[0][0..1] = K0, K1
nop | nop | nop | ell 0,2,x12,x14                          # bóveda[0][2..3] = K2, K3

# ---- Un bloque por iteración ----
bloque: nop      | cargai x4,x16,0   | nop | nop          # L = M[p]
nop              | cargai x5,x16,4   | nop | nop          # R = M[p + 4]
sumai x16,x16,8  | nop               | nop | nop          # p = p + 8
nop
nop | nop | nop | fsli x4,x4,0,3                           # ronda 1 (K3)
nop
nop
nop | nop | nop | fsli x4,x4,0,2                           # ronda 2 (K2)
nop
nop
nop | nop | nop | fsli x4,x4,0,1                           # ronda 3 (K1)
nop
nop
nop | nop | nop | fsli x4,x4,0,0                           # ronda 4 (K0)
nop
nop
nop | guardap x16,x4,-8 | nop | nop                        # M[p - 8] = L
nop | guardap x16,x5,-4 | menora x16,x17,bloque | nop      # M[p - 4] = R; otro bloque si p < fin
fin: nop | nop | sye x0,fin | nop
