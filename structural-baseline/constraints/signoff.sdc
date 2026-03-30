# ==========================================
# Signoff SDC for Top (Booth–Wallace Multiplier)
# ==========================================

set clock_port __VIRTUAL_CLK__
if { [info exists ::env(CLOCK_PORT)] } {
    set port_count [llength $::env(CLOCK_PORT)]

    if { $port_count > 0 } {
        set ::clock_port [lindex $::env(CLOCK_PORT) 0]
    } else {
        puts stderr "\[WARNING] No CLOCK_PORT found. Using virtual clock."
    }
}

# Create primary clock
set port_args [get_ports $clock_port]
puts "\[INFO] Using clock $clock_port for signoff…"
create_clock -name $clock_port -period $::env(CLOCK_PERIOD) $port_args

# >>> ADD THIS LINE <<<
set clocks [get_clocks $clock_port]
set_propagated_clock $clocks

# ------------------------------------------
# I/O Delays
# ------------------------------------------
set input_delay_value  [expr $::env(CLOCK_PERIOD) * $::env(IO_DELAY_CONSTRAINT) / 100]
set output_delay_value [expr $::env(CLOCK_PERIOD) * $::env(IO_DELAY_CONSTRAINT) / 100]

# Remove clock from input list
set clk_input [get_ports $clock_port]
set clk_indx [lsearch [all_inputs] $clk_input]
set all_inputs_wo_clk [lreplace [all_inputs] $clk_indx $clk_indx ""]

# Remove async reset from timing constraints
set rst_input [get_ports reset]
set rst_indx [lsearch $all_inputs_wo_clk $rst_input]
set all_inputs_wo_clk_rst [lreplace $all_inputs_wo_clk $rst_indx $rst_indx ""]

set clocks [get_clocks $clock_port]

set_input_delay  $input_delay_value  -clock $clocks $all_inputs_wo_clk_rst
set_output_delay $output_delay_value -clock $clocks [all_outputs]

# ------------------------------------------
# Driving Cell Assumptions
# ------------------------------------------
if { ![info exists ::env(SYNTH_CLK_DRIVING_CELL)] } {
    set ::env(SYNTH_CLK_DRIVING_CELL) $::env(SYNTH_DRIVING_CELL)
}

set_driving_cell \
    -lib_cell [lindex [split $::env(SYNTH_DRIVING_CELL) "/"] 0] \
    -pin      [lindex [split $::env(SYNTH_DRIVING_CELL) "/"] 1] \
    $all_inputs_wo_clk_rst

set_driving_cell \
    -lib_cell [lindex [split $::env(SYNTH_CLK_DRIVING_CELL) "/"] 0] \
    -pin      [lindex [split $::env(SYNTH_CLK_DRIVING_CELL) "/"] 1] \
    $clk_input

# ------------------------------------------
# Output Load
# ------------------------------------------
set cap_load [expr $::env(OUTPUT_CAP_LOAD) / 1000.0]
puts "\[INFO] Setting output load to: $cap_load"
set_load $cap_load [all_outputs]

# ------------------------------------------
# Clock Uncertainty (relaxed for signoff)
# ------------------------------------------
puts "\[INFO] Setting clock uncertainty to 0.1"
set_clock_uncertainty 0.1 $clocks

# ------------------------------------------
# Timing Derates
# ------------------------------------------
puts "\[INFO] Applying timing derates: $::env(TIME_DERATING_CONSTRAINT)%"
set_timing_derate -early [expr 1 - ($::env(TIME_DERATING_CONSTRAINT) / 100.0)]
set_timing_derate -late  [expr 1 + ($::env(TIME_DERATING_CONSTRAINT) / 100.0)]
