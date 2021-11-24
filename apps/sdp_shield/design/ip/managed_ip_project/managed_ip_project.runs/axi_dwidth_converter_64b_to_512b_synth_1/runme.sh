#!/bin/sh

# 
# Vivado(TM)
# runme.sh: a Vivado-generated Runs Script for UNIX
# Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
# 

if [ -z "$PATH" ]; then
  PATH=/opt/Xilinx/Vitis/2019.2/bin:/opt/Xilinx/Vivado/2019.2/bin
else
  PATH=/opt/Xilinx/Vitis/2019.2/bin:/opt/Xilinx/Vivado/2019.2/bin:$PATH
fi
export PATH

if [ -z "$LD_LIBRARY_PATH" ]; then
  LD_LIBRARY_PATH=
else
  LD_LIBRARY_PATH=:$LD_LIBRARY_PATH
fi
export LD_LIBRARY_PATH

HD_PWD='/home/centos/src/project_data/free/apps/dnnweaver/design/ip/managed_ip_project/managed_ip_project.runs/axi_dwidth_converter_64b_to_512b_synth_1'
cd "$HD_PWD"

HD_LOG=runme.log
/bin/touch $HD_LOG

ISEStep="./ISEWrap.sh"
EAStep()
{
     $ISEStep $HD_LOG "$@" >> $HD_LOG 2>&1
     if [ $? -ne 0 ]
     then
         exit
     fi
}

EAStep vivado -log axi_dwidth_converter_64b_to_512b.vds -m64 -product Vivado -mode batch -messageDb vivado.pb -notrace -source axi_dwidth_converter_64b_to_512b.tcl
