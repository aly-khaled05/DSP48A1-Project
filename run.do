vlib work
vlog dsp.v DSPtestbench.v
vsim -voptargs=+acc work.DSP_tb
add wave *
run -all
