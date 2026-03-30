#!/bin/bash
# =============================================================
# Gate-Level Simulation — All Three Designs
# Usage: ./run_gate_sim.sh
# Run from project root: booth-wallace-power-analysis/
#
# Prerequisites:
#   LibreLane must be run for each design first:
#     librelane behavioral/config.yaml
#     librelane structural-baseline/config.yaml
#     librelane structural-icg/config.yaml
#
# The script will automatically find the latest run folder
# inside each design's runs/ directory.
#
# Output: sim_out/gate_level.vcd and sim_out/gate_results.log
#
# sky130_fd_sc_hd is located automatically from (in order):
#   1. SKY env var (export SKY=/path/to/sky130_fd_sc_hd)
#   2. PDK_ROOT env var  ($PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd)
#   3. ~/.ciel installation
#   4. ~/pdk installation (OpenLane default)
# =============================================================

set -e

# --- Auto-detect sky130_fd_sc_hd ---
_detect_sky() {
    # 1. Explicit env var
    if [ -n "$SKY" ] && [ -d "$SKY" ]; then
        echo "$SKY"; return
    fi
    # 2. PDK_ROOT (OpenLane / custom)
    if [ -n "$PDK_ROOT" ] && [ -d "$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd" ]; then
        echo "$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd"; return
    fi
    # 3. Ciel (~/.ciel)
    local ciel_match
    ciel_match=$(ls -d "$HOME/.ciel/ciel/sky130/versions/"*/sky130A/libs.ref/sky130_fd_sc_hd 2>/dev/null | sort | tail -1)
    if [ -n "$ciel_match" ]; then
        echo "$ciel_match"; return
    fi
    # 4. OpenLane default ~/pdk
    if [ -d "$HOME/pdk/sky130A/libs.ref/sky130_fd_sc_hd" ]; then
        echo "$HOME/pdk/sky130A/libs.ref/sky130_fd_sc_hd"; return
    fi
    return 1
}

SKY=$(_detect_sky) || {
    echo "ERROR: sky130_fd_sc_hd not found automatically."
    echo "Please set one of the following before running:"
    echo "  export SKY=/path/to/sky130A/libs.ref/sky130_fd_sc_hd"
    echo "  export PDK_ROOT=/path/to/pdks"
    exit 1
}
echo "Using sky130: $SKY"
# -----------------------------------

DESIGNS=("behavioral" "structural-baseline" "structural-icg")

for DESIGN in "${DESIGNS[@]}"; do
    echo ""
    echo "======================================================"
    echo " Gate-Level Simulation: $DESIGN"
    echo "======================================================"

    mkdir -p $DESIGN/sim_out

    # Find latest LibreLane run
    RUN_DIR=$(ls -d $DESIGN/runs/RUN_* 2>/dev/null | sort | tail -1)
    if [ -z "$RUN_DIR" ]; then
        echo "ERROR: No LibreLane run found in $DESIGN/runs/"
        echo "Please run: librelane $DESIGN/config.yaml"
        continue
    fi
    echo "Using run: $RUN_DIR"

    NETLIST="$RUN_DIR/final/nl/Top.nl.v"
    if [ ! -f "$NETLIST" ]; then
        echo "ERROR: Netlist not found at $NETLIST"
        continue
    fi

    iverilog -o $DESIGN/sim_out/gate_sim \
        -DFUNCTIONAL \
        $SKY/verilog/primitives.v \
        $SKY/verilog/sky130_fd_sc_hd.v \
        $NETLIST \
        $DESIGN/tb/tb_Top_power.v 2>&1 | grep -v "warning:" || true

    cd $DESIGN
    vvp sim_out/gate_sim 2>&1 | grep -v "dumpfile" | tee sim_out/gate_results.log || true
    cd ..

    echo "VCD saved to $DESIGN/sim_out/gate_level.vcd"
    echo "Results saved to $DESIGN/sim_out/gate_results.log"
done

echo ""
echo "======================================================"
echo " All gate-level simulations complete."
echo " Next step: run ./run_power.sh"
echo "======================================================"
