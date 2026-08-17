# Fresh work library
if {[file exists work]} {
    vdel -all -lib work
}
vlib work
vmap work work

# Compile in dependency order. -sv enables SystemVerilog parsing;
# +acc keeps full visibility for waveform debug in the GUI.
vlog -sv +acc speck_datapath.sv
vlog -sv +acc speck_controller.sv
vlog -sv +acc speck32_64_top.sv
vlog -sv +acc tb_speck32_64.sv

# Elaborate and load the testbench (top-level of the compiled design)
vsim -voptargs=+acc work.tb_speck32_64

# Waveform: DUT ports + internal datapath/controller state, useful for
# stepping through a single round in the report screenshots.
add wave -divider "Testbench / Handshake"
add wave -radix hex   sim:/tb_speck32_64/clk
add wave -radix hex   sim:/tb_speck32_64/rst_n
add wave -radix hex   sim:/tb_speck32_64/start
add wave -radix hex   sim:/tb_speck32_64/key_in
add wave -radix hex   sim:/tb_speck32_64/plaintext
add wave -radix hex   sim:/tb_speck32_64/ciphertext
add wave -radix hex   sim:/tb_speck32_64/valid_out

add wave -divider "Controller FSM"
add wave            sim:/tb_speck32_64/dut/u_controller/state
add wave            sim:/tb_speck32_64/dut/u_controller/next_state
add wave -radix hex sim:/tb_speck32_64/dut/u_controller/load_en
add wave -radix hex sim:/tb_speck32_64/dut/u_controller/round_en

add wave -divider "Datapath Registers"
add wave -radix hex sim:/tb_speck32_64/dut/u_datapath/x_reg
add wave -radix hex sim:/tb_speck32_64/dut/u_datapath/y_reg
add wave -radix hex sim:/tb_speck32_64/dut/u_datapath/rk_reg
add wave -radix hex sim:/tb_speck32_64/dut/u_datapath/l0_reg
add wave -radix hex sim:/tb_speck32_64/dut/u_datapath/l1_reg
add wave -radix hex sim:/tb_speck32_64/dut/u_datapath/l2_reg
add wave -radix unsigned sim:/tb_speck32_64/dut/u_datapath/round_cnt
add wave -radix hex sim:/tb_speck32_64/dut/u_datapath/last_round

# Run to completion ($finish in the testbench ends the run automatically)
run -all

# Zoom the waveform to fit everything that happened, for a clean screenshot
wave zoom full
