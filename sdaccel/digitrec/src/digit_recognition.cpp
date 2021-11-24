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
#include "digitrec_sw.h"

int main(int argc, char ** argv) 
{
  printf("Digit Recognition Application\n");

  // for this benchmark, data is already included in arrays:
  //   training_data: contains 18000 training samples, with 1800 samples for each digit class
  //   testing_data:  contains 2000 test samples
  //   expected:      contains labels for the test samples

  // timers
  struct timeval start, end;

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

	//Allocate memory in host memory
	size_t training_mem_bytes = sizeof(DigitType) * NUM_TRAINING * DIGIT_WIDTH;
	size_t testing_mem_bytes = sizeof(DigitType) * NUM_TEST * DIGIT_WIDTH;
	size_t result_mem_bytes = sizeof(LabelType) * NUM_TEST;

	std::vector<DigitType, aligned_allocator<DigitType>> source_training_mem(NUM_TRAINING*DIGIT_WIDTH);
	std::vector<DigitType, aligned_allocator<DigitType>> source_testing_mem(NUM_TEST*DIGIT_WIDTH);
	std::vector<LabelType, aligned_allocator<LabelType>> source_result_mem(NUM_TEST);

	for(size_t i = 0; i < NUM_TRAINING*DIGIT_WIDTH; i++){
		source_training_mem[i] = training_data[i];
	}
	for(size_t i = 0; i < NUM_TEST*DIGIT_WIDTH; i++){
		source_testing_mem[i] = testing_data[i];
	}
	for(size_t i = 0; i < NUM_TEST; i++){
		source_result_mem[i] = 0;
	}

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
	OCL_CHECK(err, err = krnl_digitrec.setArg(0, buffer_training_mem));
	OCL_CHECK(err, err = krnl_digitrec.setArg(1, buffer_testing_mem));
	OCL_CHECK(err, err = krnl_digitrec.setArg(2, buffer_result_mem));


	//Copy input data to device global memory
	cl::Event write_event;
	OCL_CHECK(err, err = q.enqueueMigrateMemObjects(inBufVec, 0, NULL, &write_event));
	OCL_CHECK(err, err = q.finish());

	//Launch the kernel
	std::cout << "Launching the kernel" << std::endl;
	OCL_CHECK(err, err = q.enqueueTask(krnl_digitrec, NULL, &write_event));

	//Wait for kernels to finish
	OCL_CHECK(err, err = q.finish());

	//Copy result back into host memory
	std::cout << "Getting Results" << std::endl;
	OCL_CHECK(err, err = q.enqueueMigrateMemObjects(outBufVec, CL_MIGRATE_MEM_OBJECT_HOST));
	OCL_CHECK(err, err = q.finish());

	//Stop the timer
	gettimeofday(&end, 0);

	//Check results
	std::cout << "Checking results" << std::endl;
	check_results(source_result_mem.data(), expected, NUM_TEST);

  // print time
  long long elapsed = (end.tv_sec - start.tv_sec) * 1000000LL + end.tv_usec - start.tv_usec;   
  printf("hw elapsed time: %lld us\n", elapsed);

  //Compare to software
  LabelType* result = new LabelType[NUM_TEST];
  gettimeofday(&start, NULL);
  DigitRec_sw(training_data, testing_data, result);
  gettimeofday(&end, NULL);

	//Check results
	std::cout << "Checking results" << std::endl;
	check_results(result, expected, NUM_TEST);

elapsed = (end.tv_sec - start.tv_sec) * 1000000LL + end.tv_usec - start.tv_usec;
	  printf("sw elapsed time: %lld us\n", elapsed);

	  delete []result;




  return EXIT_SUCCESS;

}
