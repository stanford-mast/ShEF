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

/*******************************************************************************
Description: SDx Vector Addition using Blocking Pipes Operation
*******************************************************************************/

#define INCR_VALUE 10

#include <iostream>
#include <cstring>
#include <cstdio>
#include <vector>
#include "xcl2.hpp"
#include <unistd.h>
#include <sys/time.h>

#include "test_data.hpp"

#define X_SIZE 512
#define Y_SIZE 512


int main(int argc, char** argv)
{
    cl_int err;

    // Reducing the data size for emulation mode
//    char *xcl_mode = getenv("XCL_EMULATION_MODE");
//    if (xcl_mode != NULL){
//        data_size = 1024;
//    }
    struct timeval start, end;
	struct timeval start_exec, end_exec;

    //Allocate Memory in Host Memory
    int server_size =  9438136;
    int output_size = 512*512+4;
    //size_t output_size = 65; // B+1
    int input_size = 1409127;
    int chunk_size = 0x200;

    size_t output_size_bytes = output_size * sizeof(unsigned int);
    size_t input_size_bytes = input_size * sizeof(unsigned int);
    size_t server_size_bytes = server_size * sizeof(unsigned int);
//    size_t vector_size_bytes = sizeof(unsigned int) * data_size;
//    std::vector<unsigned int,aligned_allocator<unsigned int>> source_input_a     (data_size);
//    std::vector<unsigned int,aligned_allocator<unsigned int>> source_input_b     (data_size);
    std::vector<unsigned int, aligned_allocator<unsigned int>> source_server (server_size);
    std::vector<unsigned int, aligned_allocator<unsigned int>> input_image(input_size);
    std::vector<unsigned int, aligned_allocator<unsigned int>> output_image0(output_size);
//    std::vector<unsigned int, aligned_allocator<unsigned int>> output_image1(output_size);
//    std::vector<unsigned int, aligned_allocator<unsigned int>> output_image2(output_size);
//    std::vector<unsigned int, aligned_allocator<unsigned int>> output_image3(output_size);
	std::vector<unsigned int, aligned_allocator<unsigned int>> dummy(output_size);
//
//    std::vector<unsigned int,aligned_allocator<unsigned int>> source_hw_results(data_size);
//    std::vector<unsigned int,aligned_allocator<unsigned int>> source_sw_results(data_size);
//
//    // Create the test data and Software Result
//    for(size_t i = 0 ; i < data_size; i++){
//        source_input_a[i] = input_a[i];
//        source_input_b[i] = input_b[i];
//        source_hw_results[i] = 0;
//    }
    for(int i = 0; i < server_size; i++){
    	source_server[i] = input_server[i];
    }
//    for(int i = 0; i < input_size; i++){
//    	input_image[i] = input_image_enc[i];
//    }
    for(int i = 0; i < output_size; i++){
    	dummy[i] = 0;
//    	output_image1[i] = 0;
//    	output_image2[i] = 0;
//    	output_image3[i] = 0;
    }

//OPENCL HOST CODE AREA START
    // get_xil_devices() is a utility API which will find the Xilinx
    // platforms and will return list of devices connected to Xilinx platform
    std::vector<cl::Device> devices = xcl::get_xil_devices();
    cl::Device device = devices[0];

    std::cout << "Creating Context..." <<std::endl;
    OCL_CHECK(err, cl::Context context (device, NULL, NULL, NULL, &err));
    OCL_CHECK(err, cl::CommandQueue q (context, device, CL_QUEUE_OUT_OF_ORDER_EXEC_MODE_ENABLE, &err));
    OCL_CHECK(err, std::string device_name = device.getInfo<CL_DEVICE_NAME>(&err));

    // find_binary_file() is a utility API which will search the xclbin file for
    // targeted mode (sw_emu/hw_emu/hw) and for targeted platforms.
    std::string binaryFile = xcl::find_binary_file(device_name, "binary");

    // import_binary_file() ia a utility API which will load the binaryFile
    // and will return Binaries.
    cl::Program::Binaries bins = xcl::import_binary_file(binaryFile);
    devices.resize(1);
    OCL_CHECK(err, cl::Program program (context, devices, bins, NULL, &err));
    OCL_CHECK(err, cl::Kernel krnl_oram(program, "oram", &err));
    OCL_CHECK(err, cl::Kernel krnl_shield_ram_r01(program, "krnl_shield_ram_r01", &err));
    OCL_CHECK(err, cl::Kernel krnl_shield_prng(program, "krnl_shield_prng", &err));
//	OCL_CHECK(err, cl::Kernel krnl_shield_input_i0(program, "krnl_shield_input_rtl_i0", &err));
	//OCL_CHECK(err, cl::Kernel krnl_shield_output_o0(program, "krnl_shield_output_rtl_o0", &err));
//	OCL_CHECK(err, cl::Kernel krnl_shield_output_o1(program, "krnl_shield_output_rtl_o1", &err));
//	OCL_CHECK(err, cl::Kernel krnl_shield_output_o2(program, "krnl_shield_output_rtl_o2", &err));
//	OCL_CHECK(err, cl::Kernel krnl_shield_output_o3(program, "krnl_shield_output_rtl_o3", &err));


    // Allocate Buffer in Global Memory
    // Buffers are allocated using CL_MEM_USE_HOST_PTR for efficient memory and
    // Device-to-host communication
    std::vector<cl::Memory> inBufVec, outBufVec;
    //std::vector<cl::Memory> inBufVec;
    std::cout << "Creating Buffers..." <<std::endl;
    OCL_CHECK(err, cl::Buffer buffer_server(context, CL_MEM_USE_HOST_PTR | CL_MEM_READ_WRITE,
    		server_size_bytes, source_server.data(), &err));
//    OCL_CHECK(err, cl::Buffer imageToDevice(context,CL_MEM_USE_HOST_PTR | CL_MEM_READ_ONLY,
//    			input_size_bytes, input_image.data(), &err));
	//OCL_CHECK(err, cl::Buffer image0FromDevice(context,CL_MEM_USE_HOST_PTR | CL_MEM_WRITE_ONLY,
		//	output_size_bytes, output_image0.data(), &err));
//	OCL_CHECK(err, cl::Buffer image1FromDevice(context,CL_MEM_USE_HOST_PTR | CL_MEM_WRITE_ONLY,
//				output_size_bytes, output_image1.data(), &err));
//	OCL_CHECK(err, cl::Buffer image2FromDevice(context,CL_MEM_USE_HOST_PTR | CL_MEM_WRITE_ONLY,
//				output_size_bytes, output_image2.data(), &err));
//	OCL_CHECK(err, cl::Buffer image3FromDevice(context,CL_MEM_USE_HOST_PTR | CL_MEM_WRITE_ONLY,
//				output_size_bytes, output_image3.data(), &err));
	OCL_CHECK(err, cl::Buffer dummyInput(context, CL_MEM_USE_HOST_PTR | CL_MEM_WRITE_ONLY,
			output_size_bytes, dummy.data(), &err));

    inBufVec.push_back(buffer_server);
    //inBufVec.push_back(imageToDevice);
	outBufVec.push_back(dummyInput);
//	outBufVec.push_back(image0FromDevice);
//	outBufVec.push_back(image1FromDevice);
//	outBufVec.push_back(image2FromDevice);
//	outBufVec.push_back(image3FromDevice);
//    inBufVec.push_back(buffer_input_b);

    //Start the timer
    gettimeofday(&start, 0);


    //Set the Kernel Arguments
//	int size = data_size;
//	int inc = INCR_VALUE;
   // OCL_CHECK(err, err = krnl_oram.setArg(0, buffer_server));
//	OCL_CHECK(err, err = krnl_shield_input_i0.setArg(0, imageToDevice));
//	OCL_CHECK(err, err = krnl_shield_input_i0.setArg(1, input_size));
//	OCL_CHECK(err, err = krnl_shield_input_i0.setArg(2, chunk_size));
	OCL_CHECK(err, err = krnl_shield_ram_r01.setArg(0, buffer_server));
	OCL_CHECK(err, err = krnl_oram.setArg(0, dummyInput));
	OCL_CHECK(err, err = krnl_oram.setArg(1, 512));
//	OCL_CHECK(err, err = krnl_shield_output_o0.setArg(0, image0FromDevice));
//	OCL_CHECK(err, err = krnl_shield_output_o0.setArg(1, output_size));
//	OCL_CHECK(err, err = krnl_shield_output_o1.setArg(0, image1FromDevice));
//	OCL_CHECK(err, err = krnl_shield_output_o1.setArg(1, output_size));
//	OCL_CHECK(err, err = krnl_shield_output_o2.setArg(0, image2FromDevice));
//	OCL_CHECK(err, err = krnl_shield_output_o2.setArg(1, output_size));
//	OCL_CHECK(err, err = krnl_shield_output_o3.setArg(0, image3FromDevice));
//	OCL_CHECK(err, err = krnl_shield_output_o3.setArg(1, output_size));



    // Copy input data to device global memory
    std::cout << "Copying data..." << std::endl;
    cl::Event write_event;
    cl::Event input_event, oram_event, ram_event, prng_event, o0_event, o1_event, o2_event, o3_event;
//    cl::Event event;
    OCL_CHECK(err, err = q.enqueueMigrateMemObjects(inBufVec, 0/*0 means from host*/, NULL, &write_event));

    cl_int event_info;

    OCL_CHECK(err, err = q.finish());

    // Launch the Kernel
    std::cout << "Launching Kernel..." << std::endl;
    gettimeofday(&start_exec, 0);
    //OCL_CHECK(err, err = q.enqueueTask(krnl_shield_input_i0, NULL, &input_event));
    OCL_CHECK(err, err = q.enqueueTask(krnl_shield_ram_r01, NULL, &ram_event));
    OCL_CHECK(err, err = q.enqueueTask(krnl_oram, NULL, &oram_event));
    OCL_CHECK(err, err = q.enqueueTask(krnl_shield_prng, NULL, &prng_event));
	//OCL_CHECK(err, err = q.enqueueTask(krnl_shield_output_o0, NULL, &o0_event));
//	OCL_CHECK(err, err = q.enqueueTask(krnl_shield_output_o1, NULL, &o1_event));
//	OCL_CHECK(err, err = q.enqueueTask(krnl_shield_output_o2, NULL, &o2_event));
//	OCL_CHECK(err, err = q.enqueueTask(krnl_shield_output_o3, NULL, &o3_event));
	std::cout << "Launched Kernel..." << std::endl;


//	while(1){
//		cl_int status;
//		input_event.getInfo(CL_EVENT_COMMAND_EXECUTION_STATUS, &status);
//		if(status != CL_RUNNING)
//			printf("Input: %d\n", status);
//		oram_event.getInfo(CL_EVENT_COMMAND_EXECUTION_STATUS, &status);
//		if(status != CL_RUNNING)
//		printf("Oram: %d\n", status);
//		ram_event.getInfo(CL_EVENT_COMMAND_EXECUTION_STATUS, &status);
//		if(status != CL_RUNNING)
//		printf("Ram: %d\n", status);
//		prng_event.getInfo(CL_EVENT_COMMAND_EXECUTION_STATUS, &status);
//		if(status != CL_RUNNING)
//		printf("PRNG: %d\n", status);
//		o0_event.getInfo(CL_EVENT_COMMAND_EXECUTION_STATUS, &status);
//		if(status != CL_RUNNING)
//		printf("Output0: %d\n", status);
//		o1_event.getInfo(CL_EVENT_COMMAND_EXECUTION_STATUS, &status);
//		if(status != CL_RUNNING)
//		printf("Output1: %d\n", status);
//		o2_event.getInfo(CL_EVENT_COMMAND_EXECUTION_STATUS, &status);
//		if(status != CL_RUNNING)
//		printf("Output2: %d\n", status);
//		o3_event.getInfo(CL_EVENT_COMMAND_EXECUTION_STATUS, &status);
//		if(status != CL_RUNNING)
//		printf("Output3: %d\n", status);
//
//	}


    //wait for all kernels to finish their operations
    OCL_CHECK(err, err = q.finish());
    gettimeofday(&end_exec, 0);

    //Copy Result from Device Global Memory to Host Local Memory
    std::cout << "Getting Results..." << std::endl;
    OCL_CHECK(err, err = q.enqueueMigrateMemObjects(outBufVec, CL_MIGRATE_MEM_OBJECT_HOST));
    OCL_CHECK(err, err = q.finish());
//OPENCL HOST CODE AREA END
    
    //Stop the timer
    gettimeofday(&end, 0);



    long long elapsed = (end.tv_sec - start.tv_sec) * 1000000LL + end.tv_usec - start.tv_usec;
    printf("Elapsed time: %lld us\n", elapsed);
	long long elapsed_exec = (end_exec.tv_sec - start_exec.tv_sec) * 1000000LL + end_exec.tv_usec - start_exec.tv_usec;
	printf("Elapsed time HW exec: %lld us\n", elapsed_exec);
	//printf("%d", dummy[0]);
   // for(int i = 0; i < output_size/4; i++){
   // 	printf("%08x\n",dummy[i]);
   // }

    //printf("Success? %d %d\n", source_hw_results[0], source_hw_results[1]);


    return 0;
}
