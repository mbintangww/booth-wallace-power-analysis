#!/bin/bash
# =============================================================
# Power Analysis — All Three Designs
# Usage: ./run_power.sh
# Run from project root: booth-wallace-power-analysis/
#
# Prerequisites:
#   1. LibreLane run completed for each design
#   2. Gate-level simulation completed (run ./run_gate_sim.sh first)
#      → sim_out/gate_level.vcd must exist in each design folder
#
# Output: sim_out/power_report.log for each design
#
# sky130_fd_sc_hd and openroad are located automatically from:
#   SKY:      export SKY=/path/to/sky130_fd_sc_hd
#             or export PDK_ROOT=/path/to/pdks
#             or ~/.ciel / ~/pdk (auto-detected)
#   OpenROAD: openroad in PATH, or /nix/store/*/bin/openroad (auto-detected)
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
    echo "Please set one of the following before running:"
    echo "  export SKY=/path/to/sky130A/libs.ref/sky130_fd_sc_hd"
    echo "  export PDK_ROOT=/path/to/pdks"
    exit 1
}

OPENROAD=$(_detect_openroad) || {
    echo "ERROR: openroad not found in PATH or /nix/store."
    echo "Please install OpenROAD and add it to PATH, or:"
    echo "  export PATH=/path/to/openroad/bin:\$PATH"
    exit 1
}

echo "Using sky130:  $SKY"
echo "Using openroad: $OPENROAD"
# -----------------------------------

DESIGNS=("behavioral" "structural-baseline" "structural-icg")

for DESIGN in "${DESIGNS[@]}"; do
    echo ""
    echo "======================================================"
    echo " Power Analysis: $DESIGN"
    echo "======================================================"

    # Find latest LibreLane run (full path from repo root)
    RUN_DIR_FULL=$(ls -d $DESIGN/runs/RUN_* 2>/dev/null | sort | tail -1)
    if [ -z "$RUN_DIR_FULL" ]; then
        echo "ERROR: No LibreLane run found in $DESIGN/runs/"
        continue
    fi
    # Relative path from inside the design folder (strip "DESIGN/" prefix)
    RUN_DIR="${RUN_DIR_FULL#$DESIGN/}"

    VCD="$DESIGN/sim_out/gate_level.vcd"
    if [ ! -f "$VCD" ]; then
        echo "ERROR: VCD not found at $VCD"
        echo "Please run ./run_gate_sim.sh first."
        continue
    fi

    echo "Using run: $RUN_DIR_FULL"

    cd $DESIGN
    $OPENROAD -no_init -exit - <<EOF 2>&1 | tee sim_out/power_report.log
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
read_power_activities -scope tb_Top_power/uut -vcd sim_out/gate_level.vcd
report_power -corner nom_tt_025C_1v80
exit
EOF
    cd ..

    echo "Power report saved to $DESIGN/sim_out/power_report.log"
done

echo ""
echo "======================================================"
echo " All power analyses complete."
echo "======================================================"
