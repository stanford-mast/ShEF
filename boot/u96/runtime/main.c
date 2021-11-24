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
#include <sleep.h>
#include "kernel_driver.h"
#include "xil_cache.h"
#include "uart_driver.h"


int main()
{
    init_platform();

    sleep(5);
    int i;
//    unsigned char nonce[32];
//    unsigned char verifier_pk[32] = {0xa9, 0x3f, 0xf0, 0x44, 0xa6, 0x35, 0x11, 0x88,
//    		0xda, 0x2a, 0x54, 0xb4, 0x3d, 0xd9, 0xdc, 0x8c, 0x4b, 0xd4, 0x97, 0xef,
//			0xbd, 0x9f, 0x28, 0x5e, 0x05, 0xc9, 0x85, 0xeb, 0x24, 0xa8, 0xc9, 0x73
//    };
//
//    int i;
//    for(i=0; i < 32; i++){
//    	nonce[i] = i;
//    }

    //First, wait for the remote verifier to send its nonce and PK to us
    u32 status;
    status = handle_uart_cmd();

    if (status != UART_RETURN_PK_NONCE){
    	return -1;
    }

    //Using the nonce+pk, tell the security kernel to generate the attestation
    get_attestation();

    //Send the attestation to the remote user
    //Block until the user sends the decryption key for the bitstream, which is written to shared memory
    status = handle_uart_cmd();
    if (status != UART_RETURN_BITSTREAM_KEY){
    	return -1;
    }


    //Load bitstream into shared memory, and signal the security kernel to program it using the
    //provided decryption key
    load_bitstream();

    //Wait for the kernel to finish loading the bitstream.
	Xil_DCacheFlush();
	Xil_DCacheDisable();
	wait_for_kernel();
	Xil_DCacheEnable();

	//Handle commands from UART
	sleep(1);
	xil_printf("Ready to process host commands:\r\n");
    handle_uart_cmd();
    cleanup_platform();
    return 0;
}
