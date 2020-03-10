create_clock -name i_clk -period 20 [get_ports {i_sys_clk}]

derive_pll_clocks -create_base_clocks

set_false_path -from [get_ports {i_resetn}]

set_false_path -to [get_ports {ssegs[0][0] ssegs[0][1] ssegs[0][2] ssegs[0][3] ssegs[0][4] ssegs[0][5] ssegs[0][6] ssegs[1][0] ssegs[1][1] ssegs[1][2] ssegs[1][3] ssegs[1][4] ssegs[1][5] ssegs[1][6] ssegs[2][0] ssegs[2][1] ssegs[2][2] ssegs[2][3] ssegs[2][4] ssegs[2][5] ssegs[2][6] ssegs[3][0] ssegs[3][1] ssegs[3][2] ssegs[3][3] ssegs[3][4] ssegs[3][5] ssegs[3][6] ssegs[4][0] ssegs[4][1] ssegs[4][2] ssegs[4][3] ssegs[4][4] ssegs[4][5] ssegs[4][6] ssegs[5][0] ssegs[5][1] ssegs[5][2] ssegs[5][3] ssegs[5][4] ssegs[5][5] ssegs[5][6]}]