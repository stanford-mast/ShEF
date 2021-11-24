/******************************************************************************
*
* Copyright (C) 2009 - 2014 Xilinx, Inc.  All rights reserved.
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* Use of the Software is limited solely to applications:
* (a) running on a Xilinx device, or
* (b) that interact with a Xilinx device through a bus or interconnect.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
* XILINX  BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
* WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
* OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*
* Except as contained in this notice, the name of the Xilinx shall not be used
* in advertising or otherwise to promote the sale, use or other dealings in
* this Software without prior written authorization from Xilinx.
*
******************************************************************************/

/*
 * helloworld.c: simple test application
 *
 * This application configures UART 16550 to baud rate 9600.
 * PS7 UART (Zynq) is not initialized by this application, since
 * bootrom/bsp configures it to baud rate 115200
 *
 * ------------------------------------------------
 * | UART TYPE   BAUD RATE                        |
 * ------------------------------------------------
 *   uartns550   9600
 *   uartlite    Configurable only in HW design
 *   ps7_uart    115200 (configured by bootrom/bsp)
 */

#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
#include "ed25519.h"
#include "xparameters.h"
#include "security_kernel.h"
#include "ipi.h"


/********************* Global Variable Definitions **********************/
//XCsuDma csu_dma = {0};
//unsigned char security_buffer[SEC_BUFFER_SIZE] __attribute__((section (".security_buffer")));
extern unsigned char kernel_hash[KERNEL_HASH_SIZE];
extern unsigned char keygen_seed[32];
extern unsigned char attest_pk[32];
extern unsigned char attest_sk[64];
extern unsigned char verifier_pk[32];
extern unsigned char session_key[32];
extern unsigned char kernel_cert_hash[48];

//extern attestation_t attestation;
//unsigned char shared_runtime[32] __attribute__((section("sharedRAM")));


int main()
{
	int i;
	u32 status;


    init_platform();
    xil_printf("=====================Security Kernel=================");

    //Clear shared memory
    clear_shared_memory();

    //Initialize IPIs
    status = rpu_gic_init(&gic_inst, XPAR_XIPIPSU_0_INT_ID,
    			(Xil_ExceptionHandler)rpu_ipi_handler, &ipi_inst);
	if(status != XST_SUCCESS){
		return -1;
	}
	//Initialize IPI
	status = rpu_ipi_init(&ipi_inst);
	if(status != XST_SUCCESS){
		return -1;
	}


    print("Security Kernel Hash: ");

    for (i = 0; i < KERNEL_HASH_SIZE; i++){
    	xil_printf("%02x", kernel_hash[i]);
    }
    xil_printf("\r\nSeed:");
    for (i = 0; i < 32; i++){
    	xil_printf("%02x", keygen_seed[i]);
    }
    xil_printf("\r\nAttest PK:");
    for (i = 0; i < 32; i++){
       xil_printf("%02x", attest_pk[i]);
    }
    xil_printf("\r\nAttest SK:");
        for (i = 0; i < 64; i++){
           xil_printf("%02x", attest_sk[i]);
    }


    //Generate attestation keys.
    ed25519_create_keypair(attest_pk, attest_sk, keygen_seed);
    xil_printf("\r\nKernel Hash:");

    for (i = 0; i < KERNEL_HASH_SIZE; i++){
    	xil_printf("%02x", kernel_hash[i]);
    }
    xil_printf("\r\nSeed:");
    for (i = 0; i < 32; i++){
    	xil_printf("%02x", keygen_seed[i]);
    }
    xil_printf("\r\nAttest PK:");
    for (i = 0; i < 32; i++){
       xil_printf("%02x", attest_pk[i]);
    }
    xil_printf("\r\nAttest SK:");
        for (i = 0; i < 64; i++){
           xil_printf("%02x", attest_sk[i]);
    }

    //Generate a certificate over the public attestation key and kernel hash
    get_kernel_certificate_hash(kernel_cert_hash, kernel_hash, attest_pk);

    //Instruct the PMU to sign the certificate hash
    xil_printf("\r\nKernel Certificate Signature:");

    for (i = 0; i < 512; i++){
    	xil_printf("%02x", kernel_cert_sig[i]);
    }

    get_kernel_certificate_signature(kernel_cert_hash);

    xil_printf("\r\nKernel Certificate Signature:");

    for (i = 0; i < 512; i++){
    	xil_printf("%02x", kernel_cert_sig[i]);
    }

    //Block until runtime is ready, and generate an attestation for the runtime.
    //Once the precedure finishes, a shared key will be placed in session_key
    generate_attestation(attest_pk, attest_sk, kernel_hash, (unsigned char*)kernel_cert_sig, session_key);

    //Now, wait for the runtime to provide an encrypted bitstream (encrypted with bitstream decryption key).
    //Decrypt the bitstream and load it into the FPGA.
    //test_aes();

    u32 bitstream_size = wait_for_bitstream_load();

    //Decrypt the bitstream decryption key.
    u8 bitstream_key[32] = {0};
    status = decrypt_bitstream_key(bitstream_key, session_key);
    sleep(1);
    xil_printf("Bitstream key: ");
    for (i = 0; i < 32; i++){
    	xil_printf("%02x", bitstream_key[i]);
    }
    if(status != XST_SUCCESS){
    	cleanup_platform();
    	return -1;
    }

    program_bitstream(bitstream_key, (u8*)(SD_TEMP_BITSTREAM_LOAD_ADDR + 4), bitstream_size);

    //Clear the bitstream key
    memset(bitstream_key, 0, 32);

    while(1);

    cleanup_platform();
    return 0;
}
