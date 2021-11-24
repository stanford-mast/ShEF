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

int main(int argc, char** argv)
{
    //int data_size = 0x412; //This should be how many lines are in the encrypted .dat file
		int data_size = 2519694;
    int chunk_size = 0x200;
    int pt_size = 2500000+3; //This should be how many words are expected in the output file, minus the tag (In other words, PT + IV)
    int tag_size = 4;
    cl_int err;

    struct timeval start, end;

    // Reducing the data size for emulation mode
//    char *xcl_mode = getenv("XCL_EMULATION_MODE");
//    if (xcl_mode != NULL){
//        data_size = 1024;
//    }

    //Allocate Memory in Host Memory
    size_t vector_size_bytes = sizeof(unsigned int) * data_size;
    std::vector<unsigned int,aligned_allocator<unsigned int>> source_input_a0    (data_size);
    std::vector<unsigned int,aligned_allocator<unsigned int>> source_input_b0    (data_size);
    std::vector<unsigned int,aligned_allocator<unsigned int>> source_input_a1    (data_size);
    std::vector<unsigned int,aligned_allocator<unsigned int>> source_input_b1    (data_size);
    std::vector<unsigned int,aligned_allocator<unsigned int>> source_input_a2    (data_size);
    std::vector<unsigned int,aligned_allocator<unsigned int>> source_input_b2    (data_size);
    std::vector<unsigned int,aligned_allocator<unsigned int>> source_input_a3    (data_size);
    std::vector<unsigned int,aligned_allocator<unsigned int>> source_input_b3    (data_size);

    std::vector<unsigned int,aligned_allocator<unsigned int>> source_hw_results0(data_size);
    std::vector<unsigned int,aligned_allocator<unsigned int>> source_hw_results1(data_size);
    std::vector<unsigned int,aligned_allocator<unsigned int>> source_hw_results2(data_size);
    std::vector<unsigned int,aligned_allocator<unsigned int>> source_hw_results3(data_size);

    // Create the test data and Software Result 
    for(size_t i = 0 ; i < data_size; i++){
        source_input_a0[i] = input_a[i];
        source_input_b0[i] = input_b[i];
        source_input_a1[i] = input_a[i];
        source_input_b1[i] = input_b[i];
        source_input_a2[i] = input_a[i];
        source_input_b2[i] = input_b[i];
        source_input_a3[i] = input_a[i];
        source_input_b3[i] = input_b[i];
        source_hw_results0[i] = 0;
        source_hw_results1[i] = 0;
        source_hw_results2[i] = 0;
        source_hw_results3[i] = 0;
    }

//OPENCL HOST CODE AREA START
    // get_xil_devices() is a utility API which will find the Xilinx
    // platforms and will return list of devices connected to Xilinx platform
    std::vector<cl::Device> devices = xcl::get_xil_devices();
    cl::Device device = devices[0];

    std::cout << "Creating Context..." <<std::endl;
    OCL_CHECK(err, cl::Context context (device, NULL, NULL, NULL, &err));
    //OCL_CHECK(err, cl::CommandQueue q (context, device, NULL, &err));
    OCL_CHECK(err, cl::CommandQueue q (context, device, CL_QUEUE_OUT_OF_ORDER_EXEC_MODE_ENABLE | CL_QUEUE_PROFILING_ENABLE, &err));
    OCL_CHECK(err, std::string device_name = device.getInfo<CL_DEVICE_NAME>(&err));

    // find_binary_file() is a utility API which will search the xclbin file for
    // targeted mode (sw_emu/hw_emu/hw) and for targeted platforms.
    std::string binaryFile = xcl::find_binary_file(device_name, "binary");

    // import_binary_file() ia a utility API which will load the binaryFile
    // and will return Binaries.
    cl::Program::Binaries bins = xcl::import_binary_file(binaryFile);
    devices.resize(1);
    OCL_CHECK(err, cl::Program program (context, devices, bins, NULL, &err));
    OCL_CHECK(err, cl::Kernel krnl_vvadd_stage(program, "vvadd", &err));
    OCL_CHECK(err, cl::Kernel krnl_shield_input_i0(program, "krnl_shield_input_rtl_i0", &err));
    OCL_CHECK(err, cl::Kernel krnl_shield_input_i1(program, "krnl_shield_input_rtl_i1", &err));
    OCL_CHECK(err, cl::Kernel krnl_shield_input_i2(program, "krnl_shield_input_rtl_i2", &err));
    OCL_CHECK(err, cl::Kernel krnl_shield_input_i3(program, "krnl_shield_input_rtl_i3", &err));
    OCL_CHECK(err, cl::Kernel krnl_shield_input_i4(program, "krnl_shield_input_rtl_i4", &err));
    OCL_CHECK(err, cl::Kernel krnl_shield_input_i5(program, "krnl_shield_input_rtl_i5", &err));
    OCL_CHECK(err, cl::Kernel krnl_shield_input_i6(program, "krnl_shield_input_rtl_i6", &err));
    OCL_CHECK(err, cl::Kernel krnl_shield_input_i7(program, "krnl_shield_input_rtl_i7", &err));
    OCL_CHECK(err, cl::Kernel krnl_shield_output_o0(program, "krnl_shield_output_rtl_o0", &err));
    OCL_CHECK(err, cl::Kernel krnl_shield_output_o1(program, "krnl_shield_output_rtl_o1", &err));
    OCL_CHECK(err, cl::Kernel krnl_shield_output_o2(program, "krnl_shield_output_rtl_o2", &err));
    OCL_CHECK(err, cl::Kernel krnl_shield_output_o3(program, "krnl_shield_output_rtl_o3", &err));

    // Allocate Buffer in Global Memory
    // Buffers are allocated using CL_MEM_USE_HOST_PTR for efficient memory and
    // Device-to-host communication
    std::vector<cl::Memory> inBufVec, outBufVec;
    std::cout << "Creating Buffers..." <<std::endl;
    OCL_CHECK(err, cl::Buffer buffer_input_a0(context, CL_MEM_USE_HOST_PTR | CL_MEM_READ_ONLY,
    		vector_size_bytes, source_input_a0.data(), &err));
    OCL_CHECK(err, cl::Buffer buffer_input_b0(context, CL_MEM_USE_HOST_PTR | CL_MEM_READ_ONLY,
        		vector_size_bytes, source_input_b0.data(), &err));
    OCL_CHECK(err, cl::Buffer buffer_input_a1(context, CL_MEM_USE_HOST_PTR | CL_MEM_READ_ONLY,
    		vector_size_bytes, source_input_a1.data(), &err));
    OCL_CHECK(err, cl::Buffer buffer_input_b1(context, CL_MEM_USE_HOST_PTR | CL_MEM_READ_ONLY,
        		vector_size_bytes, source_input_b1.data(), &err));
    OCL_CHECK(err, cl::Buffer buffer_input_a2(context, CL_MEM_USE_HOST_PTR | CL_MEM_READ_ONLY,
    		vector_size_bytes, source_input_a2.data(), &err));
    OCL_CHECK(err, cl::Buffer buffer_input_b2(context, CL_MEM_USE_HOST_PTR | CL_MEM_READ_ONLY,
        		vector_size_bytes, source_input_b2.data(), &err));
    OCL_CHECK(err, cl::Buffer buffer_input_a3(context, CL_MEM_USE_HOST_PTR | CL_MEM_READ_ONLY,
    		vector_size_bytes, source_input_a3.data(), &err));
    OCL_CHECK(err, cl::Buffer buffer_input_b3(context, CL_MEM_USE_HOST_PTR | CL_MEM_READ_ONLY,
        		vector_size_bytes, source_input_b3.data(), &err));
    OCL_CHECK(err, cl::Buffer buffer_output0(context, CL_MEM_USE_HOST_PTR | CL_MEM_WRITE_ONLY,
    		vector_size_bytes, source_hw_results0.data(), &err));
    OCL_CHECK(err, cl::Buffer buffer_output1(context, CL_MEM_USE_HOST_PTR | CL_MEM_WRITE_ONLY,
    		vector_size_bytes, source_hw_results1.data(), &err));
    OCL_CHECK(err, cl::Buffer buffer_output2(context, CL_MEM_USE_HOST_PTR | CL_MEM_WRITE_ONLY,
    		vector_size_bytes, source_hw_results2.data(), &err));
    OCL_CHECK(err, cl::Buffer buffer_output3(context, CL_MEM_USE_HOST_PTR | CL_MEM_WRITE_ONLY,
    		vector_size_bytes, source_hw_results3.data(), &err));
    inBufVec.push_back(buffer_input_a0);
    inBufVec.push_back(buffer_input_b0);
    inBufVec.push_back(buffer_input_a1);
    inBufVec.push_back(buffer_input_b1);
    inBufVec.push_back(buffer_input_a2);
    inBufVec.push_back(buffer_input_b2);
    inBufVec.push_back(buffer_input_a3);
    inBufVec.push_back(buffer_input_b3);
    outBufVec.push_back(buffer_output0);
    outBufVec.push_back(buffer_output1);
    outBufVec.push_back(buffer_output2);
    outBufVec.push_back(buffer_output3);

    //Start the timer
    gettimeofday(&start, 0);


    //Set the Kernel Arguments
	int size = data_size;
	int inc = INCR_VALUE;
	OCL_CHECK(err, err = krnl_shield_input_i0.setArg(0, buffer_input_a0));
	OCL_CHECK(err, err = krnl_shield_input_i0.setArg(1, size));
	OCL_CHECK(err, err = krnl_shield_input_i0.setArg(2, chunk_size));
	OCL_CHECK(err, err = krnl_shield_input_i1.setArg(0, buffer_input_b0));
	OCL_CHECK(err, err = krnl_shield_input_i1.setArg(1, size));
	OCL_CHECK(err, err = krnl_shield_input_i1.setArg(2, chunk_size));
	OCL_CHECK(err, err = krnl_shield_input_i2.setArg(0, buffer_input_a1));
	OCL_CHECK(err, err = krnl_shield_input_i2.setArg(1, size));
	OCL_CHECK(err, err = krnl_shield_input_i2.setArg(2, chunk_size));
	OCL_CHECK(err, err = krnl_shield_input_i3.setArg(0, buffer_input_b1));
	OCL_CHECK(err, err = krnl_shield_input_i3.setArg(1, size));
	OCL_CHECK(err, err = krnl_shield_input_i3.setArg(2, chunk_size));
	OCL_CHECK(err, err = krnl_shield_input_i4.setArg(0, buffer_input_a2));
	OCL_CHECK(err, err = krnl_shield_input_i4.setArg(1, size));
	OCL_CHECK(err, err = krnl_shield_input_i4.setArg(2, chunk_size));
	OCL_CHECK(err, err = krnl_shield_input_i5.setArg(0, buffer_input_b2));
	OCL_CHECK(err, err = krnl_shield_input_i5.setArg(1, size));
	OCL_CHECK(err, err = krnl_shield_input_i5.setArg(2, chunk_size));
	OCL_CHECK(err, err = krnl_shield_input_i6.setArg(0, buffer_input_a3));
	OCL_CHECK(err, err = krnl_shield_input_i6.setArg(1, size));
	OCL_CHECK(err, err = krnl_shield_input_i6.setArg(2, chunk_size));
	OCL_CHECK(err, err = krnl_shield_input_i7.setArg(0, buffer_input_b3));
	OCL_CHECK(err, err = krnl_shield_input_i7.setArg(1, size));
	OCL_CHECK(err, err = krnl_shield_input_i7.setArg(2, chunk_size));
	OCL_CHECK(err, err = krnl_vvadd_stage.setArg(0, pt_size));
	OCL_CHECK(err, err = krnl_shield_output_o0.setArg(0, buffer_output0));
	OCL_CHECK(err, err = krnl_shield_output_o0.setArg(1, pt_size + tag_size));
	OCL_CHECK(err, err = krnl_shield_output_o1.setArg(0, buffer_output1));
	OCL_CHECK(err, err = krnl_shield_output_o1.setArg(1, pt_size + tag_size));
	OCL_CHECK(err, err = krnl_shield_output_o2.setArg(0, buffer_output2));
	OCL_CHECK(err, err = krnl_shield_output_o2.setArg(1, pt_size + tag_size));
	OCL_CHECK(err, err = krnl_shield_output_o3.setArg(0, buffer_output3));
	OCL_CHECK(err, err = krnl_shield_output_o3.setArg(1, pt_size + tag_size));



    // Copy input data to device global memory
    std::cout << "Copying data..." << std::endl;
    cl::Event write_event;
    OCL_CHECK(err, err = q.enqueueMigrateMemObjects(inBufVec, 0/*0 means from host*/, NULL, &write_event));
   

    OCL_CHECK(err, err = q.finish());

    // Launch the Kernel
    std::cout << "Launching Kernel..." << std::endl;
    OCL_CHECK(err, err = q.enqueueTask(krnl_shield_input_i0, NULL, &write_event));
    OCL_CHECK(err, err = q.enqueueTask(krnl_shield_input_i1, NULL, &write_event));
    OCL_CHECK(err, err = q.enqueueTask(krnl_shield_input_i2, NULL, &write_event));
    OCL_CHECK(err, err = q.enqueueTask(krnl_shield_input_i3, NULL, &write_event));
    OCL_CHECK(err, err = q.enqueueTask(krnl_shield_input_i4, NULL, &write_event));
    OCL_CHECK(err, err = q.enqueueTask(krnl_shield_input_i5, NULL, &write_event));
    OCL_CHECK(err, err = q.enqueueTask(krnl_shield_input_i6, NULL, &write_event));
    OCL_CHECK(err, err = q.enqueueTask(krnl_shield_input_i7, NULL, &write_event));
    OCL_CHECK(err, err = q.enqueueTask(krnl_vvadd_stage, NULL, &write_event));
    OCL_CHECK(err, err = q.enqueueTask(krnl_shield_output_o0, NULL, &write_event));
    OCL_CHECK(err, err = q.enqueueTask(krnl_shield_output_o1, NULL, &write_event));
    OCL_CHECK(err, err = q.enqueueTask(krnl_shield_output_o2, NULL, &write_event));
    OCL_CHECK(err, err = q.enqueueTask(krnl_shield_output_o3, NULL, &write_event));

    //wait for all kernels to finish their operations
    OCL_CHECK(err, err = q.finish());

    //Copy Result from Device Global Memory to Host Local Memory
    std::cout << "Getting Results..." << std::endl;
    OCL_CHECK(err, err = q.enqueueMigrateMemObjects(outBufVec, CL_MIGRATE_MEM_OBJECT_HOST));
    OCL_CHECK(err, err = q.finish());
//OPENCL HOST CODE AREA END
    
    //Stop the timer
    gettimeofday(&end, 0);

    // Compare the results of the Device to the simulation
    bool match = true;

    long long elapsed = (end.tv_sec - start.tv_sec) * 1000000LL + end.tv_usec - start.tv_usec;
    printf("Elapsed time: %lld us\n", elapsed);


    return 0;
}
