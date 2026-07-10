# Build a complete Nexys A7-100T / Nexys 4 DDR voice-game bitstream.
# Run from any directory with:
#   vivado -mode batch -source vivado/build_voice_game.tcl

set script_dir [file dirname [file normalize [info script]]]
set root_dir [file dirname $script_dir]
set build_dir [file join $root_dir build voice_game]
set artifact_dir [file join $root_dir build artifacts]
set rom_coe [file join $root_dir coe voice_game.coe]
set ram_coe [file join $root_dir coe D_mem.coe]

if {![file exists $rom_coe]} {
    error "Missing $rom_coe. Run 'make -C software' first."
}

file mkdir $build_dir
file mkdir $artifact_dir

create_project -force voice_game $build_dir -part xc7a100tcsg324-1
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

set rtl_sources [list \
    [file join $root_dir top.v] \
    [file join $root_dir code SCPU.v] \
    [file join $root_dir code RF.v] \
    [file join $root_dir code ctrl.v] \
    [file join $root_dir code ctrl_encode_def.v] \
    [file join $root_dir code alu.v] \
    [file join $root_dir code EXT.v] \
    [file join $root_dir code dm_controller.v] \
    [file join $root_dir IO Counter_3_IO.v] \
    [file join $root_dir IO Enter.v] \
    [file join $root_dir IO clk_div.v] \
    [file join $root_dir IO ps2_keyboard.v] \
    [file join $root_dir IO keyboard_display.v] \
    [file join $root_dir IO keyboard_control.v] \
    [file join $root_dir IO vga_timing.v] \
    [file join $root_dir IO vga_test_pattern.v] \
    [file join $root_dir IO mic_pdm_rx.v] \
    [file join $root_dir IO mic_voice_trigger.v] \
    [file join $root_dir IO mic_mmio.v] \
    [file join $root_dir IO video_mmio.v] \
    [file join $root_dir IO vga_game_renderer.v] \
    [file join $root_dir edf_file MIO_BUS.V] \
    [file join $root_dir edf_file Multi_8CH32.v] \
    [file join $root_dir edf_file SPIO.v] \
    [file join $root_dir edf_file SSeg7.v] \
]
add_files -norecurse $rtl_sources

add_files -norecurse [list \
    [file join $root_dir edf_file Multi_8CH32.edf] \
    [file join $root_dir edf_file SPIO.edf] \
    [file join $root_dir edf_file SSeg7.edf] \
]

add_files -fileset constrs_1 -norecurse [file join $root_dir icf.xdc]
set_property include_dirs [list [file join $root_dir code]] [get_filesets sources_1]
set_property top top [get_filesets sources_1]

# Asynchronous-read instruction ROM matching top.v's ROM_D(a, spo) interface.
create_ip -name dist_mem_gen -vendor xilinx.com -library ip -module_name ROM_D
set_property -dict [list \
    CONFIG.memory_type {rom} \
    CONFIG.depth {1024} \
    CONFIG.data_width {32} \
    CONFIG.output_options {non_registered} \
    CONFIG.coefficient_file $rom_coe \
] [get_ips ROM_D]

# 1024 x 32-bit byte-write data RAM matching top.v's RAM_B interface.
create_ip -name blk_mem_gen -vendor xilinx.com -library ip -module_name RAM_B
set_property -dict [list \
    CONFIG.Memory_Type {Single_Port_RAM} \
    CONFIG.Use_Byte_Write_Enable {true} \
    CONFIG.Byte_Size {8} \
    CONFIG.Write_Width_A {32} \
    CONFIG.Write_Depth_A {1024} \
    CONFIG.Read_Width_A {32} \
    CONFIG.Enable_A {Always_Enabled} \
    CONFIG.Register_PortA_Output_of_Memory_Primitives {false} \
    CONFIG.Load_Init_File {true} \
    CONFIG.Coe_File $ram_coe \
] [get_ips RAM_B]

generate_target all [get_ips ROM_D]
generate_target all [get_ips RAM_B]
update_compile_order -fileset sources_1

launch_runs synth_1 -jobs 4
wait_on_run synth_1
set synth_status [get_property STATUS [get_runs synth_1]]
if {![string match "*Complete*" $synth_status]} {
    error "Synthesis failed: $synth_status"
}

open_run synth_1
report_utilization -file [file join $artifact_dir post_synth_utilization.rpt]
report_timing_summary -file [file join $artifact_dir post_synth_timing.rpt]

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
set impl_status [get_property STATUS [get_runs impl_1]]
if {![string match "*Complete*" $impl_status]} {
    error "Implementation failed: $impl_status"
}

open_run impl_1
report_utilization -file [file join $artifact_dir post_route_utilization.rpt]
report_timing_summary -file [file join $artifact_dir post_route_timing.rpt]
report_drc -file [file join $artifact_dir post_route_drc.rpt]

set generated_bit [file join $build_dir voice_game.runs impl_1 top.bit]
if {![file exists $generated_bit]} {
    error "Implementation completed but bitstream was not found at $generated_bit"
}
file copy -force $generated_bit [file join $artifact_dir voice_game.bit]
puts "VOICE_GAME_BITSTREAM=[file join $artifact_dir voice_game.bit]"
