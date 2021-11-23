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

# TODO:
# Add check if CL_DIR and HDK_SHELL_DIR directories exist
# Add check if /build and /build/src_port_encryption directories exist
# Add check if the vivado_keyfile exist

set HDK_SHELL_DIR $::env(HDK_SHELL_DIR)
set HDK_SHELL_DESIGN_DIR $::env(HDK_SHELL_DESIGN_DIR)
set CL_DIR $::env(CL_DIR)
set SHEF_DIR $::env(SHEF_DIR)
set TARGET_DIR $CL_DIR/build/src_post_encryption
set UNUSED_TEMPLATES_DIR $HDK_SHELL_DESIGN_DIR/interfaces
# Remove any previously encrypted files, that may no longer be used
if {[llength [glob -nocomplain -dir $TARGET_DIR *]] != 0} {
  eval file delete -force [glob $TARGET_DIR/*]
}

#---- Developr would replace this section with design files ----

## Change file names and paths below to reflect your CL area.  DO NOT include AWS RTL files.
file copy -force $SHEF_DIR/hdk/src/interfaces/free_common_defines.vh    $TARGET_DIR
file copy -force $SHEF_DIR/hdk/src/interfaces/free_control_addrs.vh     $TARGET_DIR
file copy -force $SHEF_DIR/hdk/src/interfaces/free_interfaces_pkg.sv    $TARGET_DIR
file copy -force $SHEF_DIR/hdk/src/lib/free_control_s_axi.v             $TARGET_DIR
file copy -force $SHEF_DIR/hdk/src/lib/free_dma_ddr_slv.sv              $TARGET_DIR
file copy -force $SHEF_DIR/hdk/src/lib/primitives/shield_counter.sv     $TARGET_DIR
file copy -force $SHEF_DIR/hdk/src/lib/primitives/shield_muxes.sv       $TARGET_DIR
file copy -force $SHEF_DIR/hdk/src/lib/primitives/axi_muxes.sv          $TARGET_DIR
file copy -force $SHEF_DIR/hdk/src/lib/primitives/shield_rams.sv        $TARGET_DIR
file copy -force $SHEF_DIR/hdk/src/lib/primitives/shield_regfiles.sv    $TARGET_DIR
file copy -force $SHEF_DIR/hdk/src/lib/primitives/shield_regs.sv        $TARGET_DIR
file copy -force $SHEF_DIR/hdk/src/lib/crypto/aes.sv                    $TARGET_DIR
file copy -force $SHEF_DIR/hdk/src/lib/crypto/aes_core.v                $TARGET_DIR
file copy -force $SHEF_DIR/hdk/src/lib/crypto/aes_encipher_block.v      $TARGET_DIR
file copy -force $SHEF_DIR/hdk/src/lib/crypto/aes_key_mem.v             $TARGET_DIR
file copy -force $SHEF_DIR/hdk/src/lib/crypto/aes_sbox.v                $TARGET_DIR
file copy -force $SHEF_DIR/hdk/src/lib/crypto/aes_parallel.sv           $TARGET_DIR
file copy -force $SHEF_DIR/hdk/src/lib/crypto/hmac.sv                   $TARGET_DIR
file copy -force $SHEF_DIR/hdk/src/lib/crypto/hmac_stream.sv            $TARGET_DIR
file copy -force $SHEF_DIR/hdk/src/lib/crypto/pmac.sv                   $TARGET_DIR
file copy -force $SHEF_DIR/hdk/src/lib/crypto/pmac_ntz.sv               $TARGET_DIR
file copy -force $SHEF_DIR/hdk/src/lib/crypto/sha256_core.v             $TARGET_DIR
file copy -force $SHEF_DIR/hdk/src/lib/crypto/sha256_k_constants.v      $TARGET_DIR
file copy -force $SHEF_DIR/hdk/src/lib/crypto/sha256_w_mem.v            $TARGET_DIR
file copy -force $SHEF_DIR/hdk/src/lib/stream/stream_cmd_gen.sv         $TARGET_DIR
file copy -force $SHEF_DIR/hdk/src/lib/stream/stream.sv                 $TARGET_DIR
file copy -force $SHEF_DIR/hdk/src/lib/stream/stream_read.sv            $TARGET_DIR
file copy -force $SHEF_DIR/hdk/src/lib/stream/stream_write.sv           $TARGET_DIR
file copy -force $SHEF_DIR/hdk/src/lib/shield/shield_cmd_gen.sv         $TARGET_DIR
file copy -force $SHEF_DIR/hdk/src/lib/shield/shield_controller.sv      $TARGET_DIR
file copy -force $SHEF_DIR/hdk/src/lib/shield/shield_datapath.sv        $TARGET_DIR
file copy -force $SHEF_DIR/hdk/src/lib/shield/shield_read_mstr.sv       $TARGET_DIR
file copy -force $SHEF_DIR/hdk/src/lib/shield/shield_read_slv.sv        $TARGET_DIR
file copy -force $SHEF_DIR/hdk/src/lib/shield/shield_write_mstr.sv      $TARGET_DIR
file copy -force $SHEF_DIR/hdk/src/lib/shield/shield_write_slv.sv       $TARGET_DIR
file copy -force $SHEF_DIR/hdk/src/lib/shield/shield_read_decryptor.sv  $TARGET_DIR
file copy -force $SHEF_DIR/hdk/src/lib/shield/shield_write_encryptor.sv $TARGET_DIR
file copy -force $SHEF_DIR/hdk/src/lib/shield/shield_wrapper.sv         $TARGET_DIR

file copy -force $CL_DIR/design/cl_dnnweaver_defines.vh               $TARGET_DIR
file copy -force $CL_DIR/design/cl_id_defines.vh                      $TARGET_DIR
file copy -force $CL_DIR/design/cl_dnnweaver.sv                       $TARGET_DIR 

file copy -force $CL_DIR/design/include/pu_controller_bin.dat $TARGET_DIR
file copy -force $CL_DIR/design/include/common.vh $TARGET_DIR
file copy -force $CL_DIR/design/include/norm_lut.dat $TARGET_DIR
file copy -force $CL_DIR/design/include/dw_params.vh $TARGET_DIR
file copy -force $CL_DIR/design/include/rd_mem_controller.dat $TARGET_DIR
file copy -force $CL_DIR/design/include/wr_mem_controller.dat $TARGET_DIR
file copy -force $CL_DIR/design/source/axi_master/axi_master.v $TARGET_DIR
file copy -force $CL_DIR/design/source/axi_master_wrapper/axi_master_wrapper.v $TARGET_DIR
file copy -force $CL_DIR/design/source/axi_master/wburst_counter.v $TARGET_DIR
file copy -force $CL_DIR/design/source/primitives/FIFO/fifo.v $TARGET_DIR
file copy -force $CL_DIR/design/source/primitives/FIFO/fifo_fwft.v $TARGET_DIR
file copy -force $CL_DIR/design/source/primitives/FIFO/xilinx_bram_fifo.v $TARGET_DIR
file copy -force $CL_DIR/design/source/primitives/ROM/ROM.v $TARGET_DIR
file copy -force $CL_DIR/design/source/axi_slave/axi_slave.v $TARGET_DIR
file copy -force $CL_DIR/design/source/dnn_accelerator/dnn_accelerator.v $TARGET_DIR
file copy -force $CL_DIR/design/source/dnn_accelerator/dnn_accelerator_4AXI.v $TARGET_DIR
file copy -force $CL_DIR/design/source/mem_controller/mem_controller.v $TARGET_DIR
file copy -force $CL_DIR/design/source/mem_controller/mem_controller_top.v $TARGET_DIR
file copy -force $CL_DIR/design/source/mem_controller/mem_controller_top_4AXI.v $TARGET_DIR
file copy -force $CL_DIR/design/source/primitives/MACC/multiplier.v $TARGET_DIR
file copy -force $CL_DIR/design/source/primitives/MACC/macc.v $TARGET_DIR
file copy -force $CL_DIR/design/source/primitives/COUNTER/counter.v $TARGET_DIR
file copy -force $CL_DIR/design/source/PU/PU.v $TARGET_DIR
file copy -force $CL_DIR/design/source/PE/PE.v $TARGET_DIR
file copy -force $CL_DIR/design/source/primitives/REGISTER/register.v $TARGET_DIR
file copy -force $CL_DIR/design/source/normalization/normalization.v $TARGET_DIR
file copy -force $CL_DIR/design/source/primitives/PISO/piso.v $TARGET_DIR
file copy -force $CL_DIR/design/source/primitives/PISO/piso_norm.v $TARGET_DIR
file copy -force $CL_DIR/design/source/primitives/SIPO/sipo.v $TARGET_DIR
file copy -force $CL_DIR/design/source/pooling/pooling.v $TARGET_DIR
file copy -force $CL_DIR/design/source/primitives/COMPARATOR/comparator.v $TARGET_DIR
file copy -force $CL_DIR/design/source/primitives/MUX/mux_2x1.v $TARGET_DIR
file copy -force $CL_DIR/design/source/PE_buffer/PE_buffer.v $TARGET_DIR
file copy -force $CL_DIR/design/source/primitives/lfsr/lfsr.v $TARGET_DIR
file copy -force $CL_DIR/design/source/vectorgen/vectorgen.v $TARGET_DIR
file copy -force $CL_DIR/design/source/PU/PU_controller.v $TARGET_DIR
file copy -force $CL_DIR/design/source/weight_buffer/weight_buffer.v $TARGET_DIR
file copy -force $CL_DIR/design/source/primitives/RAM/ram.v $TARGET_DIR
file copy -force $CL_DIR/design/source/data_packer/data_packer.v $TARGET_DIR
file copy -force $CL_DIR/design/source/data_unpacker/data_unpacker.v $TARGET_DIR
file copy -force $CL_DIR/design/source/activation/activation.v $TARGET_DIR
file copy -force $CL_DIR/design/source/read_info/read_info.v $TARGET_DIR
file copy -force $CL_DIR/design/source/buffer_read_counter/buffer_read_counter.v $TARGET_DIR
file copy -force $CL_DIR/design/source/loopback/loopback_top.v $TARGET_DIR
file copy -force $CL_DIR/design/source/loopback/loopback.v $TARGET_DIR
file copy -force $CL_DIR/design/source/loopback_pu_controller/loopback_pu_controller_top.v $TARGET_DIR
file copy -force $CL_DIR/design/source/loopback_pu_controller/loopback_pu_controller.v $TARGET_DIR
file copy -force $CL_DIR/design/source/serdes/serdes.v $TARGET_DIR


file copy -force $UNUSED_TEMPLATES_DIR/unused_apppf_irq_template.inc  $TARGET_DIR
file copy -force $UNUSED_TEMPLATES_DIR/unused_cl_sda_template.inc     $TARGET_DIR
file copy -force $UNUSED_TEMPLATES_DIR/unused_ddr_a_b_d_template.inc  $TARGET_DIR
file copy -force $UNUSED_TEMPLATES_DIR/unused_ddr_c_template.inc      $TARGET_DIR
file copy -force $UNUSED_TEMPLATES_DIR/unused_dma_pcis_template.inc   $TARGET_DIR
file copy -force $UNUSED_TEMPLATES_DIR/unused_pcim_template.inc       $TARGET_DIR
file copy -force $UNUSED_TEMPLATES_DIR/unused_sh_bar1_template.inc    $TARGET_DIR
file copy -force $UNUSED_TEMPLATES_DIR/unused_flr_template.inc        $TARGET_DIR


#---- End of section replaced by Developr ---

# Make sure files have write permissions for the encryption
exec chmod +w {*}[glob $TARGET_DIR/*]

set TOOL_VERSION $::env(VIVADO_TOOL_VERSION)
set vivado_version [string range [version -short] 0 5]
puts "AWS FPGA: VIVADO_TOOL_VERSION $TOOL_VERSION"
puts "vivado_version $vivado_version"

# encrypt .v/.sv/.vh/inc as verilog files
encrypt -k $HDK_SHELL_DIR/build/scripts/vivado_keyfile_2017_4.txt -lang verilog  [glob -nocomplain -- $TARGET_DIR/*.{v,sv}] [glob -nocomplain -- $TARGET_DIR/*.vh] [glob -nocomplain -- $TARGET_DIR/*.inc]
# encrypt *vhdl files
encrypt -k $HDK_SHELL_DIR/build/scripts/vivado_vhdl_keyfile_2017_4.txt -lang vhdl -quiet [ glob -nocomplain -- $TARGET_DIR/*.vhd? ]
