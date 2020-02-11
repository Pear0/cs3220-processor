set_global_assignment -entity "main_pll" -library "lib_main_pll" -name IP_TOOL_NAME "altera_pll"
set_global_assignment -entity "main_pll" -library "lib_main_pll" -name IP_TOOL_VERSION "18.0"
set_global_assignment -entity "main_pll" -library "lib_main_pll" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_main_pll" -name SPD_FILE [file join $::quartus(sip_path) "main_pll.spd"]

set_global_assignment -library "lib_main_pll" -name MISC_FILE [file join $::quartus(sip_path) "main_pll_sim/main_pll.vo"]
