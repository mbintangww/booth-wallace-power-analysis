#!/bin/bash
# =============================================================
# RTL Simulation — All Three Designs
# Usage: ./run_rtl_sim.sh
# Run from project root: booth-wallace-power-analysis/
#
# This script runs RTL-level functional simulation for all three
# designs using Icarus Verilog. No LibreLane run required.
# Results are saved to each design's sim_out/ folder.
# =============================================================

set -e

DESIGNS=("behavioral" "structural-baseline" "structural-icg")

for DESIGN in "${DESIGNS[@]}"; do
    echo ""
    echo "======================================================"
    echo " RTL Simulation: $DESIGN"
    echo "======================================================"

    mkdir -p $DESIGN/sim_out

    # Functional testbench
    echo "--- Functional Test (tb_Top.v) ---"
    iverilog -o $DESIGN/sim_out/tb_rtl \
        $DESIGN/RTL/*.v \
        $DESIGN/tb/tb_Top.v 2>&1 | grep -v "warning:" || true
    cd $DESIGN
    vvp sim_out/tb_rtl 2>&1 | tee sim_out/rtl_results.log
    cd ..

    # Power testbench (RTL level — functional verification only)
    echo "--- Power Testbench (tb_Top_power.v) ---"
    iverilog -o $DESIGN/sim_out/tb_power \
        $DESIGN/RTL/*.v \
        $DESIGN/tb/tb_Top_power.v 2>&1 | grep -v "warning:" || true
    cd $DESIGN
    vvp sim_out/tb_power 2>&1 | grep -v "dumpfile" | tee sim_out/power_tb_results.log || true
    cd ..

    echo "Results saved to $DESIGN/sim_out/rtl_results.log"
    echo "Results saved to $DESIGN/sim_out/power_tb_results.log"
done

echo ""
echo "======================================================"
echo " All RTL simulations complete."
echo "======================================================"
