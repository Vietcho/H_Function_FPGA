vlib work
vlib riviera

vlib riviera/xil_defaultlib

vmap xil_defaultlib riviera/xil_defaultlib

vlog -work xil_defaultlib  -v2k5 "+incdir+../../../../H_Function_ILA_IP.gen/sources_1/ip/ila_debug/hdl/verilog" \
"../../../../H_Function_ILA_IP.gen/sources_1/ip/ila_debug/sim/ila_debug.v" \


vlog -work xil_defaultlib \
"glbl.v"

