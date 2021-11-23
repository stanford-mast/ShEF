onbreak {quit -f}
onerror {quit -f}

vsim -t 1ps -lib xil_defaultlib axi_dwidth_converter_64b_to_512b_opt

do {wave.do}

view wave
view structure
view signals

do {axi_dwidth_converter_64b_to_512b.udo}

run -all

quit -force
