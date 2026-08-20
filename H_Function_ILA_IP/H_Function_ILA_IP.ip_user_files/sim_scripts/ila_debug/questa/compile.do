vlib questa_lib/work
vlib questa_lib/msim

vlib questa_lib/msim/xil_defaultlib

vmap xil_defaultlib questa_lib/msim/xil_defaultlib

vlog -work xil_defaultlib  -incr -mfcu  "+incdir+../../../../H_Function_ILA_IP.gen/sources_1/ip/ila_debug/hdl/verilog" \
"../../../../H_Function_ILA_IP.gen/sources_1/ip/ila_debug/sim/ila_debug.v" \


vlog -work xil_defaultlib \
"glbl.v"

