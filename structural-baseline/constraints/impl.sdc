set clock_port __VIRTUAL_CLK__
if { [info exists ::env(CLOCK_PORT)] } {
    if { [llength $::env(CLOCK_PORT)] > 0 } {
        set ::clock_port [lindex $::env(CLOCK_PORT) 0]
    }
}

set port_args [get_ports $clock_port]
create_clock -name $clock_port -period $::env(CLOCK_PERIOD) $port_args

# IO delays
set input_delay_value  [expr $::env(CLOCK_PERIOD) * $::env(IO_DELAY_CONSTRAINT) / 100]
set output_delay_value [expr $::env(CLOCK_PERIOD) * $::env(IO_DELAY_CONSTRAINT) / 100]

# Remove clk from input list
set clk_input [get_ports $clock_port]
set clk_indx [lsearch [all_inputs] $clk_input]
set all_inputs_wo_clk [lreplace [all_inputs] $clk_indx $clk_indx ""]

# DO NOT constrain reset
set rst_input [get_ports reset]
set rst_indx [lsearch $all_inputs_wo_clk $rst_input]
set all_inputs_wo_clk_rst [lreplace $all_inputs_wo_clk $rst_indx $rst_indx ""]

set clocks [get_clocks $clock_port]

set_input_delay  $input_delay_value  -clock $clocks $all_inputs_wo_clk_rst
set_output_delay $output_delay_value -clock $clocks [all_outputs]

set_clock_uncertainty 0.15 $clocks
