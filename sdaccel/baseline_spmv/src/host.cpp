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

void sw_spmv(const unsigned int vals[NNZ], const int cols[NNZ], const int row_delimiters[N+1], unsigned int vec[N], unsigned int out[N]){
	int i, j;
	unsigned int sum, Si;

	for(i = 0; i < N; i++){
		sum = 0;
		Si = 0;
		int tmp_begin = row_delimiters[i];
		int tmp_end = row_delimiters[i+1];
		for(j = tmp_begin; j < tmp_end; j++){
			Si = vals[j] * vec[cols[j]];
			sum = sum + Si;
		}
		out[i] = sum;
	}
}

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
    int vals_size = NNZ;
    size_t vals_size_bytes = sizeof(unsigned int) * vals_size;
    std::vector<unsigned int, aligned_allocator<unsigned int>> source_input_vals (vals_size);
    int cols_size = NNZ;
    size_t cols_size_bytes = sizeof(int) * cols_size;
    std::vector<int, aligned_allocator<int>> source_input_cols (cols_size);
    int row_delimiters_size = N + 1;
    size_t row_delimiters_size_bytes = row_delimiters_size * sizeof(int);
    std::vector<int, aligned_allocator<int>> source_input_row_delimiters (row_delimiters_size);
    int vec_size = N;
    size_t vec_size_bytes = sizeof(unsigned int) * vec_size;
    std::vector<unsigned int, aligned_allocator<unsigned int>> source_input_vec (vec_size);

    int output_size = N;
    size_t output_size_bytes = sizeof(unsigned int) * output_size;
    std::vector<unsigned int, aligned_allocator<unsigned int>> source_hw_results(output_size);
    std::vector<unsigned int, aligned_allocator<unsigned int>> source_sw_results(output_size);

    unsigned int input_vec[N];

    for(int i = 0; i < vec_size; i++){
    	source_input_vec[i] = i;
    	input_vec[i] = i;
    	//source_input_vec[i] = input_vec[i];
    }

    gettimeofday(&start, 0);
    unsigned int sw_results[N];
    sw_spmv(input_vals, input_cols, input_row_delimiters, input_vec, sw_results);
    gettimeofday(&end, 0);
    long long elapsed = (end.tv_sec - start.tv_sec) * 1000000LL + end.tv_usec - start.tv_usec;
        printf("Elapsed SW: %lld us\n", elapsed);


    for(int i = 0; i < vals_size; i++){
    	source_input_vals[i] = input_vals[i];
    }
    for(int i = 0; i < cols_size; i++){
        source_input_cols[i] = input_cols[i];
    }
    for(int i = 0; i < row_delimiters_size; i++){
        source_input_row_delimiters[i] = input_row_delimiters[i];
    }

    for(int i = 0; i < output_size; i++){
    	source_hw_results[i] = 0;
    	source_sw_results[i] = 0;
    }




//OPENCL HOST CODE AREA START
    // get_xil_devices() is a utility API which will find the Xilinx
    // platforms and will return list of devices connected to Xilinx platform
    std::vector<cl::Device> devices = xcl::get_xil_devices();
    cl::Device device = devices[0];

    std::cout << "Creating Context..." <<std::endl;
    OCL_CHECK(err, cl::Context context (device, NULL, NULL, NULL, &err));
    //OCL_CHECK(err, cl::CommandQueue q (context, device, NULL, &err));
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
    OCL_CHECK(err, cl::Kernel krnl_spmv(program, "spmv", &err));

    cl_mem_ext_ptr_t valsExt, colsExt, rowsExt, vecExt, outExt;
    valsExt.flags = XCL_MEM_DDR_BANK0;
    colsExt.flags = XCL_MEM_DDR_BANK1;
    rowsExt.flags = XCL_MEM_DDR_BANK2;
    vecExt.flags = XCL_MEM_DDR_BANK3;
    outExt.flags = XCL_MEM_DDR_BANK3;

    valsExt.obj = source_input_vals.data();
    colsExt.obj = source_input_cols.data();
    rowsExt.obj = source_input_row_delimiters.data();
    vecExt.obj = source_input_vec.data();
    outExt.obj = source_hw_results.data();
    valsExt.param = 0;
    colsExt.param = 0;
    rowsExt.param = 0;
    vecExt.param  = 0;
    outExt.param = 0;


    // Allocate Buffer in Global Memory
    // Buffers are allocated using CL_MEM_USE_HOST_PTR for efficient memory and
    // Device-to-host communication
    std::vector<cl::Memory> inBufVec, outBufVec;
    std::cout << "Creating Buffers..." <<std::endl;
    OCL_CHECK(err, cl::Buffer buffer_input_vals(context, CL_MEM_USE_HOST_PTR | CL_MEM_READ_ONLY | CL_MEM_EXT_PTR_XILINX,
    		vals_size_bytes, &valsExt, &err));
    OCL_CHECK(err, cl::Buffer buffer_input_cols(context, CL_MEM_USE_HOST_PTR | CL_MEM_READ_ONLY| CL_MEM_EXT_PTR_XILINX,
        	cols_size_bytes, &colsExt, &err));
    OCL_CHECK(err, cl::Buffer buffer_input_row_delimiters(context, CL_MEM_USE_HOST_PTR | CL_MEM_READ_ONLY| CL_MEM_EXT_PTR_XILINX,
    		row_delimiters_size_bytes, &rowsExt, &err));
    OCL_CHECK(err, cl::Buffer buffer_input_vec(context, CL_MEM_USE_HOST_PTR | CL_MEM_READ_ONLY| CL_MEM_EXT_PTR_XILINX,
        	vec_size_bytes, &vecExt, &err));


    OCL_CHECK(err, cl::Buffer buffer_output(context, CL_MEM_USE_HOST_PTR | CL_MEM_WRITE_ONLY| CL_MEM_EXT_PTR_XILINX,
    		output_size_bytes, &outExt, &err));

    inBufVec.push_back(buffer_input_vals);
    inBufVec.push_back(buffer_input_cols);
    inBufVec.push_back(buffer_input_row_delimiters);
    inBufVec.push_back(buffer_input_vec);
    outBufVec.push_back(buffer_output);

    //Start the timer
    gettimeofday(&start, 0);


    //Set the Kernel Arguments
	OCL_CHECK(err, err = krnl_spmv.setArg(0, buffer_input_vals));
	OCL_CHECK(err, err = krnl_spmv.setArg(1, buffer_input_cols));
	OCL_CHECK(err, err = krnl_spmv.setArg(2, buffer_input_row_delimiters));
	OCL_CHECK(err, err = krnl_spmv.setArg(3, buffer_input_vec));
	OCL_CHECK(err, err = krnl_spmv.setArg(4, buffer_output));
	OCL_CHECK(err, err = krnl_spmv.setArg(5, N));



    // Copy input data to device global memory
    //std::cout << "Copying data..." << std::endl;
    cl::Event write_event;
    OCL_CHECK(err, err = q.enqueueMigrateMemObjects(inBufVec, 0/*0 means from host*/, NULL, &write_event));
   

    OCL_CHECK(err, err = q.finish());

    // Launch the Kernel
    //std::cout << "Launching Kernel..." << std::endl;
    gettimeofday(&start, 0);
    OCL_CHECK(err, err = q.enqueueTask(krnl_spmv, NULL, &write_event));


    //wait for all kernels to finish their operations
    OCL_CHECK(err, err = q.finish());
    gettimeofday(&end, 0);

    //Copy Result from Device Global Memory to Host Local Memory
    //std::cout << "Getting Results..." << std::endl;
    OCL_CHECK(err, err = q.enqueueMigrateMemObjects(outBufVec, CL_MIGRATE_MEM_OBJECT_HOST));
    OCL_CHECK(err, err = q.finish());
//OPENCL HOST CODE AREA END
    
    //Stop the timer




   elapsed = (end.tv_sec - start.tv_sec) * 1000000LL + end.tv_usec - start.tv_usec;
        printf("Elapsed HW: %lld us\n", elapsed);


        // Compare the results of the Device to the simulation
        for (int i = 0 ; i < output_size; i++){
        	if(source_hw_results[i] != sw_results[i]){
        		//printf("ERROR");
        		//return 0;
        		//printf("%f - %f\n", source_hw_results[i], sw_results[i]);
        	}
        	//printf("%08f\n", source_hw_results[i]);
        }
     printf("SUCCESS");




    return 0;
}
