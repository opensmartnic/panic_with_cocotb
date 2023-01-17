# This file is public domain, it can be freely copied without restrictions.
# SPDX-License-Identifier: CC0-1.0

# Makefile

# defaults
SIM ?= modelsim
TOPLEVEL_LANG ?= verilog

PRJ_ROOT = /E/xx/projs/panic_osdi20_artifact
VERILOG_SOURCES += $(PRJ_ROOT)/src/panic_memory_alloc.v
VERILOG_SOURCES += $(PRJ_ROOT)/src/rand_mem_alloc.v
VERILOG_SOURCES += $(PRJ_ROOT)/lib/axis/rtl/*.v
VERILOG_SOURCES += $(PRJ_ROOT)/lib/axi/rtl/*.v

# use VHDL_SOURCES for VHDL files

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = panic_memory_alloc

# MODULE is the basename of the Python test file
MODULE = test_my_design

# GUI=1
# SIM_ARGS = -L unisims_ver -L xpm work.glbl

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim
