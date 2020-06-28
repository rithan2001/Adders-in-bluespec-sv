
# standard Bluespec setup, defining environment variables
# BLUESPECDIR, BLUESPEC_HOME and BLUESPEC_LICENSE_FILE,
# and placing $BLUESPEC_HOME/bin in your path is expected to
# invoke 'bsc', the Bluespec compiler.
# ================================================================

#Targeting Design
# Directory containing the box
TOPFILE?=Tb_add.bsv
TOPMODULE?=mkTb_add
TOPDIR?=.

BSC_DIR := $(shell which bsc)
BSC_VDIR:=$(subst /bsc,/,${BSC_DIR})../lib/Verilog/

FILES:= .
VERILOGDIR := ./verilog
BSVOUTDIR := ./bin
BUILDDIR := bsv_build
BSC_COMP_FLAGS = -u -verilog -elab -vdir $(VERILOGDIR) -bdir $(BUILDDIR) -info-dir $(BUILDDIR) \
								 +RTS -K40000M -RTS -aggressive-conditions -no-warn-action-shadowing -check-assert  -keep-fires  -opt-undetermined-vals \
								 -remove-false-rules -remove-empty-rules -remove-starved-rules -remove-dollar \
								 -unspecified-to X -show-schedule -show-module-use


BSC_PATHS = -p $(FILES):%/Libraries

# ----------------------------------------------------------------
# Verilog compile/link/sim
# ----------------------------------------------------------------
# ----------------- Setting up flags for verilator ---------------------------------------------- #
VERILATESIM := -CFLAGS -O3
THREADS=1
SIM_MAIN=./testbench/sim_main.cpp
SIM_MAIN_H=./testbench/sim_main.h
VERILATOR_FLAGS += --stats -O3 $(VERILATESIM) -LDFLAGS "-static" --x-assign fast \
					--x-initial fast --noassert $(SIM_MAIN) --bbox-sys -Wno-STMTDLY \
					-Wno-UNOPTFLAT -Wno-WIDTH -Wno-lint -Wno-COMBDLY -Wno-INITIALDLY --trace\
					--autoflush --threads $(THREADS) -DBSV_RESET_FIFO_HEAD -DBSV_RESET_FIFO_ARRAY
# ---------------------------------------------------------------------------------------------- #

check-env:
ifeq (, $(shell which bsc))
	$(error "BSC not found in $(PATH). Exiting ")
endif


.PHONY: generate_verilog
generate_verilog: check-env
	@echo Compiling for Verilog ...
	@mkdir -p $(BUILDDIR) $(VERILOGDIR)
	bsc $(BSC_COMP_FLAGS) -D VERBOSITY=$(VERBOSITY) $(define_macros)  $(BSC_PATHS) -g $(TOPMODULE)  $(TOPDIR)/$(TOPFILE) || (echo "BSC COMPILE ERROR"; exit 1)
	@echo Compiling for Verilog finished

.PHONY: link_verilator
link_verilator: ## Generate simulation executable using Verilator
	@echo "Linking $(TOPMODULE) using verilator"
	@mkdir -p $(BSVOUTDIR) obj_dir
	@echo "#define TOPMODULE V$(TOPMODULE)" > $(SIM_MAIN_H)
	@echo '#include "V$(TOPMODULE).h"' >> $(SIM_MAIN_H)
	verilator $(VERILATOR_FLAGS) --cc $(VERILOGDIR)/$(TOPMODULE).v -y $(VERILOGDIR) \
		-y $(BSC_VDIR) --exe
	@ln -f -s $(SIM_MAIN) obj_dir/sim_main.cpp
	@ln -f -s $(SIM_MAIN_H) obj_dir/sim_main.h
	@make -j8 -C obj_dir -f V$(TOPMODULE).mk
	@cp obj_dir/V$(TOPMODULE) $(BSVOUTDIR)/out
	@echo Linking for Verilog sim finished

.PHONY: simulate
simulate:
	@echo Simulation...
	$(BSVOUTDIR)/out +fullverbose > log
	@echo Simulation finished

# ----------------------------------------------------------------

.PHONY: clean
clean:
	rm -rf  $(BSVOUTDIR) obj_dir  $(VERILOGDIR) bin *~
	rm -f  *$(TOPMODULE)*  *.vcd

