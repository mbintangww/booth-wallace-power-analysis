#!/bin/bash
# =============================================================
# Sparsity Sweep — 30-Run Power Analysis
# Usage: ./run_sweep.sh
# Run from project root: booth-wallace-power-analysis/
#
# Runs gate-level simulation + OpenROAD power analysis for
# 10 zero-input sparsity levels (0%..90%) across all 3 designs.
#
# Prerequisites:
#   LibreLane must be run for each design first.
#   Output: sim_out/power_report_N.log and sim_out/gate_level_N.vcd
#   Then run: python parse_sweep.py  (via nix-shell or venv)
# =============================================================

set -e

# --- Auto-detect sky130_fd_sc_hd ---
_detect_sky() {
    if [ -n "$SKY" ] && [ -d "$SKY" ]; then
        echo "$SKY"; return
    fi
    if [ -n "$PDK_ROOT" ] && [ -d "$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd" ]; then
        echo "$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd"; return
    fi
    local ciel_match
    ciel_match=$(ls -d "$HOME/.ciel/ciel/sky130/versions/"*/sky130A/libs.ref/sky130_fd_sc_hd 2>/dev/null | sort | tail -1)
    if [ -n "$ciel_match" ]; then
        echo "$ciel_match"; return
    fi
    if [ -d "$HOME/pdk/sky130A/libs.ref/sky130_fd_sc_hd" ]; then
        echo "$HOME/pdk/sky130A/libs.ref/sky130_fd_sc_hd"; return
    fi
    return 1
}

# --- Auto-detect OpenROAD ---
_detect_openroad() {
    if command -v openroad &>/dev/null; then
        command -v openroad; return
    fi
    local nix_match
    nix_match=$(ls /nix/store/*/bin/openroad 2>/dev/null | head -1)
    if [ -n "$nix_match" ]; then
        echo "$nix_match"; return
    fi
    return 1
}

SKY=$(_detect_sky) || {
    echo "ERROR: sky130_fd_sc_hd not found automatically."
    echo "Please set: export SKY=/path/to/sky130A/libs.ref/sky130_fd_sc_hd"
    exit 1
}

OPENROAD=$(_detect_openroad) || {
    echo "ERROR: openroad not found in PATH or /nix/store."
    echo "Please add OpenROAD to PATH."
    exit 1
}

echo "Using sky130:   $SKY"
echo "Using openroad: $OPENROAD"

DESIGNS=("behavioral" "structural-baseline" "structural-icg")
SPARSITY=(0 10 20 30 40 50 60 70 80 90)

TOTAL=$(( ${#DESIGNS[@]} * ${#SPARSITY[@]} ))
COUNT=0

for DESIGN in "${DESIGNS[@]}"; do
    echo ""
    echo "======================================================"
    echo " Design: $DESIGN"
    echo "======================================================"

    mkdir -p $DESIGN/sim_out

    RUN_DIR_FULL=$(ls -d $DESIGN/runs/RUN_* 2>/dev/null | sort | tail -1)
    if [ -z "$RUN_DIR_FULL" ]; then
        echo "ERROR: No LibreLane run found in $DESIGN/runs/ — skipping."
        continue
    fi
    RUN_DIR="${RUN_DIR_FULL#$DESIGN/}"

    NETLIST="$RUN_DIR_FULL/final/nl/Top.nl.v"
    ODB="$RUN_DIR_FULL/final/odb/Top.odb"
    SPEF="$RUN_DIR_FULL/final/spef/nom/Top.nom.spef"

    for ZPCT in "${SPARSITY[@]}"; do
        COUNT=$(( COUNT + 1 ))
        echo ""
        echo "--- [$COUNT/$TOTAL] $DESIGN @ ${ZPCT}% zero ---"

        # Gate-level compile with ZERO_PCT
        iverilog -o $DESIGN/sim_out/gate_sim_${ZPCT} \
            -DFUNCTIONAL \
            -DZERO_PCT=${ZPCT} \
            $SKY/verilog/primitives.v \
            $SKY/verilog/sky130_fd_sc_hd.v \
            $NETLIST \
            $DESIGN/tb/tb_Top_power.v 2>&1 | grep -v "warning:" || true

        # Run simulation
        cd $DESIGN
        vvp sim_out/gate_sim_${ZPCT} 2>&1 | grep -v "dumpfile" | grep -v "^$" || true
        mv sim_out/gate_level.vcd sim_out/gate_level_${ZPCT}.vcd
        cd ..

        # OpenROAD power analysis
        cd $DESIGN
        $OPENROAD -no_init -exit - <<EOF 2>&1 | tee sim_out/power_report_${ZPCT}.log
set ::env(CLOCK_PORT)               clk
set ::env(CLOCK_PERIOD)             16
set ::env(IO_DELAY_CONSTRAINT)      20
set ::env(OUTPUT_CAP_LOAD)          33.442
set ::env(SYNTH_DRIVING_CELL)       sky130_fd_sc_hd__inv_2/Y
set ::env(TIME_DERATING_CONSTRAINT) 5
define_corners nom_tt_025C_1v80
read_liberty -corner nom_tt_025C_1v80 $SKY/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_db $RUN_DIR/final/odb/Top.odb
read_sdc constraints/signoff.sdc
read_spef -corner nom_tt_025C_1v80 $RUN_DIR/final/spef/nom/Top.nom.spef
read_power_activities -scope tb_Top_power/uut -vcd sim_out/gate_level_${ZPCT}.vcd
report_power -corner nom_tt_025C_1v80
exit
EOF
        cd ..

        echo "    -> power_report_${ZPCT}.log saved"
    done
done

echo ""
echo "======================================================"
echo " Sweep complete: $TOTAL runs done."
echo " Next step: python parse_sweep.py"
echo "======================================================"
