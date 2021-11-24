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
Description: 

    This is a CNN (Convolutional Neural Network) convolutional layer based
    example to showcase the effectiveness of using multiple compute units when
    the base algorithm consists of multiple nested loops with large loop count.    

*******************************************************************************/

#include <iostream>
#include <cstring>
#include <cstdio>
#include <cassert>
#include <unistd.h>
#include <time.h>
#include <sys/time.h>

//OpenCL utility layer include
#include "xcl2.hpp"
#include "defns.h"
#include "image_data.h"

#define WORK_GROUP 4 
#define WORK_ITEM_PER_GROUP 1

#define DATA_SIZE OChan * OSize * OSize

uint64_t get_duration_ns (const cl::Event &event) {
    uint64_t nstimestart, nstimeend;
    event.getProfilingInfo<uint64_t>(CL_PROFILING_COMMAND_START,&nstimestart);
    event.getProfilingInfo<uint64_t>(CL_PROFILING_COMMAND_END,&nstimeend);
    return(nstimeend-nstimestart);
}

// Software solution
void convGolden(int *weight, int *image, int *out, int i_chan, int o_chan)
{
    // Runs over output filters
    for(int output = 0; output < o_chan; output++){
        // Runs over output pixel in Y-direction
        for(int y = 0; y < OSize; y++){
            // Runs over output pixel in X-direction
            for(int x = 0; x < OSize; x++){
                short acc = 0;
                // Runs over each input channel of input feature map
                for(int input = 0; input < i_chan; input++){
                    // Runs over filter window 
                    for(int i = 0; i < WSize; i++){
                        // Runs over filter windows 
                        for(int j = 0; j < WSize; j++){

                            // Calculate input padding boundaries
                            int xVal = x*Stride + j-Padding, yVal = y*Stride + i-Padding;

                            // Convolution operation
                            if(yVal >= 0 && yVal < ISize && xVal >= 0 && xVal < ISize){
                                acc += (short) image[(input*ISize + yVal)*ISize + xVal] * 
                                       (short) weight[((output*WInChan + input)*WSize + i)*WSize + j];
                            }
                        }
                        // Update each output pixel / output filter
                        out[(output*OSize + y)*OSize + x] = acc;
                    }
                }
            }
        }
    }
}


void run_opencl_cnn(
    std::vector<cl::Device> &devices,
    cl::CommandQueue &q,
    cl::Context &context,
    std::string &device_name,
    bool good,
    int size,
    std::vector<unsigned int, aligned_allocator<unsigned int>> &weight,
    std::vector<unsigned int, aligned_allocator<unsigned int>> &image0,
	std::vector<unsigned int, aligned_allocator<unsigned int>> &image1,
	std::vector<unsigned int, aligned_allocator<unsigned int>> &image2,
	std::vector<unsigned int, aligned_allocator<unsigned int>> &image3,
    std::vector<unsigned int, aligned_allocator<unsigned int>> &output0,
	std::vector<unsigned int, aligned_allocator<unsigned int>> &output1,
	std::vector<unsigned int, aligned_allocator<unsigned int>> &output2,
	std::vector<unsigned int, aligned_allocator<unsigned int>> &output3,
    int i_chan,
    int o_chan
) {
    std::string binaryFile;

    struct timeval start, end;

    if (good) {
        binaryFile = xcl::find_binary_file(device_name, "binary");
    } 
    else {
        binaryFile = xcl::find_binary_file(device_name,"cnn_BAD");
        if(access(binaryFile.c_str(), R_OK) != 0) {
            std::cout << "WARNING: vadd_BAD xclbin not built" << std::endl;
            return;
        }
    }

    cl::Program::Binaries bins = xcl::import_binary_file(binaryFile);
    devices.resize(1);
    cl::Program program(context, devices, bins);
    cl::Kernel krnl_cnn_conv0(program,"cnn0");
    cl::Kernel krnl_cnn_conv1(program,"cnn1");
    cl::Kernel krnl_cnn_conv2(program,"cnn2");
    cl::Kernel krnl_cnn_conv3(program,"cnn3");
    cl::Kernel krnl_shield_input_c00(program, "krnl_shield_input_rtl_c00");
    cl::Kernel krnl_shield_input_c01(program, "krnl_shield_input_rtl_c01");
    cl::Kernel krnl_shield_output_c02(program, "krnl_shield_output_rtl_c02");
    cl::Kernel krnl_shield_input_c03(program, "krnl_shield_input_rtl_c03");
	cl::Kernel krnl_shield_input_c04(program, "krnl_shield_input_rtl_c04");
	cl::Kernel krnl_shield_output_c05(program, "krnl_shield_output_rtl_c05");
	cl::Kernel krnl_shield_input_c06(program, "krnl_shield_input_rtl_c06");
	cl::Kernel krnl_shield_input_c07(program, "krnl_shield_input_rtl_c07");
	cl::Kernel krnl_shield_output_c08(program, "krnl_shield_output_rtl_c08");
	cl::Kernel krnl_shield_input_c09(program, "krnl_shield_input_rtl_c09");
	cl::Kernel krnl_shield_input_c10(program, "krnl_shield_input_rtl_c10");
	cl::Kernel krnl_shield_output_c11(program, "krnl_shield_output_rtl_c11");

    std::cout << "Starting " << (good ? "GOOD" : "BAD") << " Kernel" << std::endl;
    cl::Event event;

    //size_t image_size_bytes  = sizeof(int) * i_chan * ISize * ISize;
    int image_size = 0x1138b;
    int weight_size = 0x972eb;
    int chunk_size = 0x200;
    int output_size = (o_chan * OSize * OSize) + 7;
    size_t image_size_bytes = image_size * sizeof(unsigned int);
    //size_t weight_size_bytes = sizeof(int) * o_chan * WInChan * WSize * WSize;
    size_t weight_size_bytes = weight_size * sizeof(unsigned int);
    //size_t output_size_bytes = sizeof(int) * o_chan * OSize * OSize;
    size_t output_size_bytes = sizeof(unsigned int) * output_size;

    // Allocate Buffer in Global Memory
    std::vector<cl::Memory> inBufVec, outBufVec;
    cl::Buffer buffer_image0 (context, CL_MEM_USE_HOST_PTR | CL_MEM_READ_ONLY,
                            image_size_bytes, image0.data());
    cl::Buffer buffer_image1 (context, CL_MEM_USE_HOST_PTR | CL_MEM_READ_ONLY,
                                image_size_bytes, image1.data());
    cl::Buffer buffer_image2 (context, CL_MEM_USE_HOST_PTR | CL_MEM_READ_ONLY,
                                image_size_bytes, image2.data());
    cl::Buffer buffer_image3 (context, CL_MEM_USE_HOST_PTR | CL_MEM_READ_ONLY,
                                image_size_bytes, image3.data());
    cl::Buffer buffer_weight(context, CL_MEM_USE_HOST_PTR | CL_MEM_READ_ONLY,
                            weight_size_bytes, weight.data());
    cl::Buffer buffer_output0(context, CL_MEM_USE_HOST_PTR | CL_MEM_WRITE_ONLY,
                                output_size_bytes, output0.data());
    cl::Buffer buffer_output1(context, CL_MEM_USE_HOST_PTR | CL_MEM_WRITE_ONLY,
                                    output_size_bytes, output1.data());
    cl::Buffer buffer_output2(context, CL_MEM_USE_HOST_PTR | CL_MEM_WRITE_ONLY,
                                    output_size_bytes, output2.data());
    cl::Buffer buffer_output3(context, CL_MEM_USE_HOST_PTR | CL_MEM_WRITE_ONLY,
                                    output_size_bytes, output3.data());

    inBufVec.push_back(buffer_image0);
    inBufVec.push_back(buffer_image1);
    inBufVec.push_back(buffer_image2);
    inBufVec.push_back(buffer_image3);
    inBufVec.push_back(buffer_weight);
    outBufVec.push_back(buffer_output0);
    outBufVec.push_back(buffer_output1);
    outBufVec.push_back(buffer_output2);
    outBufVec.push_back(buffer_output3);

    //Set the Kernel Arguments
    int narg = 0;

    //krnl_cnn_conv.setArg(narg++, buffer_image);
	krnl_shield_input_c00.setArg(0, buffer_image0);
	krnl_shield_input_c00.setArg(1, image_size);
	krnl_shield_input_c00.setArg(2, chunk_size);
	krnl_shield_input_c01.setArg(0, buffer_weight);
	krnl_shield_input_c01.setArg(1, weight_size);
	krnl_shield_input_c01.setArg(2, chunk_size);
	krnl_shield_output_c02.setArg(0, buffer_output0);
	krnl_shield_output_c02.setArg(1, output_size);
	krnl_shield_input_c03.setArg(0, buffer_image1);
	krnl_shield_input_c03.setArg(1, image_size);
	krnl_shield_input_c03.setArg(2, chunk_size);
	krnl_shield_input_c04.setArg(0, buffer_weight);
	krnl_shield_input_c04.setArg(1, weight_size);
	krnl_shield_input_c04.setArg(2, chunk_size);
	krnl_shield_output_c05.setArg(0, buffer_output1);
	krnl_shield_output_c05.setArg(1, output_size);
	krnl_shield_input_c06.setArg(0, buffer_image2);
	krnl_shield_input_c06.setArg(1, image_size);
	krnl_shield_input_c06.setArg(2, chunk_size);
	krnl_shield_input_c07.setArg(0, buffer_weight);
	krnl_shield_input_c07.setArg(1, weight_size);
	krnl_shield_input_c07.setArg(2, chunk_size);
	krnl_shield_output_c08.setArg(0, buffer_output2);
	krnl_shield_output_c08.setArg(1, output_size);
	krnl_shield_input_c09.setArg(0, buffer_image3);
	krnl_shield_input_c09.setArg(1, image_size);
	krnl_shield_input_c09.setArg(2, chunk_size);
	krnl_shield_input_c10.setArg(0, buffer_weight);
	krnl_shield_input_c10.setArg(1, weight_size);
	krnl_shield_input_c10.setArg(2, chunk_size);
	krnl_shield_output_c11.setArg(0, buffer_output3);
	krnl_shield_output_c11.setArg(1, output_size);


    //krnl_cnn_conv.setArg(narg++, buffer_weight);
    //krnl_cnn_conv.setArg(narg++, buffer_output);
    krnl_cnn_conv0.setArg(0, size);
    krnl_cnn_conv0.setArg(1, i_chan);
    krnl_cnn_conv0.setArg(2, o_chan);
    krnl_cnn_conv1.setArg(0, size);
    krnl_cnn_conv1.setArg(1, i_chan);
    krnl_cnn_conv1.setArg(2, o_chan);
    krnl_cnn_conv2.setArg(0, size);
    krnl_cnn_conv2.setArg(1, i_chan);
    krnl_cnn_conv2.setArg(2, o_chan);
    krnl_cnn_conv3.setArg(0, size);
    krnl_cnn_conv3.setArg(1, i_chan);
    krnl_cnn_conv3.setArg(2, o_chan);

    gettimeofday(&start, 0);

    q.enqueueMigrateMemObjects(inBufVec,0/* 0 means from host*/);


    //std::cout << "Begin " << (good ? "GOOD" : "BAD") << " Kernel" << std::endl;

    //uint64_t duration = 0;

//
////    if(good) {
//        int work_group = WORK_GROUP;
//        int work_item_per_group = WORK_ITEM_PER_GROUP;
//
//        //Set global & local grids
//        cl::NDRange global_size = work_group;
//        cl::NDRange local_size  = work_item_per_group;
//
//        //q.enqueueNDRangeKernel(krnl_cnn_conv, 0, global_size, local_size, NULL, &event);
//        q.finish();
//
//        duration = get_duration_ns(event);
//    }
//    else {
        q.enqueueTask(krnl_cnn_conv0, NULL, &event);
		q.enqueueTask(krnl_shield_input_c00, NULL, &event);
		q.enqueueTask(krnl_shield_input_c01, NULL, &event);
		q.enqueueTask(krnl_shield_output_c02, NULL, &event);
        q.enqueueTask(krnl_cnn_conv1, NULL, &event);
		q.enqueueTask(krnl_shield_input_c03, NULL, &event);
		q.enqueueTask(krnl_shield_input_c04, NULL, &event);
		q.enqueueTask(krnl_shield_output_c05, NULL, &event);
        q.enqueueTask(krnl_cnn_conv2, NULL, &event);
		q.enqueueTask(krnl_shield_input_c06, NULL, &event);
		q.enqueueTask(krnl_shield_input_c07, NULL, &event);
		q.enqueueTask(krnl_shield_output_c08, NULL, &event);
        q.enqueueTask(krnl_cnn_conv3, NULL, &event);
		q.enqueueTask(krnl_shield_input_c09, NULL, &event);
		q.enqueueTask(krnl_shield_input_c10, NULL, &event);
		q.enqueueTask(krnl_shield_output_c11, NULL, &event);
        q.finish();

//
        //duration = get_duration_ns(event);
//    }

    //Copy Result from Device Global Memory to Host Local Memory
    q.enqueueMigrateMemObjects(outBufVec,CL_MIGRATE_MEM_OBJECT_HOST);
    q.finish();

    gettimeofday(&end, 0);
    long long elapsed = (end.tv_sec - start.tv_sec) * 1000000LL + end.tv_usec - start.tv_usec;
    printf("elapsed time: %lld us\n", elapsed);



    //std::cout << "Finished " << (good ? "GOOD" : "BAD") << " Kernel" << std::endl;
    //return duration;
    return;
}
int main(int argc, char** argv)
{
    int i_chan = IChan;
    int o_chan = OChan;

    int size = DATA_SIZE;

    //const char *xcl_emu = getenv("XCL_EMULATION_MODE");
    //if(xcl_emu && !strcmp(xcl_emu, "hw_emu")) {
	//i_chan = 1;
//	o_chan = 2;
//
//	size = o_chan * OSize * OSize;
//
//	printf("\nOriginal Dataset is Reduced for Faster Execution of Hardware Emulation Flow\n");
//	printf("\t#Input_Channels (IChan)            = %d (Original : 96 )\n", i_chan);
//	printf("\t#Weight_Output_Channels (WOutChan) = %d (Original : 256)\n\n", o_chan);
//}

    // Allocate Memory in Host (Image, Weights and Output)
    //size_t image_size_bytes  = sizeof(int) * i_chan * ISize * ISize;
    int image_size = 0x1138b;
    size_t image_size_bytes = image_size * sizeof(unsigned int);
    //size_t image_size_bytes = 0x2e4;
    int weight_size = 0x972eb;
    size_t weight_size_bytes = sizeof(unsigned int) * weight_size;

    //size_t weight_size_bytes = sizeof(int) * o_chan * WInChan * WSize * WSize;
    //size_t output_size_bytes = sizeof(int) * o_chan * OSize * OSize;
    int output_size = (o_chan * OSize * OSize) + 7;
    size_t output_size_bytes = (sizeof(unsigned int) * output_size);

    //std::vector<int,aligned_allocator<int>> image(image_size_bytes);
    std::vector<unsigned int, aligned_allocator<unsigned int>> image0(image_size);
    std::vector<unsigned int, aligned_allocator<unsigned int>> image1(image_size);
    std::vector<unsigned int, aligned_allocator<unsigned int>> image2(image_size);
    std::vector<unsigned int, aligned_allocator<unsigned int>> image3(image_size);
    std::vector<unsigned int,aligned_allocator<unsigned int>> weight(weight_size);
    //std::vector<int, aligned_allocator<int>> image_sw(sizeof(int)*i_chan*ISize*ISize);
    //std::vector<int, aligned_allocator<int>> weight_sw(sizeof(int)*o_chan*WInChan*WSize*WSize);
    //std::vector<int,aligned_allocator<int>> source_good_hw_results(output_size_bytes);
    std::vector<unsigned int, aligned_allocator<unsigned int>> source_good_hw_results0(output_size);
    std::vector<unsigned int, aligned_allocator<unsigned int>> source_good_hw_results1(output_size);
    std::vector<unsigned int, aligned_allocator<unsigned int>> source_good_hw_results2(output_size);
    std::vector<unsigned int, aligned_allocator<unsigned int>> source_good_hw_results3(output_size);
    //std::vector<int,aligned_allocator<int>> source_bad_hw_results(output_size_bytes);
    //std::vector<int,aligned_allocator<int>> source_sw_results(sizeof(int)*o_chan*OSize*OSize);

    // Initialize Image, Weights & Output Host Buffers
//    for(int i = 0; i < i_chan*ISize*ISize; i++)
//        image_sw[i] = i%255;
    for(int i = 0; i < image_size; i++){
    	image0[i] = image_data[i];
    	image1[i] = image_data[i];
    	image2[i] = image_data[i];
    	image3[i] = image_data[i];
    }

//    for(int i = 0; i < o_chan*WInChan*WSize*WSize; i++)
//        weight_sw[i] = i%255;
    for(int i = 0; i < weight_size; i++){
    	weight[i] = weight_data[i];
    }

//    for(int i = 0; i < o_chan*OSize*OSize; i++){
//        source_sw_results[i] = 0;
//    }
    for(int i = 0; i < output_size; i++){
    	source_good_hw_results0[i] = 0;
    	source_good_hw_results1[i] = 0;
    	source_good_hw_results2[i] = 0;
    	source_good_hw_results3[i] = 0;
    }

    //std::cout << "Running sw" << std::endl;
    //convGolden(weight_sw.data(), image_sw.data(), source_sw_results.data(), i_chan, o_chan);


//OPENCL HOST CODE AREA START
    //Create Program and Kernels
    std::vector<cl::Device> devices = xcl::get_xil_devices();
    cl::Device device = devices[0];
    
    cl::Context context(device);
    cl::CommandQueue q(context, device, CL_QUEUE_OUT_OF_ORDER_EXEC_MODE_ENABLE);
    std::string device_name = device.getInfo<CL_DEVICE_NAME>();

   // uint64_t bad_duration = run_opencl_cnn(devices, q, context, device_name,
   //         false, size, weight, image, source_bad_hw_results, i_chan, o_chan);

    std::cout << "Running hw" << std::endl;

    run_opencl_cnn(devices, q, context, device_name,
            true, size, weight, image0, image1, image2, image3, source_good_hw_results0,
			source_good_hw_results1, source_good_hw_results2, source_good_hw_results3, i_chan, o_chan);
//OPENCL HOST CODE AREA END

    // Compare the results of the Device to the simulation
    bool match = true;
    for (int i = 0 ; i < output_size; i++){
    	printf("%08x\n", source_good_hw_results1[i]);
    }
//    printf("=======\n");
//    for (int i = 0; i < size; i++){
//    	printf("%08x\n", source_sw_results[i]);
//    }

//    if (bad_duration != 0) {
//        std::cout << "BAD duration = "  << bad_duration  << " ns" << std::endl;
//    }


    //std::cout << "TEST " << (match ? "PASSED" : "FAILED") << std::endl;
    //return (match ? EXIT_SUCCESS :  EXIT_FAILURE);
    return EXIT_SUCCESS;
}
