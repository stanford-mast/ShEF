# Open the u96 hw project
open_project ../hw/u96_hw/u96_hw.xpr

update_compile_order -fileset sources_1

#Run with n threads, change to match machine
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
exit