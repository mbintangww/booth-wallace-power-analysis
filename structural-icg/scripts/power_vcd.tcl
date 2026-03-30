# ============================================================
# Power Analysis Script — OpenROAD Standalone
# Design: Structural Booth-Wallace Multiplier with ICG Clock Gating
#
# Usage:
#   openroad -no_init -exit scripts/power_vcd.tcl
#   Run from project root: structural-icg/
#
# Prerequisites:
#   1. Run LibreLane to generate netlist, ODB, and SPEF:
#        librelane config.yaml
#      LibreLane will define SYNTHESIS, enabling the ICG cell in DFF.v.
#      Then update RUN_DIR below with the generated run folder name.
#
#   2. Run gate-level simulation to generate VCD:
#        SKY=<path-to-sky130_fd_sc_hd>
#        mkdir -p sim_out
#        iverilog -o sim_out/gate_sim -DFUNCTIONAL \
#          $SKY/verilog/primitives.v \
#          $SKY/verilog/sky130_fd_sc_hd.v \
#          runs/$RUN_DIR/final/nl/Top.nl.v \
#          tb/tb_Top_power.v
#        vvp sim_out/gate_sim
#
# Note on DFF.v:
#   DFF.v uses `ifdef SYNTHESIS to select between:
#   - SYNTHESIS defined (LibreLane): sky130_fd_sc_hd__dlclkp_1 ICG cell
#   - SYNTHESIS not defined (iverilog RTL sim): behavioral fallback
# ============================================================

# --- UPDATE THESE TWO PATHS BEFORE RUNNING ---
set RUN_DIR "runs/RUN_YYYY-MM-DD_HH-MM-SS"
set SKY     "/path/to/sky130A/libs.ref/sky130_fd_sc_hd"
# ---------------------------------------------

set ::env(CLOCK_PORT)              clk
set ::env(CLOCK_PERIOD)            16
set ::env(IO_DELAY_CONSTRAINT)     20
set ::env(OUTPUT_CAP_LOAD)         33.442
set ::env(SYNTH_DRIVING_CELL)      sky130_fd_sc_hd__inv_2/Y
set ::env(TIME_DERATING_CONSTRAINT) 5

define_corners nom_tt_025C_1v80

read_liberty -corner nom_tt_025C_1v80 \
  $SKY/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

read_db $RUN_DIR/final/odb/Top.odb

read_sdc constraints/signoff.sdc

read_spef -corner nom_tt_025C_1v80 \
  $RUN_DIR/final/spef/nom/Top.nom.spef

read_power_activities \
  -scope tb_Top_power/uut \
  -vcd sim_out/gate_level.vcd

puts "\n=== Power Report — Structural ICG (VCD 70% zero, 16ns clock) ==="
report_power -corner nom_tt_025C_1v80

exit
