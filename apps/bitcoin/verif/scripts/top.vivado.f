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
-include ${SHEF_INTERFACES_DIR}
-include ${SHEF_LIB_DIR}

#FREE Files
${SHEF_INTERFACES_DIR}/free_common_defines.vh
${SHEF_INTERFACES_DIR}/free_control_addrs.vh
${SHEF_INTERFACES_DIR}/free_interfaces_pkg.sv
${SHEF_LIB_DIR}/free_control_s_axi.v
${SHEF_LIB_DIR}/primitives/shield_counter.sv
${SHEF_LIB_DIR}/primitives/shield_muxes.sv
${SHEF_LIB_DIR}/primitives/shield_rams.sv
${SHEF_LIB_DIR}/primitives/shield_regfiles.sv
${SHEF_LIB_DIR}/primitives/shield_regs.sv
${SHEF_LIB_DIR}/crypto/sha256_core.v
${SHEF_LIB_DIR}/crypto/sha256_k_constants.v
${SHEF_LIB_DIR}/crypto/sha256_w_mem.v

#App files
${CL_ROOT}/design/cl_bitcoin_defines.vh
${CL_ROOT}/design/cl_id_defines.vh
${CL_ROOT}/design/cl_bitcoin.sv
${CL_ROOT}/design/source/bitcoin.sv


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





