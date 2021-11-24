/**********
Copyright (c) 2018, Xilinx, Inc.
All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice,
this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation
and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors
may be used to endorse or promote products derived from this software
without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
**********/
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <cstring>
#include <iostream>
#include <CL/cl.h>
#include <time.h>
#include <sys/time.h>
#include <vector>
//#include "bitmap.h"
#include "xcl2.hpp"
#include "sw_affine.h"
#include "test_data.h"

#define X_SIZE 512
#define Y_SIZE 512


int main(int argc, char** argv)
{


	struct timeval start, end;
	struct timeval start_exec, end_exec;
	int i;
   
	FILE *input_file;
	FILE *output_file;

	int enc_image_size = 1748664;
	int output_image_size = Y_SIZE * X_SIZE + 7;
	cl_int err;

	size_t  input_size_bytes = sizeof(unsigned int) * enc_image_size;



	size_t output_size_bytes = sizeof(unsigned int) * output_image_size;

	std::vector<unsigned int,aligned_allocator<unsigned int>> input_image(enc_image_size);
	std::vector<unsigned int,aligned_allocator<unsigned int>> output_image0(output_image_size);

	std::vector<unsigned int,aligned_allocator<unsigned int>> output_image1(output_image_size);

	std::vector<unsigned int,aligned_allocator<unsigned int>> output_image2(output_image_size);

	std::vector<unsigned int,aligned_allocator<unsigned int>> output_image3(output_image_size);



	std::vector<unsigned int, aligned_allocator<unsigned int>> dummy(1);
	dummy[0] = 0;


//	unsigned int sw_input_image[X_SIZE * Y_SIZE];
//	for(i = 0; i < Y_SIZE*X_SIZE; i++){
//		unsigned char r = i % 255;
//		unsigned char g = (i+1) % 255;
//		unsigned char b = (i+2) % 255;
//		unsigned char a = (i+3) % 255;
//		sw_input_image[i] = (r << 24) | (g << 16) | (b << 8) | a;
//	}

	for(i = 0; i < enc_image_size; i++){
		input_image[i] = enc_image[i];
	}
	for( i = 0; i < output_image_size; i++){
		output_image0[i] = 0;
		output_image1[i] = 0;
		output_image2[i] = 0;
		output_image3[i] = 0;
	}



	std::vector<cl::Device> devices = xcl::get_xil_devices();
	cl::Device device = devices[0];
	OCL_CHECK(err, cl::Context context(device, NULL, NULL, NULL, &err));
  
	OCL_CHECK(err, cl::CommandQueue q(context, device,CL_QUEUE_OUT_OF_ORDER_EXEC_MODE_ENABLE , &err));

	OCL_CHECK(err, std::string device_name = device.getInfo<CL_DEVICE_NAME>(&err));
	std::string binaryFile = xcl::find_binary_file(device_name,"krnl_affine");
	cl::Program::Binaries bins = xcl::import_binary_file(binaryFile);
	devices.resize(1);
	OCL_CHECK(err, cl::Program program(context, devices, bins, NULL, &err));

	OCL_CHECK(err, cl::Kernel krnl_affine0(program,"affine_kernel0", &err));
	OCL_CHECK(err, cl::Kernel krnl_shield_ram_r01(program, "krnl_shield_ram_r01", &err));
	OCL_CHECK(err, cl::Kernel krnl_shield_ram_r23(program, "krnl_shield_ram_r23", &err));
	OCL_CHECK(err, cl::Kernel krnl_shield_ram_r45(program, "krnl_shield_ram_r45", &err));
	OCL_CHECK(err, cl::Kernel krnl_shield_ram_r67(program, "krnl_shield_ram_r67", &err));
	OCL_CHECK(err, cl::Kernel krnl_shield_ram_r89(program, "krnl_shield_ram_r89", &err));
	OCL_CHECK(err, cl::Kernel krnl_shield_ram_r1011(program, "krnl_shield_ram_r1011", &err));
	OCL_CHECK(err, cl::Kernel krnl_shield_ram_r1213(program, "krnl_shield_ram_r1213", &err));
	OCL_CHECK(err, cl::Kernel krnl_shield_ram_r1415(program, "krnl_shield_ram_r1415", &err));
	OCL_CHECK(err, cl::Kernel krnl_shield_output_o0(program, "krnl_shield_output_rtl_o0", &err));
	OCL_CHECK(err, cl::Kernel krnl_shield_output_o1(program, "krnl_shield_output_rtl_o1", &err));
	OCL_CHECK(err, cl::Kernel krnl_shield_output_o2(program, "krnl_shield_output_rtl_o2", &err));
	OCL_CHECK(err, cl::Kernel krnl_shield_output_o3(program, "krnl_shield_output_rtl_o3", &err));

	std::vector<cl::Memory> inBufVec, outBufVec;

	printf("CREATING BUFFERS\n");

	OCL_CHECK(err, cl::Buffer imageToDevice(context,CL_MEM_USE_HOST_PTR | CL_MEM_READ_ONLY,
			input_size_bytes, input_image.data(), &err));
	OCL_CHECK(err, cl::Buffer image0FromDevice(context,CL_MEM_USE_HOST_PTR | CL_MEM_WRITE_ONLY,
			output_size_bytes, output_image0.data(), &err));
	OCL_CHECK(err, cl::Buffer image1FromDevice(context,CL_MEM_USE_HOST_PTR | CL_MEM_WRITE_ONLY,
				output_size_bytes, output_image1.data(), &err));
	OCL_CHECK(err, cl::Buffer image2FromDevice(context,CL_MEM_USE_HOST_PTR | CL_MEM_WRITE_ONLY,
				output_size_bytes, output_image2.data(), &err));
	OCL_CHECK(err, cl::Buffer image3FromDevice(context,CL_MEM_USE_HOST_PTR | CL_MEM_WRITE_ONLY,
				output_size_bytes, output_image3.data(), &err));
	OCL_CHECK(err, cl::Buffer dummyInput(context, CL_MEM_USE_HOST_PTR | CL_MEM_READ_ONLY,
			4, dummy.data(), &err));



//	OCL_CHECK(err, cl::Buffer image2ToDevice(context,CL_MEM_USE_HOST_PTR | CL_MEM_READ_ONLY | CL_MEM_EXT_PTR_XILINX,
//			input_size_bytes, &in2Ext, &err));
//	OCL_CHECK(err, cl::Buffer image2FromDevice(context,CL_MEM_USE_HOST_PTR | CL_MEM_WRITE_ONLY | CL_MEM_EXT_PTR_XILINX,
//			output_size_bytes, &out2Ext, &err));
//	OCL_CHECK(err, cl::Buffer dummy2Input(context, CL_MEM_USE_HOST_PTR | CL_MEM_READ_ONLY | CL_MEM_EXT_PTR_XILINX,
//			4, &dummy2Ext, &err));
//	OCL_CHECK(err, cl::Buffer image3ToDevice(context,CL_MEM_USE_HOST_PTR | CL_MEM_READ_ONLY | CL_MEM_EXT_PTR_XILINX,
//			input_size_bytes, &in3Ext, &err));
//	OCL_CHECK(err, cl::Buffer image3FromDevice(context,CL_MEM_USE_HOST_PTR | CL_MEM_WRITE_ONLY | CL_MEM_EXT_PTR_XILINX,
//			output_size_bytes, &out3Ext, &err));
//	OCL_CHECK(err, cl::Buffer dummy3Input(context, CL_MEM_USE_HOST_PTR | CL_MEM_READ_ONLY | CL_MEM_EXT_PTR_XILINX,
//			4, &dummy3Ext, &err));






////
	inBufVec.push_back(imageToDevice);
	inBufVec.push_back(dummyInput);
	outBufVec.push_back(image0FromDevice);
	outBufVec.push_back(image1FromDevice);
	outBufVec.push_back(image2FromDevice);
	outBufVec.push_back(image3FromDevice);
//

	printf("Setting arguments\n");

	// Set the kernel arguments
	//
	OCL_CHECK(err, err = krnl_shield_ram_r01.setArg(0, imageToDevice));
	OCL_CHECK(err, err = krnl_shield_ram_r23.setArg(0, imageToDevice));
	OCL_CHECK(err, err = krnl_shield_ram_r45.setArg(0, imageToDevice));
	OCL_CHECK(err, err = krnl_shield_ram_r67.setArg(0, imageToDevice));
	OCL_CHECK(err, err = krnl_shield_ram_r89.setArg(0, imageToDevice));
	OCL_CHECK(err, err = krnl_shield_ram_r1011.setArg(0, imageToDevice));
	OCL_CHECK(err, err = krnl_shield_ram_r1213.setArg(0, imageToDevice));
	OCL_CHECK(err, err = krnl_shield_ram_r1415.setArg(0, imageToDevice));
	OCL_CHECK(err, err = krnl_affine0.setArg(0, dummyInput));
	OCL_CHECK(err, err = krnl_shield_output_o0.setArg(0, image0FromDevice));
	OCL_CHECK(err, err = krnl_shield_output_o0.setArg(1, output_image_size));
	OCL_CHECK(err, err = krnl_shield_output_o1.setArg(0, image1FromDevice));
	OCL_CHECK(err, err = krnl_shield_output_o1.setArg(1, output_image_size));
	OCL_CHECK(err, err = krnl_shield_output_o2.setArg(0, image2FromDevice));
	OCL_CHECK(err, err = krnl_shield_output_o2.setArg(1, output_image_size));
	OCL_CHECK(err, err = krnl_shield_output_o3.setArg(0, image3FromDevice));
	OCL_CHECK(err, err = krnl_shield_output_o3.setArg(1, output_image_size));

//
//	/* Copy input vectors to memory */
	gettimeofday(&start, 0);


	OCL_CHECK(err, err = q.enqueueMigrateMemObjects(inBufVec,0/* 0 means from host*/));
	OCL_CHECK(err, err = q.finish());



	// Launch the kernel
	gettimeofday(&start_exec, 0);

	OCL_CHECK(err, err = q.enqueueTask(krnl_affine0));
	OCL_CHECK(err, err = q.enqueueTask(krnl_shield_ram_r01));
	OCL_CHECK(err, err = q.enqueueTask(krnl_shield_ram_r23));
	OCL_CHECK(err, err = q.enqueueTask(krnl_shield_ram_r45));
	OCL_CHECK(err, err = q.enqueueTask(krnl_shield_ram_r67));
	OCL_CHECK(err, err = q.enqueueTask(krnl_shield_ram_r89));
	OCL_CHECK(err, err = q.enqueueTask(krnl_shield_ram_r1011));
	OCL_CHECK(err, err = q.enqueueTask(krnl_shield_ram_r1213));
	OCL_CHECK(err, err = q.enqueueTask(krnl_shield_ram_r1415));
	OCL_CHECK(err, err = q.enqueueTask(krnl_shield_output_o0));
	OCL_CHECK(err, err = q.enqueueTask(krnl_shield_output_o1));
	OCL_CHECK(err, err = q.enqueueTask(krnl_shield_output_o2));
	OCL_CHECK(err, err = q.enqueueTask(krnl_shield_output_o3));

	q.finish();
	gettimeofday(&end_exec, 0);



	OCL_CHECK(err, err = q.enqueueMigrateMemObjects(outBufVec,CL_MIGRATE_MEM_OBJECT_HOST));
	q.finish();

	gettimeofday(&end, 0);


	long long elapsed = (end.tv_sec - start.tv_sec) * 1000000LL + end.tv_usec - start.tv_usec;
	printf("Elapsed time HW: %lld us\n", elapsed);
	long long elapsed_exec = (end_exec.tv_sec - start_exec.tv_sec) * 1000000LL + end_exec.tv_usec - start_exec.tv_usec;
	printf("Elapsed time HW exec: %lld us\n", elapsed_exec);

	for(i = 0; i < output_image_size; i++){
		printf("%08x\n", output_image0[i]);
	}


	return 0 ;
}
