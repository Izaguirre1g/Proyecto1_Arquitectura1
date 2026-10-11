# ==============================================================================
#  Makefile de simulación - Procesador VLIW (CE4301, Proyecto Grupal I)
#
#  Uso:
#    make sim              compila y ejecuta todos los testbenches de tb/
#    make tb_alu           compila y ejecuta sólo tb/tb_alu.sv
#    make waves TB=tb_alu  abre en GTKWave el .vcd de ese testbench
#    make list             lista los testbenches disponibles
#    make archivo          cifra y descifra un archivo en el procesador
#                          (ARCHIVO=<ruta>, por defecto examples/archivos/mensaje.txt)
#    make clean            borra build/
#    make help             muestra esta ayuda
#
#  Variables útiles:
#    PLUSARGS="+verbose +seed=7"   argumentos para la simulación
#
#  Cada testbench se compila con todos los módulos de rtl/ y se ejecuta dentro
#  de build/<tb>/, donde quedan el ejecutable (sim.vvp), el log (sim.log) y el
#  archivo de ondas (.vcd). Ver docs/simulation.md.
# ==============================================================================

SHELL := /bin/bash

IVERILOG ?= iverilog
VVP      ?= vvp
GTKWAVE  ?= gtkwave

RTL_DIR   := rtl
TB_DIR    := tb
BUILD_DIR := build

RTL_SRCS := $(sort $(wildcard $(RTL_DIR)/*.sv))
TB_SRCS  := $(sort $(wildcard $(TB_DIR)/tb_*.sv))
TB_HDRS  := $(wildcard $(TB_DIR)/*.svh)
TBS      := $(patsubst $(TB_DIR)/%.sv,%,$(TB_SRCS))

# -g2012          SystemVerilog
# -I              rutas para los `include (isa_defs.sv, tb_utils.svh)
# -Wno-timescale  sólo algunos archivos declaran `timescale e Icarus avisaría
#                 en cada módulo que lo hereda
IVFLAGS  ?= -g2012 -Wall -Wno-timescale -I $(RTL_DIR) -I $(TB_DIR)

# -n: $stop se comporta como $finish, la simulación nunca queda esperando
VVPFLAGS ?= -n
PLUSARGS ?=

TB ?=

# $(call compile,<testbench>)
compile = $(IVERILOG) $(IVFLAGS) -s $(1) -o $(BUILD_DIR)/$(1)/sim.vvp $(RTL_SRCS) $(TB_DIR)/$(1).sv


.PHONY: all sim list clean help waves check-tools $(TBS)

all: sim


help:
	@sed -n '2,19p' Makefile | sed 's/^# \{0,1\}//'


check-tools:
	@command -v $(IVERILOG) > /dev/null || { \
	    echo "No se encontró $(IVERILOG). Instale Icarus Verilog: sudo apt install iverilog"; exit 1; }


list:
	@printf '%s\n' $(TBS)


# ------------------------------------------------------------------------------
#  Un target por testbench: make tb_alu
# ------------------------------------------------------------------------------

$(BUILD_DIR)/%/sim.vvp: $(TB_DIR)/%.sv $(RTL_SRCS) $(TB_HDRS) | check-tools
	@mkdir -p $(@D)
	$(call compile,$*)

$(TBS): %: $(BUILD_DIR)/%/sim.vvp
	@cd $(BUILD_DIR)/$* && set -o pipefail && $(VVP) $(VVPFLAGS) sim.vvp $(PLUSARGS) 2>&1 | tee sim.log


# ------------------------------------------------------------------------------
#  make sim: compila y ejecuta todos los testbenches y muestra un resumen.
#
#  Estado de cada testbench:
#    PASS          imprimió [PASS] y terminó con código 0
#    FAIL          imprimió [FAIL] o terminó con código distinto de 0
#    SIN-CHEQUEO   corrió sin errores pero no se autoverifica (no usa
#                  tb_utils.svh), hay que revisar su salida a mano
#    NO-COMPILA    error de compilación (ver build/<tb>/compile.log)
#
#  Termina con error si algún testbench quedó en FAIL o NO-COMPILA.
# ------------------------------------------------------------------------------

sim: check-tools
	@echo "Simulando $(words $(TBS)) testbenches con $$($(IVERILOG) -V 2>&1 | head -1)"
	@pass=0; fail=0; nochk=0; bad=0; \
	for tb in $(TBS); do \
	    mkdir -p $(BUILD_DIR)/$$tb; \
	    if $(call compile,$$tb) > $(BUILD_DIR)/$$tb/compile.log 2>&1; then \
	        ( cd $(BUILD_DIR)/$$tb && $(VVP) $(VVPFLAGS) sim.vvp $(PLUSARGS) > sim.log 2>&1 ); rc=$$?; \
	        if [ $$rc -ne 0 ] || grep -q '\[FAIL\]' $(BUILD_DIR)/$$tb/sim.log; then \
	            st=FAIL; fail=$$((fail+1)); \
	        elif grep -q '\[PASS\]' $(BUILD_DIR)/$$tb/sim.log; then \
	            st=PASS; pass=$$((pass+1)); \
	        else \
	            st=SIN-CHEQUEO; nochk=$$((nochk+1)); \
	        fi; \
	    else \
	        st=NO-COMPILA; bad=$$((bad+1)); \
	    fi; \
	    printf '  %-12s %s\n' "$$st" "$$tb"; \
	done; \
	echo "Resumen: $$pass PASS, $$fail FAIL, $$bad NO-COMPILA, $$nochk SIN-CHEQUEO"; \
	echo "Logs y ondas en $(BUILD_DIR)/<testbench>/"; \
	[ $$fail -eq 0 ] && [ $$bad -eq 0 ]


# ------------------------------------------------------------------------------
#  make waves TB=tb_alu
# ------------------------------------------------------------------------------

waves:
	@[ -n "$(TB)" ] || { echo "Uso: make waves TB=<testbench>   (ver make list)"; exit 1; }
	@vcd=$$(ls $(BUILD_DIR)/$(TB)/*.vcd 2>/dev/null | head -1); \
	[ -n "$$vcd" ] || { echo "No hay .vcd para $(TB). Ejecute primero: make $(TB)"; exit 1; }; \
	echo "Abriendo $$vcd"; \
	$(GTKWAVE) $$vcd > /dev/null 2>&1 &


clean:
	rm -rf $(BUILD_DIR)


# Pruebas del ensamblador: no requieren simulador.
.PHONY: test-assembler test-programs
test-assembler:
	python3 -m unittest discover -s tests -p 'test_assembler.py' -v
	python3 -m unittest discover -s tests -p 'test_isa.py' -v
	python3 -m unittest discover -s tests -p 'test_bundler.py' -v

# Ejecuta contra el RTL real; falla si el resultado es incorrecto.
test-programs: check-tools
	@command -v $(VVP) > /dev/null || { echo "No se encontró $(VVP)"; exit 1; }
	IVERILOG=$(IVERILOG) VVP=$(VVP) python3 -m unittest discover -s tests -p 'test_cpu_program.py' -v


# ------------------------------------------------------------------------------
#  make archivo ARCHIVO=<ruta>
#
#  Cifra y descifra un archivo de cualquier formato en el procesador:
#    1. ensambla examples/cifrar_archivo.asm y examples/descifrar_archivo.asm;
#    2. carga el archivo en la memoria de datos desde 0x200 (tools/load_file.py);
#    3. tests/rtl/tb_archivo.sv ejecuta los dos programas y guarda la memoria en
#       cifrado.mem y descifrado.mem ($writememh);
#    4. tools/extract_data.py saca cifrado.bin y descifrado.bin, y descifrado.bin
#       se compara con el original.
#  Todo queda en build/archivo/. Tamaño máximo: 65024 bytes (64 KB - 0x200).
# ------------------------------------------------------------------------------

ARCHIVO     ?= examples/archivos/mensaje.txt
ARCHIVO_DIR := $(BUILD_DIR)/archivo

.PHONY: archivo
archivo: check-tools
	@test -f "$(ARCHIVO)" || { echo "No existe el archivo $(ARCHIVO)"; exit 1; }
	@mkdir -p $(ARCHIVO_DIR)
	python3 tools/assembler.py --input examples/cifrar_archivo.asm --output $(ARCHIVO_DIR)/cifrar.mem
	python3 tools/assembler.py --input examples/descifrar_archivo.asm --output $(ARCHIVO_DIR)/descifrar.mem
	python3 tools/load_file.py "$(ARCHIVO)" --base 0x200 --output $(ARCHIVO_DIR)/datos.mem
	$(IVERILOG) $(IVFLAGS) -s tb_archivo -o $(ARCHIVO_DIR)/sim.vvp $(RTL_SRCS) tests/rtl/tb_archivo.sv
	@set -o pipefail; n=$$(wc -c < "$(ARCHIVO)"); \
	( cd $(ARCHIVO_DIR) && $(VVP) $(VVPFLAGS) sim.vvp +CIFRAR=cifrar.mem +DESCIFRAR=descifrar.mem \
	    +DATOS=datos.mem +BYTES=$$n $(PLUSARGS) 2>&1 | tee sim.log ) && \
	python3 tools/extract_data.py $(ARCHIVO_DIR)/cifrado.mem --base 0x200 --size $$(( (n + 7) / 8 * 8 )) \
	    --format bin --output $(ARCHIVO_DIR)/cifrado.bin && \
	python3 tools/extract_data.py $(ARCHIVO_DIR)/descifrado.mem --base 0x200 --size $$n \
	    --format bin --output $(ARCHIVO_DIR)/descifrado.bin && \
	cmp "$(ARCHIVO)" $(ARCHIVO_DIR)/descifrado.bin && \
	echo "[PASS] $(ARCHIVO): descifrado.bin es idéntico al original ($$n bytes)"
