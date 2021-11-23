# Amazon FPGA Hardware Development Kit
#
# Copyright 2016 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Amazon Software License (the "License"). You may not use
# this file except in compliance with the License. A copy of the License is
# located at
#
#    http://aws.amazon.com/asl/
#
# or in the "license" file accompanying this file. This file is distributed on
# an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, express or
# implied. See the License for the specific language governing permissions and
# limitations under the License.

-define VIVADO_SIM

-sourcelibext .v
-sourcelibext .sv
-sourcelibext .svh

-sourcelibdir ${CL_ROOT}/design
-sourcelibdir ${SH_LIB_DIR}
-sourcelibdir ${SH_INF_DIR}
-sourcelibdir ${SH_SH_DIR}
#-sourcelibdir ${HDK_SHELL_DESIGN_DIR}/ip/cl_debug_bridge/bd_0/hdl
#-sourcelibdir ${HDK_SHELL_DESIGN_DIR}/ip/cl_debug_bridge/sim
-sourcelibdir ${HDK_SHELL_DESIGN_DIR}/sh_ddr/sim
-sourcelibdir ${SHEF_INTERFACES_DIR}
-sourcelibdir ${SHEF_LIB_DIR}

-include ${SH_LIB_DIR}
-include ${SH_INF_DIR}
-include ${SH_SH_DIR}
-include ${HDK_COMMON_DIR}/verif/include
-include ${HDK_SHELL_DESIGN_DIR}/ip/cl_debug_bridge/bd_0/ip/ip_0/sim
-include ${HDK_SHELL_DESIGN_DIR}/ip/cl_debug_bridge/bd_0/ip/ip_0/hdl/verilog
-include ${HDK_SHELL_DESIGN_DIR}/ip/axi_register_slice/hdl
-include ${HDK_SHELL_DESIGN_DIR}/ip/axi_register_slice_light/hdl
-include ${HDK_SHELL_DESIGN_DIR}/sh_ddr/sim
-include ${SHEF_INTERFACES_DIR}
-include ${SHEF_LIB_DIR}
-include ${CL_ROOT}/design/include
-include ${CL_ROOT}/design/ip/axi_dwidth_converter_64b_to_512b/hdl

#SHEF Files
${SHEF_INTERFACES_DIR}/free_common_defines.vh
${SHEF_INTERFACES_DIR}/free_control_addrs.vh
${SHEF_INTERFACES_DIR}/free_interfaces_pkg.sv
${SHEF_LIB_DIR}/free_control_s_axi.v

#App files
${CL_ROOT}/design/cl_dnnweaver_defines.vh
${CL_ROOT}/design/cl_id_defines.vh
${CL_ROOT}/design/cl_dnnweaver.sv

#${CL_ROOT}/design/include/pu_controller_bin.vh
${CL_ROOT}/design/include/common.vh
${CL_ROOT}/design/include/dw_params.vh
#${CL_ROOT}/design/include/rd_mem_controller.vh
#${CL_ROOT}/design/include/wr_mem_controller.vh

${CL_ROOT}/design/source/axi_master/axi_master.v
${CL_ROOT}/design/source/axi_master_wrapper/axi_master_wrapper.v
${CL_ROOT}/design/source/axi_master/wburst_counter.v
${CL_ROOT}/design/source/primitives/FIFO/fifo.v
${CL_ROOT}/design/source/primitives/FIFO/fifo_fwft.v
${CL_ROOT}/design/source/primitives/FIFO/xilinx_bram_fifo.v
${CL_ROOT}/design/source/primitives/ROM/ROM.v
${CL_ROOT}/design/source/axi_slave/axi_slave.v
${CL_ROOT}/design/source/dnn_accelerator/dnn_accelerator.v
${CL_ROOT}/design/source/dnn_accelerator/dnn_accelerator_4AXI.v
${CL_ROOT}/design/source/mem_controller/mem_controller.v
${CL_ROOT}/design/source/mem_controller/mem_controller_top.v
${CL_ROOT}/design/source/mem_controller/mem_controller_top_4AXI.v
${CL_ROOT}/design/source/primitives/MACC/multiplier.v
${CL_ROOT}/design/source/primitives/MACC/macc.v
${CL_ROOT}/design/source/primitives/COUNTER/counter.v
${CL_ROOT}/design/source/PU/PU.v
${CL_ROOT}/design/source/PE/PE.v
${CL_ROOT}/design/source/primitives/REGISTER/register.v
${CL_ROOT}/design/source/normalization/normalization.v
${CL_ROOT}/design/source/primitives/PISO/piso.v
${CL_ROOT}/design/source/primitives/PISO/piso_norm.v
${CL_ROOT}/design/source/primitives/SIPO/sipo.v
${CL_ROOT}/design/source/pooling/pooling.v
${CL_ROOT}/design/source/primitives/COMPARATOR/comparator.v
${CL_ROOT}/design/source/primitives/MUX/mux_2x1.v
${CL_ROOT}/design/source/PE_buffer/PE_buffer.v
${CL_ROOT}/design/source/primitives/lfsr/lfsr.v
${CL_ROOT}/design/source/vectorgen/vectorgen.v
${CL_ROOT}/design/source/PU/PU_controller.v
${CL_ROOT}/design/source/weight_buffer/weight_buffer.v
${CL_ROOT}/design/source/primitives/RAM/ram.v
${CL_ROOT}/design/source/data_packer/data_packer.v
${CL_ROOT}/design/source/data_unpacker/data_unpacker.v
${CL_ROOT}/design/source/activation/activation.v
${CL_ROOT}/design/source/read_info/read_info.v
${CL_ROOT}/design/source/buffer_read_counter/buffer_read_counter.v
${CL_ROOT}/design/source/loopback/loopback_top.v
${CL_ROOT}/design/source/loopback/loopback.v
${CL_ROOT}/design/source/loopback_pu_controller/loopback_pu_controller_top.v
${CL_ROOT}/design/source/loopback_pu_controller/loopback_pu_controller.v
${CL_ROOT}/design/source/serdes/serdes.v



#THIS NEEDS TO GO BEFORE DDR INCLUDES
-f ${HDK_COMMON_DIR}/verif/tb/filelists/tb.${SIMULATOR}.f
${TEST_NAME}

#IP Files
#${HDK_SHELL_DESIGN_DIR}/ip/ila_vio_counter/sim/ila_vio_counter.v
#${HDK_SHELL_DESIGN_DIR}/ip/ila_0/sim/ila_0.v
#${HDK_SHELL_DESIGN_DIR}/ip/cl_debug_bridge/bd_0/sim/bd_a493.v
#${HDK_SHELL_DESIGN_DIR}/ip/cl_debug_bridge/bd_0/ip/ip_0/sim/bd_a493_xsdbm_0.v
#${HDK_SHELL_DESIGN_DIR}/ip/cl_debug_bridge/bd_0/ip/ip_0/hdl/xsdbm_v3_0_vl_rfs.v
#${HDK_SHELL_DESIGN_DIR}/ip/cl_debug_bridge/bd_0/ip/ip_0/hdl/ltlib_v1_0_vl_rfs.v
#${HDK_SHELL_DESIGN_DIR}/ip/cl_debug_bridge/bd_0/ip/ip_1/sim/bd_a493_lut_buffer_0.v
#${HDK_SHELL_DESIGN_DIR}/ip/cl_debug_bridge/bd_0/ip/ip_1/hdl/lut_buffer_v2_0_vl_rfs.v
#${HDK_SHELL_DESIGN_DIR}/ip/cl_debug_bridge/bd_0/hdl/bd_a493_wrapper.v
#${HDK_SHELL_DESIGN_DIR}/ip/cl_debug_bridge/sim/cl_debug_bridge.v
#${HDK_SHELL_DESIGN_DIR}/ip/vio_0/sim/vio_0.v
${HDK_SHELL_DESIGN_DIR}/ip/axi_register_slice_light/sim/axi_register_slice_light.v
${HDK_SHELL_DESIGN_DIR}/ip/axi_register_slice/sim/axi_register_slice.v
${HDK_SHELL_DESIGN_DIR}/ip/axi_register_slice_light/hdl/axi_register_slice_v2_1_vl_rfs.v
${HDK_SHELL_DESIGN_DIR}/ip/axi_register_slice_light/hdl/axi_infrastructure_v1_1_vl_rfs.v
${HDK_SHELL_DESIGN_DIR}/ip/axi_clock_converter_0/hdl/axi_clock_converter_v2_1_vl_rfs.v
${HDK_SHELL_DESIGN_DIR}/ip/axi_clock_converter_0/hdl/fifo_generator_v13_2_rfs.v
${SH_LIB_DIR}/../ip/axi_clock_converter_0/sim/axi_clock_converter_0.v
${HDK_SHELL_DESIGN_DIR}/ip/dest_register_slice/sim/dest_register_slice.v
${HDK_SHELL_DESIGN_DIR}/ip/src_register_slice/sim/src_register_slice.v

${HDK_SHELL_DESIGN_DIR}/ip/cl_axi_interconnect/ipshared/9909/hdl/axi_data_fifo_v2_1_vl_rfs.v
${HDK_SHELL_DESIGN_DIR}/ip/cl_axi_interconnect/ipshared/c631/hdl/axi_crossbar_v2_1_vl_rfs.v
${HDK_SHELL_DESIGN_DIR}/ip/cl_axi_interconnect/ip/cl_axi_interconnect_xbar_0/sim/cl_axi_interconnect_xbar_0.v
${HDK_SHELL_DESIGN_DIR}/ip/cl_axi_interconnect/ip/cl_axi_interconnect_s00_regslice_0/sim/cl_axi_interconnect_s00_regslice_0.v
${HDK_SHELL_DESIGN_DIR}/ip/cl_axi_interconnect/ip/cl_axi_interconnect_s01_regslice_0/sim/cl_axi_interconnect_s01_regslice_0.v
${HDK_SHELL_DESIGN_DIR}/ip/cl_axi_interconnect/ip/cl_axi_interconnect_m00_regslice_0/sim/cl_axi_interconnect_m00_regslice_0.v
${HDK_SHELL_DESIGN_DIR}/ip/cl_axi_interconnect/ip/cl_axi_interconnect_m01_regslice_0/sim/cl_axi_interconnect_m01_regslice_0.v
${HDK_SHELL_DESIGN_DIR}/ip/cl_axi_interconnect/ip/cl_axi_interconnect_m02_regslice_0/sim/cl_axi_interconnect_m02_regslice_0.v
${HDK_SHELL_DESIGN_DIR}/ip/cl_axi_interconnect/ip/cl_axi_interconnect_m03_regslice_0/sim/cl_axi_interconnect_m03_regslice_0.v
${HDK_SHELL_DESIGN_DIR}/ip/cl_axi_interconnect/sim/cl_axi_interconnect.v

${CL_ROOT}/design/ip/axi_dwidth_converter_64b_to_512b/hdl/axi_register_slice_v2_1_vl_rfs.v
${CL_ROOT}/design/ip/axi_dwidth_converter_64b_to_512b/hdl/axi_dwidth_converter_v2_1_vl_rfs.v
${CL_ROOT}/design/ip/axi_dwidth_converter_64b_to_512b/sim/axi_dwidth_converter_64b_to_512b.v

${HDK_COMMON_DIR}/verif/models/ddr4_rdimm_wrapper/ddr4_bi_delay.sv
${HDK_COMMON_DIR}/verif/models/ddr4_rdimm_wrapper/ddr4_db_delay_model.sv
${HDK_COMMON_DIR}/verif/models/ddr4_rdimm_wrapper/ddr4_db_dly_dir.sv
${HDK_COMMON_DIR}/verif/models/ddr4_rdimm_wrapper/ddr4_dir_detect.sv
${HDK_COMMON_DIR}/verif/models/ddr4_rdimm_wrapper/ddr4_rcd_model.sv
${HDK_COMMON_DIR}/verif/models/ddr4_rdimm_wrapper/ddr4_rank.sv
${HDK_COMMON_DIR}/verif/models/ddr4_rdimm_wrapper/ddr4_dimm.sv
${HDK_COMMON_DIR}/verif/models/ddr4_rdimm_wrapper/ddr4_rdimm_wrapper.sv 
${SH_LIB_DIR}/bram_2rw.sv
${SH_LIB_DIR}/flop_fifo.sv
${SH_LIB_DIR}/lib_pipe.sv
${HDK_SHELL_DESIGN_DIR}/sh_ddr/sim/mgt_gen_axl.sv
${HDK_SHELL_DESIGN_DIR}/sh_ddr/sim/ccf_ctl.v
${HDK_SHELL_DESIGN_DIR}/sh_ddr/sim/mgt_acc_axl.sv
${HDK_SHELL_DESIGN_DIR}/sh_ddr/sim/sync.v
${HDK_SHELL_DESIGN_DIR}/sh_ddr/sim/flop_ccf.sv
${HDK_SHELL_DESIGN_DIR}/sh_ddr/sim/sh_ddr.sv



