/******************************************************************************
* Copyright (C) 2017 Xilinx, Inc.  All rights reserved.
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
******************************************************************************/

#ifndef XPFW_MOD_IPI_EXAMPLE_H_
#define XPFW_MOD_IPI_EXAMPLE_H_

#define SEC_MOD_IPI_HANDLER_ID 			0x1EU
#define XPFW_IPI_MSG_SEND_TIME 			10000U
#define IPI_PMU_CH0_MASK 				XPAR_XIPIPS_TARGET_PSU_PMU_0_CH0_MASK

#define IPI_BITSTREAM_HASH_MASK			0xF0F0F0F0
#define RSA_SIZE 						512 /* 4096 bits */
#define SHA3_SIZE						48  /* 384 bit digest */

#define FLIP_ENDIAN(a) ((a>>24)&0xff) | ((a<<8)&0xff0000) | \
						((a>>8)&0xff00) | ((a<<24)&0xff000000)

void sec_ipi_mod_init(void);


#endif /* XPFW_MOD_IPI_EXAMPLE_H_ */
