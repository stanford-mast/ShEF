/*===============================================================*/
/*                                                               */
/*                    digit_recognition.cpp                      */
/*                                                               */
/*   Main host function for the Digit Recognition application.   */
/*                                                               */
/*===============================================================*/

// standard C/C++ headers
#include <cstdio>
#include <cstdlib>
#include <getopt.h>
#include <string>
#include <time.h>
#include <sys/time.h>


// other headers
#include "utils.h"
#include "typedefs.h"
#include "check_result.h"
#include "xcl2.hpp"

// data
#include "training_data.h"
#include "testing_data.h"

int main(int argc, char ** argv) 
{
  printf("Digit Recognition Application\n");

	int training_size = 0x236f3;
	int testing_size = 0x3f03;
  //int training_size = 0x147;
  //int testing_size = 0x27;
  int result_size = (NUM_TEST/4) + 7;
	int chunk_size = 0x200;

  // for this benchmark, data is already included in arrays:
  //   training_data: contains 18000 training samples, with 1800 samples for each digit class
  //   testing_data:  contains 2000 test samples
  //   expected:      contains labels for the test samples

  // timers
  struct timeval start, end;
  struct timeval start_exec, end_exec;

  // Initialize device
  int err;
  std::vector<cl::Device> devices = xcl::get_xil_devices();
  cl::Device device = devices[0];

  std::cout << "Creating context" << std::endl;
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
	OCL_CHECK(err, cl::Kernel krnl_digitrec(program, "DigitRec", &err));
	OCL_CHECK(err, cl::Kernel krnl_shield_input_a(program, "krnl_shield_input_rtl_a", &err));
	OCL_CHECK(err, cl::Kernel krnl_shield_input_b(program, "krnl_shield_input_rtl_b", &err));
	OCL_CHECK(err, cl::Kernel krnl_shield_output(program, "krnl_shield_output_rtl", &err));

	//Allocate memory in host memory
	size_t training_mem_bytes = sizeof(unsigned int) * training_size;
	//size_t training_mem_bytes = sizeof(DigitType) * NUM_TRAINING * DIGIT_WIDTH;
	size_t testing_mem_bytes = sizeof(unsigned int) * testing_size;
	size_t result_mem_bytes = sizeof(unsigned int) * result_size;
	//size_t result_mem_bytes = sizeof(LabelType) * NUM_TEST;

	std::vector<unsigned int, aligned_allocator<unsigned int>> source_training_mem(training_size);
	//std::vector<DigitType, aligned_allocator<DigitType>> source_training_mem(NUM_TRAINING*DIGIT_WIDTH);
	std::vector<unsigned int, aligned_allocator<unsigned int>> source_testing_mem(testing_size);
	//std::vector<LabelType, aligned_allocator<LabelType>> source_result_mem(NUM_TEST);
	std::vector<unsigned int, aligned_allocator<unsigned int>> source_result_mem(result_size);

	for(size_t i = 0; i < training_size; i++){
		source_training_mem[i] = training_data[i];
	}
	for(size_t i = 0; i < testing_size; i++){
		source_testing_mem[i] = testing_data[i];
	}
	for(size_t i = 0; i < result_size; i++){
		source_result_mem[i] = 0;
	}

	std::cout << "result length: " << result_size << std::endl;

  // Allocate Buffer in Global Memory
  // Buffers are allocated using CL_MEM_USE_HOST_PTR for efficient memory and
  // Device-to-host communication
  std::vector<cl::Memory> inBufVec, outBufVec;
  std::cout << "Creating Buffers..." <<std::endl;
	OCL_CHECK(err, cl::Buffer buffer_training_mem(context, CL_MEM_USE_HOST_PTR | CL_MEM_READ_ONLY,
		training_mem_bytes, source_training_mem.data(), &err));
	OCL_CHECK(err, cl::Buffer buffer_testing_mem(context, CL_MEM_USE_HOST_PTR | CL_MEM_READ_ONLY,
		testing_mem_bytes, source_testing_mem.data(), &err));
	OCL_CHECK(err, cl::Buffer buffer_result_mem(context, CL_MEM_USE_HOST_PTR | CL_MEM_WRITE_ONLY,
		result_mem_bytes, source_result_mem.data(), &err));

  inBufVec.push_back(buffer_training_mem);
	inBufVec.push_back(buffer_testing_mem);
  outBufVec.push_back(buffer_result_mem);

  //Start the timer
  gettimeofday(&start, 0);

	//Set the arguments
	OCL_CHECK(err, err = krnl_shield_input_a.setArg(0, buffer_training_mem));
	OCL_CHECK(err, err = krnl_shield_input_a.setArg(1, training_size));
	OCL_CHECK(err, err = krnl_shield_input_a.setArg(2, chunk_size));
	OCL_CHECK(err, err = krnl_shield_input_b.setArg(0, buffer_testing_mem));
	OCL_CHECK(err, err = krnl_shield_input_b.setArg(1, testing_size));
	OCL_CHECK(err, err = krnl_shield_input_b.setArg(2, chunk_size));
	OCL_CHECK(err, err = krnl_shield_output.setArg(0, buffer_result_mem));
	OCL_CHECK(err, err = krnl_shield_output.setArg(1, result_size));
	//OCL_CHECK( err, err = krnl_digitrec.setArg(0, buffer_training_mem));
	//OCL_CHECK(err, err = krnl_digitrec.setArg(0, buffer_result_mem));


	//Copy input data to device global memory
	cl::Event write_event;
	OCL_CHECK(err, err = q.enqueueMigrateMemObjects(inBufVec, 0, NULL, &write_event));
	OCL_CHECK(err, err = q.finish());

	//Launch the kernel
	gettimeofday(&start_exec, 0);
	std::cout << "Launching the kernel" << std::endl;
	OCL_CHECK(err, err = q.enqueueTask(krnl_shield_input_a, NULL, &write_event));
	OCL_CHECK(err, err = q.enqueueTask(krnl_shield_input_b, NULL, &write_event));
	OCL_CHECK(err, err = q.enqueueTask(krnl_digitrec, NULL, &write_event));
	OCL_CHECK(err, err = q.enqueueTask(krnl_shield_output, NULL, &write_event));

	//Wait for kernels to finish
	OCL_CHECK(err, err = q.finish());
	gettimeofday(&end_exec, 0);

	//Copy result back into host memory
	std::cout << "Getting Results" << std::endl;
	OCL_CHECK(err, err = q.enqueueMigrateMemObjects(outBufVec, CL_MIGRATE_MEM_OBJECT_HOST));
	OCL_CHECK(err, err = q.finish());

	//Stop the timer
	gettimeofday(&end, 0);

	//Check results
	std::cout << "Checking results" << std::endl;
	unsigned int* results = source_result_mem.data();
	for(int j = 0; j < result_size; j++){
		printf("%08x\n", results[j]);
		//std::cout << std::hex<< (DigitType)results[j] << std::endl;
	}
	//check_results(source_result_mem.data(), expected, NUM_TEST);

  // print time
  long long elapsed = (end.tv_sec - start.tv_sec) * 1000000LL + end.tv_usec - start.tv_usec;   
  printf("elapsed time: %lld us\n", elapsed);
  long long testval = 0xffffffffffffffff;
  printf("test: %llx\n", testval);
  return EXIT_SUCCESS;

}
