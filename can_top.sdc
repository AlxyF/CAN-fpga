create_clock -period 20.000 -name osc_clk osc_clk
derrive_pll_clocks
derrive_clock_uncertainty
set_false_path -from {get_ports button[0]}
set_false_path -to {get_ports led*}