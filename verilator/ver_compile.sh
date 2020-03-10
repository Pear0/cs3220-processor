#!/bin/sh
set -e

verilator --cc -Wall --trace -Mdir obj_dir -public \
  -I../rtl/cs3220_core \
  -I../rtl/memory \
  -I../rtl/ \
  -I../rtl/perf \
  -I../rtl/compat \
  -I../rtl/wb_iodevices \
  -I../rtl/cache \
  ../rtl/cs3220_syn.sv

cd obj_dir

make -f Vcs3220_syn.mk


