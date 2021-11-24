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


	size_t vector_size_bytes = sizeof(unsigned int) * Y_SIZE*X_SIZE;
	std::vector<unsigned int,aligned_allocator<unsigned int>> input_image0(Y_SIZE*X_SIZE);
	std::vector<unsigned int,aligned_allocator<unsigned int>> input_image1(Y_SIZE*X_SIZE);
	std::vector<unsigned int,aligned_allocator<unsigned int>> input_image2(Y_SIZE*X_SIZE);
	std::vector<unsigned int,aligned_allocator<unsigned int>> input_image3(Y_SIZE*X_SIZE);
	cl_int err;

	std::vector<unsigned int,aligned_allocator<unsigned int>> output_image0(Y_SIZE*X_SIZE);
	std::vector<unsigned int,aligned_allocator<unsigned int>> output_image1(Y_SIZE*X_SIZE);
	std::vector<unsigned int,aligned_allocator<unsigned int>> output_image2(Y_SIZE*X_SIZE);
	std::vector<unsigned int,aligned_allocator<unsigned int>> output_image3(Y_SIZE*X_SIZE);

	unsigned int sw_input_image0[X_SIZE * Y_SIZE];
	unsigned int sw_input_image1[X_SIZE * Y_SIZE];
	unsigned int sw_input_image2[X_SIZE * Y_SIZE];
	unsigned int sw_input_image3[X_SIZE * Y_SIZE];
	for(i = 0; i < Y_SIZE*X_SIZE; i++){
		unsigned char r = i % 255;
		unsigned char g = (i+1) % 255;
		unsigned char b = (i+2) % 255;
		unsigned char a = (i+3) % 255;
		sw_input_image0[i] = (r << 24) | (g << 16) | (b << 8) | a;
		sw_input_image1[i] = (r << 24) | (g << 16) | (b << 8) | a;
		sw_input_image2[i] = (r << 24) | (g << 16) | (b << 8) | a;
		sw_input_image3[i] = (r << 24) | (g << 16) | (b << 8) | a;
		input_image0[i] = (r << 24) | (g << 16) | (b << 8) | a;
		input_image1[i] = (r << 24) | (g << 16) | (b << 8) | a;
		input_image2[i] = (r << 24) | (g << 16) | (b << 8) | a;
		input_image3[i] = (r << 24) | (g << 16) | (b << 8) | a;
	}

	printf("Loaded image\n");

// Read the bit map file into memory and allocate memory for the final image
	//std::cout << "Reading input image...\n";
////// Load the input image
	//const char *imageFilename = "/home/centos/src/project_data/workspace/free-shield/sdx_workspace/baseline_affine/data/img.dat";
	//input_file = fopen(imageFilename, "rb");
	//if (!input_file)
	//{
	//	printf("Error: Unable to open input image file %s!\n",
	//	imageFilename);
	//	return 1;
	// }
	//printf("\n");
	//printf("   Reading RAW Image\n");
	//size_t items_read = fread(input_image.data(), vector_size_bytes,1,input_file);
	//printf("   Bytes read = %d\n\n", (int)(items_read* sizeof input_image));

	std::vector<cl::Device> devices = xcl::get_xil_devices();
	cl::Device device = devices[0];
	OCL_CHECK(err, cl::Context context(device, NULL, NULL, NULL, &err));

	OCL_CHECK(err, cl::CommandQueue q(context, device,CL_QUEUE_OUT_OF_ORDER_EXEC_MODE_ENABLE , &err));

	OCL_CHECK(err, std::string device_name = device.getInfo<CL_DEVICE_NAME>(&err));
	std::string binaryFile = xcl::find_binary_file(device_name,"krnl_affine");
	cl::Program::Binaries bins = xcl::import_binary_file(binaryFile);
	devices.resize(1);
	OCL_CHECK(err, cl::Program program(context, devices, bins, NULL, &err));
	OCL_CHECK(err, cl::Kernel krnl0(program,"affine_kernel0", &err));
	OCL_CHECK(err, cl::Kernel krnl1(program,"affine_kernel1", &err));
	OCL_CHECK(err, cl::Kernel krnl2(program,"affine_kernel2", &err));
	OCL_CHECK(err, cl::Kernel krnl3(program,"affine_kernel3", &err));

	printf("Created kernels\n");

	std::vector<cl::Memory> inBufVec, outBufVec;
	OCL_CHECK(err, cl::Buffer imageToDevice0(context,CL_MEM_USE_HOST_PTR | CL_MEM_READ_ONLY, vector_size_bytes, input_image0.data(), &err));
	OCL_CHECK(err, cl::Buffer imageToDevice1(context,CL_MEM_USE_HOST_PTR | CL_MEM_READ_ONLY, vector_size_bytes, input_image1.data(), &err));
	OCL_CHECK(err, cl::Buffer imageToDevice2(context,CL_MEM_USE_HOST_PTR | CL_MEM_READ_ONLY, vector_size_bytes, input_image2.data(), &err));
	OCL_CHECK(err, cl::Buffer imageToDevice3(context,CL_MEM_USE_HOST_PTR | CL_MEM_READ_ONLY, vector_size_bytes, input_image3.data(), &err));
	OCL_CHECK(err, cl::Buffer imageFromDevice0(context,CL_MEM_USE_HOST_PTR | CL_MEM_WRITE_ONLY,vector_size_bytes, output_image0.data(), &err));
	OCL_CHECK(err, cl::Buffer imageFromDevice1(context,CL_MEM_USE_HOST_PTR | CL_MEM_WRITE_ONLY,vector_size_bytes, output_image1.data(), &err));
	OCL_CHECK(err, cl::Buffer imageFromDevice2(context,CL_MEM_USE_HOST_PTR | CL_MEM_WRITE_ONLY,vector_size_bytes, output_image2.data(), &err));
	OCL_CHECK(err, cl::Buffer imageFromDevice3(context,CL_MEM_USE_HOST_PTR | CL_MEM_WRITE_ONLY,vector_size_bytes, output_image3.data(), &err));

	inBufVec.push_back(imageToDevice0);
	inBufVec.push_back(imageToDevice1);
	inBufVec.push_back(imageToDevice2);
	inBufVec.push_back(imageToDevice3);
	outBufVec.push_back(imageFromDevice0);
	outBufVec.push_back(imageFromDevice1);
	outBufVec.push_back(imageFromDevice2);
	outBufVec.push_back(imageFromDevice3);

	// Set the kernel arguments
	OCL_CHECK(err, err = krnl0.setArg(0, imageToDevice0));
	OCL_CHECK(err, err = krnl0.setArg(1, imageFromDevice0));
	OCL_CHECK(err, err = krnl1.setArg(0, imageToDevice1));
	OCL_CHECK(err, err = krnl1.setArg(1, imageFromDevice1));
	OCL_CHECK(err, err = krnl2.setArg(0, imageToDevice2));
	OCL_CHECK(err, err = krnl2.setArg(1, imageFromDevice2));
	OCL_CHECK(err, err = krnl3.setArg(0, imageToDevice3));
	OCL_CHECK(err, err = krnl3.setArg(1, imageFromDevice3));

	/* Copy input vectors to memory */
	gettimeofday(&start, 0);
	OCL_CHECK(err, err = q.enqueueMigrateMemObjects(inBufVec,0/* 0 means from host*/));
	OCL_CHECK(err, err = q.finish());



	// Launch the kernel
	gettimeofday(&start_exec, 0);
	OCL_CHECK(err, err = q.enqueueTask(krnl0));
	OCL_CHECK(err, err = q.enqueueTask(krnl1));
	OCL_CHECK(err, err = q.enqueueTask(krnl2));
	OCL_CHECK(err, err = q.enqueueTask(krnl3));
	q.finish();
	gettimeofday(&end_exec, 0);

	OCL_CHECK(err, err = q.enqueueMigrateMemObjects(outBufVec,CL_MIGRATE_MEM_OBJECT_HOST));
	q.finish();
	gettimeofday(&end, 0);

	long long elapsed = (end.tv_sec - start.tv_sec) * 1000000LL + end.tv_usec - start.tv_usec;
	printf("Elapsed time HW: %lld us\n", elapsed);
	long long elapsed_exec = (end_exec.tv_sec - start_exec.tv_sec) * 1000000LL + end_exec.tv_usec - start_exec.tv_usec;
	printf("Elapsed time HW exec: %lld us\n", elapsed_exec);

	unsigned int sw_results0[512*512];
	unsigned int sw_results1[512*512];
	unsigned int sw_results2[512*512];
	unsigned int sw_results3[512*512];
	gettimeofday(&start, 0);
	sw_affine(sw_input_image0, sw_results0);
	sw_affine(sw_input_image1, sw_results1);
	sw_affine(sw_input_image2, sw_results2);
	sw_affine(sw_input_image0, sw_results3);
	gettimeofday(&end, 0);

	int j = 0;

	for (i = 0; i < 512*512; i++){
		//printf("%08x\n", sw_results[i]);
		//unsigned char sw_r = sw_results[i] >> 24;
		//unsigned char sw_g = sw_results[i] >> 16;
		//unsigned char sw_b = sw_results[i] >> 8;
		//unsigned char sw_a = sw_results[i];
		//unsigned char hw_r = results[i] >> 24;
		//unsigned char hw_g = results[i] >> 16;
		//unsigned char hw_b = results[i] >> 8;
		//unsigned char hw_a = results[i];



		//if( (abs((int)sw_r - (int)hw_r) > 2) ||
		//		(abs((int)sw_g - (int)hw_g) > 2) ||
		//		(abs((int)sw_b - (int)hw_b) > 2) ||
		//		(abs((int)sw_a - (int)hw_a) > 2)){
		//	printf("ERROR: %d :",i);
		//	printf("%x, %x\n", sw_results[i], results[i]);
		//	//break;
		//	j++;
		//}
	}
	printf("J %d\n", j);

	elapsed = (end.tv_sec - start.tv_sec) * 1000000LL + end.tv_usec - start.tv_usec;
	printf("Elapsed time SW: %lld us\n", elapsed);

//// Read back the image from the kernel
//	std::cout << "Reading output image and writing to file...\n";
//	output_file = fopen("transformed_image.raw", "wb");
//	if (!output_file)
//	{
//		printf("Error: Unable to open output image file!\n");
//		return 1;
//	}

	printf("   Writing RAW Image\n");
//	size_t items_written = fwrite(output_image0.data(), vector_size_bytes, 1, output_file);
//	printf("   Bytes written = %d\n\n", (int)(items_written * sizeof output_image0));

	return 0 ;
}
