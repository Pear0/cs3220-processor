#!/bin/sh
set -e

verilator --cc -Wall --trace -Mdir obj_dir -public -I../rtl/cs3220_core ../rtl/cs3220_core/core.sv

cd obj_dir

make -f Vcore.mk


