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


int main(int argc, char** argv)
{
    cl_int err;

    // Reducing the data size for emulation mode
//    char *xcl_mode = getenv("XCL_EMULATION_MODE");
//    if (xcl_mode != NULL){
//        data_size = 1024;
//    }
    struct timeval start, end;

    //Allocate Memory in Host Memory
    size_t server_size =  127 * 4 * 66;
//    size_t vector_size_bytes = sizeof(unsigned int) * data_size;
//    std::vector<unsigned int,aligned_allocator<unsigned int>> source_input_a     (data_size);
//    std::vector<unsigned int,aligned_allocator<unsigned int>> source_input_b     (data_size);
    std::vector<unsigned char, aligned_allocator<unsigned char>> source_server (server_size);
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
    for(size_t i = 0; i < server_size; i++){
    	source_server[i] = 0;
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


    // Allocate Buffer in Global Memory
    // Buffers are allocated using CL_MEM_USE_HOST_PTR for efficient memory and
    // Device-to-host communication
//    std::vector<cl::Memory> inBufVec, outBufVec;
    std::vector<cl::Memory> inBufVec;
    std::cout << "Creating Buffers..." <<std::endl;
    OCL_CHECK(err, cl::Buffer buffer_server(context, CL_MEM_USE_HOST_PTR | CL_MEM_READ_WRITE,
    		server_size, source_server.data(), &err));
//    OCL_CHECK(err, cl::Buffer buffer_input_a(context, CL_MEM_USE_HOST_PTR | CL_MEM_READ_ONLY,
//    		vector_size_bytes, source_input_a.data(), &err));
//    OCL_CHECK(err, cl::Buffer buffer_input_b(context, CL_MEM_USE_HOST_PTR | CL_MEM_READ_ONLY,
//        		vector_size_bytes, source_input_b.data(), &err));
//    OCL_CHECK(err, cl::Buffer buffer_output(context, CL_MEM_USE_HOST_PTR | CL_MEM_WRITE_ONLY,
//    		vector_size_bytes, source_hw_results.data(), &err));
//
    inBufVec.push_back(buffer_server);
//    inBufVec.push_back(buffer_input_b);
//    outBufVec.push_back(buffer_output);

    //Start the timer
    gettimeofday(&start, 0);


    //Set the Kernel Arguments
//	int size = data_size;
//	int inc = INCR_VALUE;
    OCL_CHECK(err, err = krnl_oram.setArg(0, buffer_server));
	OCL_CHECK(err, err = krnl_oram.setArg(1, 512));
//	OCL_CHECK(err, err = krnl_vvadd_stage.setArg(1, buffer_input_b));
//	OCL_CHECK(err, err = krnl_vvadd_stage.setArg(2, buffer_output));
//	OCL_CHECK(err, err = krnl_vvadd_stage.setArg(3, data_size));




    // Copy input data to device global memory
    std::cout << "Copying data..." << std::endl;
    cl::Event write_event;
//    cl::Event event;
    OCL_CHECK(err, err = q.enqueueMigrateMemObjects(inBufVec, 0/*0 means from host*/, NULL, &write_event));
   

    OCL_CHECK(err, err = q.finish());

    // Launch the Kernel
    std::cout << "Launching Kernel..." << std::endl;
    OCL_CHECK(err, err = q.enqueueTask(krnl_oram, NULL, &write_event));

    //wait for all kernels to finish their operations
    OCL_CHECK(err, err = q.finish());

    //Copy Result from Device Global Memory to Host Local Memory
    std::cout << "Getting Results..." << std::endl;
    OCL_CHECK(err, err = q.enqueueMigrateMemObjects(inBufVec, CL_MIGRATE_MEM_OBJECT_HOST));
    OCL_CHECK(err, err = q.finish());
//OPENCL HOST CODE AREA END
    
    //Stop the timer
    gettimeofday(&end, 0);

    // Compare the results of the Device to the simulation
//    bool match = true;
//    for (int i = 0 ; i < data_size; i++){
//    	printf("0x%08x\n", source_hw_results[i]);
//        //std::cout << "0x" << std::setfill('0') << std::setw(8) << std::hex<< source_hw_results[i] << std::endl;
//        //if (source_hw_results[i] != source_sw_results[i]){
//            //std::cout << "Error: Result mismatch" << std::endl;
//            //match = false;
//            //break;
//        //}
//    }

    long long elapsed = (end.tv_sec - start.tv_sec) * 1000000LL + end.tv_usec - start.tv_usec;
    printf("Elapsed time: %lld us\n", elapsed);

    printf("Success? %d %d\n", source_server[0], source_server[1]);


    return 0;
}
