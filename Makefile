SIM_DIR = sim
RTL_SRC = rtl/regfile.sv rtl/alu.sv rtl/forwarding_unit.sv rtl/hazard_detection_unit.sv rtl/rv32i_core.sv
TB_SRC  = tb/rv32i_core_tb.sv

all: sim_rv32i

sim_rv32i:
	mkdir -p $(SIM_DIR)
	iverilog -g2012 -o $(SIM_DIR)/rv32i_sim.vvp $(RTL_SRC) $(TB_SRC)
	vvp $(SIM_DIR)/rv32i_sim.vvp

wave_rv32i: sim_rv32i
	gtkwave $(SIM_DIR)/rv32i_trace.vcd &

clean:
	rm -rf $(SIM_DIR)
