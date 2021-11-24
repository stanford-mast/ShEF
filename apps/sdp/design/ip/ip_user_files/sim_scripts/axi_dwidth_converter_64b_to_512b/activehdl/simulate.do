onbreak {quit -force}
onerror {quit -force}

asim -t 1ps +access +r +m+axi_dwidth_converter_64b_to_512b -L xpm -L generic_baseblocks_v2_1_0 -L fifo_generator_v13_2_5 -L axi_data_fifo_v2_1_19 -L axi_infrastructure_v1_1_0 -L axi_register_slice_v2_1_20 -L axi_protocol_converter_v2_1_20 -L axi_clock_converter_v2_1_19 -L blk_mem_gen_v8_4_4 -L axi_dwidth_converter_v2_1_20 -L xil_defaultlib -L unisims_ver -L unimacro_ver -L secureip -O5 xil_defaultlib.axi_dwidth_converter_64b_to_512b xil_defaultlib.glbl

do {wave.do}

view wave
view structure

do {axi_dwidth_converter_64b_to_512b.udo}

run -all

endsim

quit -force
