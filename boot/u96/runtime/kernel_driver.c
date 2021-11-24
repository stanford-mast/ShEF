/*
 * kernel_driver.c
 *
 *  Created on: Mar 12, 2019
 *      Author: myzhao
 */

#include "kernel_driver.h"
#include "xil_cache.h"
#include <stdio.h>
#include "xil_io.h"
#include "xil_printf.h"
#include "sd_driver.h"

/**
 * Stall until the flag in shared memory is set
 */
void wait_for_kernel(){
	while(Xil_In8(SHARED_MEM_BASE + FLAG_OFFSET) == 0);
	return;
}

/**
 * Signal the kernel
 * Assumes that the DCache is disabled
 */
void signal_kernel(){
	Xil_Out8(SHARED_MEM_BASE+FLAG_OFFSET, 0x00);
	return;
}
/**
 * Given a nonce provided by the user, command the kernel to generate an attestation + signature placed into shared memory
 *
 * precondition: the verifier's nonce and PK are written to shared memory
 */
void get_attestation(){
	Xil_DCacheFlush();
	Xil_DCacheDisable(); //Disable the dcache

	//Wait for the kernel to be ready
	wait_for_kernel();

	xil_printf("Kernel ready\r\n");

//	//Write the nonce to the shared memory
//	int i;
//	for (i = 0; i < NONCE_SIZE; i++){
//		Xil_Out8(SHARED_MEM_BASE+NONCE_OFFSET+i, *(nonce + i));
//	}
//	//Write the verifier PK to shared memory
//	for (i = 0; i < VERIFIER_PK_SIZE; i++){
//		Xil_Out8(SHARED_MEM_BASE + VERIFIER_PK_OFFSET + i, *(verifier_pk + i));
//	}

	//Write the flag to signal the kernel to finish
	signal_kernel();
	xil_printf("wrote nonce + verifier pk\r\n");

	//Wait for the kernel to generate the attestation
	wait_for_kernel();

	//Print out everything
//	xil_printf("Runtime received attestation\r\n");
//	unsigned char* attest_sig_dest = (unsigned char*)(SHARED_MEM_BASE + ATTEST_SIG_OFFSET);
//
//	xil_printf("Attest Signature:");
//		for(i=0; i < ATTEST_SIG_SIZE; i++){
//			xil_printf("%02x", *(attest_sig_dest + i));
//	}



	Xil_DCacheEnable();
	return;
}

/**
 * Load the bitstream from the SD card into DDR. Signal the kernel that bitstream loading has completed
 */
void load_bitstream(){
	u32 bitstream_size = read_sd_bitstream((u8*)(SD_TEMP_BITSTREAM_LOAD_ADDR+4));

	xil_printf("Loaded bitstream into DDR - %08x bytes\r\n", bitstream_size);

	Xil_DCacheFlush();
	Xil_DCacheDisable();

	Xil_Out32(SD_TEMP_BITSTREAM_LOAD_ADDR, bitstream_size);

	signal_kernel();

	Xil_DCacheEnable();
}



