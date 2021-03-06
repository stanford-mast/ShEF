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

#include "xpfw_default.h"
#include "xpfw_config.h"
#include "xpfw_core.h"
#include "xpfw_events.h"
#include "xpfw_module.h"
#include "xparameters.h"
#include "xsecure_rsa.h"
#include "xsecure_sha.h"
#include "xilfpga_pcap.h"
#include "xfpga_config.h"

#include "xpfw_ipi_manager.h"
#include "xpfw_mod_sec.h"

/* Exponent of private key */
u8 root_sk[RSA_SIZE] = {
	0x8f,0xef,0x22,0x8e,0x42,0x6c,0x0b,0x0e,0x67,0x19,0xc7,0xd5,0x7a,0x98,
	0xe8,0x70,0x09,0x9f,0x04,0xda,0xd6,0xd8,0xcc,0xea,0xa5,0x34,0xbf,0xb0,0x36,
	0xf0,0x75,0x8f,0xb0,0x12,0x59,0x8e,0x23,0x89,0x3f,0xbf,0xf1,0xbd,0xf1,0x39,
	0x63,0xa1,0xd4,0xc7,0xea,0xe7,0x6b,0x45,0x3a,0xad,0x1f,0xba,0xc8,0xf5,0xdd,
	0xcc,0x3c,0x87,0xf7,0x1a,0x24,0xdc,0xb3,0x49,0x58,0x20,0x17,0x85,0xa6,0xf5,
	0x8e,0x50,0x78,0x20,0x0f,0x15,0x26,0xcd,0xba,0x65,0x05,0x1c,0x28,0x64,0xad,
	0x3b,0x32,0x40,0x9e,0x26,0x4e,0xb1,0x18,0xd5,0xc7,0x87,0x97,0x3a,0xdd,0xfa,
	0x02,0x3e,0xbc,0xf3,0x24,0x66,0x9c,0xdd,0xfd,0xb9,0xf7,0xad,0x69,0xab,0x8f,
	0x08,0x58,0xd1,0x55,0x3e,0x41,0x7f,0x5f,0x8d,0x06,0xf9,0x41,0x6d,0x7b,0x02,
	0xe3,0xcf,0xdb,0x6b,0xde,0x70,0xee,0xac,0x85,0xd4,0x9c,0xaa,0xe1,0xfc,0x3f,
	0xc3,0xf1,0x09,0xda,0x89,0x50,0x00,0xe9,0x89,0x5c,0x8e,0x04,0xb8,0x04,0x0f,
	0x7a,0x96,0x1f,0x63,0x90,0x08,0x7c,0x48,0xee,0x4d,0x85,0x8c,0x69,0xc8,0x9d,
	0x1b,0x9a,0x10,0xe3,0xd5,0x5b,0xb1,0xed,0xbe,0xd5,0x92,0x32,0x4e,0xa1,0xce,
	0xcb,0x81,0x04,0xb1,0xf7,0x7f,0xdc,0x89,0x19,0x20,0x13,0x82,0x13,0xf0,0x29,
	0xb9,0x19,0x6b,0xbd,0xad,0xa9,0x83,0xb3,0x0a,0xa4,0xa8,0xfa,0x0f,0x16,0x08,
	0x4f,0xb3,0xf9,0x5d,0xbf,0x7c,0xd3,0x0c,0x30,0x9b,0x99,0x97,0x30,0x9c,0xad,
	0x72,0x1b,0x0d,0x3f,0xfe,0x99,0x62,0xb8,0xc1,0xe1,0x5f,0xde,0x4d,0x0b,0x89,
	0xcc,0xea,0x42,0xc5,0xcf,0x60,0x43,0xef,0x57,0x92,0x0e,0xf8,0x25,0x17,0xba,
	0x17,0xd4,0xde,0x7f,0x58,0xe9,0xb9,0x54,0x69,0x28,0xff,0x6f,0x03,0xfd,0x31,
	0xe5,0x8a,0xe7,0x57,0xa7,0xf6,0x58,0x3f,0x90,0xa1,0xa8,0x29,0x90,0xa1,0x0b,
	0x99,0x8c,0xb8,0x1b,0x30,0x50,0xf4,0x2f,0x75,0xff,0xb0,0xb8,0x03,0xeb,0x92,
	0x4b,0xa4,0x10,0xc2,0x09,0x80,0xe3,0x0e,0xe5,0x2e,0x45,0x20,0x64,0x35,0xc4,
	0x0f,0x2d,0x1d,0xfa,0x28,0xb2,0x7c,0x54,0x0d,0x5c,0x56,0x8f,0xae,0x25,0xd9,
	0xed,0xe2,0x11,0x60,0x34,0x42,0x94,0x8f,0xa5,0x49,0x12,0x1f,0xf6,0x33,0x95,
	0x58,0xc2,0x37,0xa9,0x93,0xc1,0x92,0x3d,0xa5,0xf6,0x87,0xc9,0xa9,0xc9,0x50,
	0x8d,0x86,0x69,0xf3,0x14,0xfe,0x72,0xb6,0x9f,0xf9,0x88,0xd8,0xc8,0xc3,0xfa,
	0xa8,0x9b,0x19,0x8f,0x26,0xb3,0xc4,0x2a,0x66,0x29,0xd9,0x06,0x0e,0x2b,0xca,
	0xff,0x09,0x18,0xd5,0x51,0xef,0x94,0x1a,0xb1,0x75,0xca,0xbb,0x7e,0xc9,0x32,
	0x15,0xda,0x1a,0xf8,0x02,0x85,0x09,0x6b,0x18,0xce,0x2d,0xaf,0xf4,0xe0,0xe1,
	0x68,0x3a,0x71,0x12,0xc9,0x11,0x17,0x70,0x76,0xab,0x18,0x29,0x7d,0x51,0x81,
	0xdc,0xe4,0x4c,0x04,0xd4,0x3c,0x32,0xea,0xe7,0x90,0xcd,0x28,0x08,0xf4,0x2f,
	0xe7,0xe0,0xdd,0x69,0x0e,0xb8,0xae,0x2b,0x0c,0x42,0x87,0x8f,0x42,0x9f,0x2f,
	0x9a,0x61,0x9a,0x75,0x89,0xd8,0xbe,0xf3,0x02,0x0d,0x08,0x17,0xf4,0x99,0x62,
	0x64,0x27,0x81,0x78,0xe2,0xfa,0x81,0xb6,0x9f,0x26,0xb6,0x5f,0xb9,0x91,0xf8,
	0xbc,0x61,0xf1
};

/* Exponent of Public key */
u32 root_pk = 0x1000100; //CSU requires '0' byte at end for some reason?

/* Modulus */
u8 root_mod[RSA_SIZE] = {
	0xc0,0x36,0x58,0xd5,0x05,0x9f,0xf6,0x9f,0x8c,0xb2,0x9a,0x9c,0x36,0x68,
	0xb8,0x2a,0x28,0xc4,0x36,0x4d,0x4e,0x33,0xce,0xdb,0xcf,0x2b,0xdd,0x38,0xda,
	0x01,0xdc,0x11,0xf9,0x4a,0xba,0x6a,0x70,0xeb,0xe1,0xc0,0x48,0xc4,0xa7,0x21,
	0x43,0xa4,0x66,0xf5,0xc0,0xdb,0x74,0x6e,0xf3,0xd8,0xfe,0x6f,0x42,0x4b,0x1c,
	0x13,0x40,0x0e,0xf5,0x6e,0xa1,0x13,0x8d,0x45,0x4f,0xfc,0x3e,0x0a,0xe2,0x48,
	0x83,0xbc,0x2d,0xbd,0x79,0xf1,0xe2,0x42,0xbc,0x03,0x6b,0x5c,0x11,0x1d,0x38,
	0x66,0x27,0xbf,0x7c,0x55,0x1d,0x7a,0xe0,0x01,0xd6,0x8c,0x15,0xcb,0xe7,0xa7,
	0x87,0xf1,0x79,0x2d,0x23,0xab,0x20,0x18,0x2d,0x07,0x1a,0x04,0x23,0x6f,0x52,
	0x55,0xcc,0x6d,0xd3,0x8d,0xdb,0xce,0x83,0x24,0x71,0xca,0xc0,0xca,0xa0,0xca,
	0xce,0xb5,0x7c,0x26,0x1c,0x3c,0x3e,0xaa,0xbe,0xed,0x16,0x82,0xe7,0x5a,0x6b,
	0x75,0x74,0xe5,0xff,0xce,0xcf,0xea,0x99,0x95,0x28,0x7f,0x34,0x0c,0xa6,0x0b,
	0xb8,0x2b,0x09,0x00,0x7a,0x15,0xb9,0x05,0xcb,0x13,0xa7,0x94,0xea,0x0e,0x04,
	0x11,0xe5,0xfb,0xb0,0xd3,0xa8,0x7c,0x68,0x7f,0xb6,0xf9,0xcd,0x62,0x67,0x1a,
	0xb6,0xfd,0x84,0x9d,0xce,0xb9,0x99,0x83,0x60,0xe2,0x95,0x33,0x43,0x8d,0xba,
	0x50,0xc4,0x29,0x6f,0x33,0x38,0x88,0x31,0x51,0x4f,0xc9,0xbe,0x26,0x04,0x80,
	0xfa,0xb3,0x9d,0xdb,0x72,0xab,0x7c,0x98,0x01,0x0a,0xcc,0x8a,0x04,0x3c,0x2a,
	0x8f,0x39,0x5b,0x2d,0x7c,0x78,0x71,0x6f,0xc2,0x5f,0xc8,0x3e,0xd4,0xc1,0x55,
	0xa7,0xd9,0x96,0x2d,0x08,0xc0,0x0a,0x99,0x54,0x87,0x73,0x6c,0x9b,0x6b,0x65,
	0xc2,0xd9,0x8b,0x1c,0xc2,0x62,0x9b,0xad,0x49,0x81,0xaa,0x02,0xc2,0x4f,0x7b,
	0xc1,0xe6,0x09,0x4c,0xe0,0x9d,0x05,0xf1,0x60,0x12,0x88,0xaa,0x6b,0xaa,0xd7,
	0xb4,0x40,0xc7,0xa2,0x53,0x37,0xcb,0x22,0xcd,0x89,0x0d,0xc1,0x6b,0x24,0x69,
	0x7f,0x8b,0xcd,0x07,0x52,0xa3,0xa4,0x68,0xe7,0xc5,0xdd,0x9c,0x84,0x1a,0xa4,
	0xa3,0xda,0x3b,0x4d,0xd7,0xaf,0x5e,0xe3,0x69,0x6c,0x76,0x4b,0xf8,0xa7,0xd4,
	0xa6,0x9c,0x99,0x8f,0x87,0x85,0x0c,0xd5,0xfb,0x18,0x66,0x2b,0x07,0x98,0x38,
	0x9a,0x01,0x3f,0x4e,0x32,0x56,0xbe,0x0c,0xf6,0x5a,0x7a,0x43,0x12,0x9e,0x0c,
	0x59,0x44,0xaa,0xf8,0x20,0x01,0xc4,0x59,0x9d,0x64,0xc8,0xcc,0xfe,0xf9,0x84,
	0x21,0x56,0x63,0x17,0x8d,0x6c,0x2e,0xde,0x36,0x97,0x09,0x72,0x8e,0xd0,0xe2,
	0xe3,0xbd,0x18,0x29,0x2d,0x3b,0xf9,0x43,0x0a,0x50,0xb5,0x4d,0xe9,0xb7,0x93,
	0x71,0x76,0x8a,0xf7,0x52,0x3a,0xec,0x03,0xd0,0x5c,0x2f,0xce,0x7a,0x7e,0xb8,
	0x31,0xc0,0x85,0x6b,0xaf,0x77,0xda,0x79,0x22,0x20,0xc2,0xd6,0x43,0x91,0x2e,
	0xa9,0x31,0x3a,0xc8,0x76,0xde,0xd9,0x7d,0xc2,0xde,0x2a,0x8e,0xc5,0x0e,0x25,
	0x96,0x2e,0x31,0xec,0xff,0x0d,0x3b,0x0f,0x8e,0x83,0x81,0xe7,0xbe,0x83,0xb6,
	0xcd,0x9b,0x49,0xad,0xe8,0x6c,0xea,0x0a,0xc5,0x23,0xfd,0x62,0x67,0x32,0xe5,
	0x1d,0xbe,0x6a,0x61,0x20,0xcf,0x08,0xdf,0x6e,0x1a,0xe5,0x17,0x57,0x6b,0xf0,
	0x78,0x2b,0xd5
};

/* Hash with PKCS padding */
/*
 * MSB  ------------------------------------------------------------LSB
 * 0x0 || 0x1 || 0xFF(for 202 bytes) || 0x0 || T_padding || SHA384 Hash
 */
u8 kernel_cert[RSA_SIZE] = {
	 0x00,0x01,
	 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
	 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
	 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
	 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
	 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
	 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
	 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
	 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
	 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
	 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
	 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
	 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
	 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
	 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
	 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
	 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
	 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
	 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
	 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
	 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
	 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
	 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
	 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
	 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
	 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
	 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
	 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
	 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
	 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
	 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
	 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
	 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
	 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
	 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
	 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
	 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
	 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
	 0x00,
	 /* T_Padding */
	 0x30,0x41,0x30,0x0D,0x06,0x09,0x60,0x86,0x48,0x01,0x65,0x03,
	 0x04,0x02,0x09,0x05,0x00,0x04,0x30,
	 /* SHA 3 Hash */
	 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
	 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
	 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
	 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF
};


const XPfw_Module_t* sec_ipi_mod_ptr;
static volatile unsigned char cert_hash[48];
XSecure_Rsa secure_rsa;
XSecure_Sha3 secure_sha3;
XCsuDma csu_dma;
u8 kernel_cert_sig[RSA_SIZE];
u8 encrypt_sig_out[RSA_SIZE];
u32 size = RSA_SIZE;

volatile u8* bitstream_addr = NULL;
volatile u32 bitstream_size = 0;

/**
*	Once the attestation PK is received, this function is scheduled.
* This function signs the attestation PK with the device sk, and sends it
* back to the security monitor through IPI
*/
static void sec_sign_cert(void){
	//XPfw_Printf(DEBUG_DETAILED, "PMU: Attestation Key received. Signing with dev_sk\r\n");

	u32 status;
	u32 index;
	u32 msg_buf[8]; //Buffer to hold message to PMUFW
	u32 resp_buf[2] = {0};
	u16 bytes_sent = 0U;
	//u8 attest_pk_digest[48];

	//Echo the attestation key
	//XPfw_Printf(DEBUG_DETAILED,"PMU: Attestation PK\r\n");
	//for(index = 0; index < 32; index++){
	//	XPfw_Printf(DEBUG_DETAILED, "%02x", attest_pk[index]);
	//}
	//XPfw_Printf(DEBUG_DETAILED, "\r\n");

	//Hash the attestation key with SHA3 KECCAK
	XCsuDma_Config *csu_config;
	csu_config = XCsuDma_LookupConfig(XPAR_PSU_CSUDMA_DEVICE_ID);
	if (csu_config == NULL){
		XPfw_Printf(DEBUG_ERROR, "PMU: Failed to configure CSU\r\n");
		return;
	}
	status = XCsuDma_CfgInitialize(&csu_dma, csu_config, csu_config->BaseAddress);
	if (status != XST_SUCCESS){
		XPfw_Printf(DEBUG_ERROR, "PMU: Failed to initialize CSU\r\n");
		return;
	}
//	XSecure_Sha3Initialize(&secure_sha3, &csu_dma);
//	XSecure_Sha3Digest(&secure_sha3, cert_hash, 64, attest_pk_digest);

	//XPfw_Printf(DEBUG_DETAILED, "PMU: Calculated attest pk digest\r\n");
	//for (index = 0; index < SHA3_SIZE; index++){
	//	XPfw_Printf(DEBUG_DETAILED, "%02x", attest_pk_digest[index]);
	//}
	//XPfw_Printf(DEBUG_DETAILED, "\r\n");

	//Write the padded hash that will be signed
	for (index = RSA_SIZE-SHA3_SIZE; index < RSA_SIZE; index++){
		kernel_cert[index] = cert_hash[index-(RSA_SIZE-SHA3_SIZE)];
	}
	//XPfw_Printf(DEBUG_DETAILED, "PMU: Padded attest pk hash\r\n");
	//for (index = 0; index < RSA_SIZE; index++){
	//	XPfw_Printf(DEBUG_DETAILED, "%02x", attest_pk_hash[index]);
	//}
	//XPfw_Printf(DEBUG_DETAILED, "\r\n");

	//Sign the data with the root private key.
	XSecure_RsaInitialize(&secure_rsa, root_mod, NULL, root_sk);
	if(XST_SUCCESS != XSecure_RsaPrivateDecrypt(&secure_rsa, kernel_cert,
			size, kernel_cert_sig)){
		XPfw_Printf(DEBUG_ERROR, "PMU: Failed to sign Kernel Certificate\r\n");
		return;
	}

	XPfw_Printf(DEBUG_DETAILED, "PMU: Generated Kernel Certificate signature\r\n");

	//for(index = 0; index < size; index++){
	//	XPfw_Printf(DEBUG_DETAILED, "%02x", attest_signature[index]);
	//}
	//XPfw_Printf(DEBUG_DETAILED, "\r\n");


	//Verify the signature
	XSecure_RsaInitialize(&secure_rsa, root_mod, NULL, (u8 *)&root_pk);
	if(XST_SUCCESS != XSecure_RsaPublicEncrypt(&secure_rsa, kernel_cert_sig, size, encrypt_sig_out)){
		XPfw_Printf(DEBUG_ERROR, "PMU: Failed to verify Kernel Cert Signature\r\n");
		return;
	}
	XPfw_Printf(DEBUG_DETAILED, "PMU: Generated attestation key data\r\n");
	for(index = 0; index < size; index++){
		XPfw_Printf(DEBUG_DETAILED, "%02x", kernel_cert_sig[index]);
	}
	XPfw_Printf(DEBUG_DETAILED, "\r\n");
	for(index = 0; index < size; index++){
		if(encrypt_sig_out[index] != kernel_cert[index]){
			XPfw_Printf(DEBUG_ERROR, "PMU: Failed to verify Kernel CertSignature\r\n");
			return;
		}
	}

	XPfw_Printf(DEBUG_DETAILED, "Sending Signature to RPU\r\n");

	//Send the signature back to the Security Monitor
	while(bytes_sent < RSA_SIZE){
		/* Each packet is formatted with the first word as the header.
		 * The next word contains the start and end index of the corresponding
		 * bytes of the attestation PK signature.
		 * Finally, the next four words (word 2-5) contain the actual attestation PK
		 * chunk.
		 */
		u16 start_index = bytes_sent;
		u16 end_index = bytes_sent + 16U;
		msg_buf[1] = (bytes_sent << 16) | end_index;

		//Send 16 bytes of the signature

		//memcpy causes an endianness flip. For now, do it this way
		for(index = 0; index < 4; index++){ //Four words in message
			u32 msg_word = (kernel_cert_sig[bytes_sent] << 24) |
							(kernel_cert_sig[bytes_sent+1] << 16) |
							(kernel_cert_sig[bytes_sent+2] << 8) |
							(kernel_cert_sig[bytes_sent+3]);
			bytes_sent += 4;

			msg_buf[index+2] = msg_word;
		}


		//Send the IPI
		//XPfw_Printf(DEBUG_ERROR, "PMU: Sending cert\r\n");
		status = XPfw_IpiWriteMessage(sec_ipi_mod_ptr, IPI_PMU_0_IER_RPU_0_MASK,
				msg_buf, 8);
		if(status != XST_SUCCESS){
			XPfw_Printf(DEBUG_ERROR, "PMU: IPI Write Message Failed \r\n");
			return;
		}
		status = XPfw_IpiTrigger(IPI_PMU_0_IER_RPU_0_MASK);
		if(status != XST_SUCCESS){
			XPfw_Printf(DEBUG_ERROR, "PMU: IPI Trigger failed \r\n");
			return;
		}
		status = XPfw_IpiPollForAck(IPI_PMU_0_IER_RPU_0_MASK, (~0));
		if(status != XST_SUCCESS){
			XPfw_Printf(DEBUG_ERROR, "PMU: IPI Poll for Ack Failed \r\n");
			return;
		}
		status = XPfw_IpiReadResponse(sec_ipi_mod_ptr, IPI_PMU_0_IER_RPU_0_MASK,
				resp_buf, 2);
		if(status != XST_SUCCESS){
			XPfw_Printf(DEBUG_ERROR, "PMU: IPI Read Response failed \r\n");
			return;
		}


		//Check that the expected indices match up
		if(resp_buf[1] != ((start_index << 16) | (end_index))){
			XPfw_Printf(DEBUG_ERROR, "PMU: RPU failed to ack byte indices\r\n");
			return;
		}
	}

	return;
}

/**
 * Code to load a bitstream onto the FPGA through PCAP.
 * This should be called by the IPI handler and given some
 * linear DRAM address that contains the bitstream as a .bin file.
 *
 * The sender of the IPI must load the bitstream into DRAM.
 *
 * This function sends back an IPI to the sender with the hash of
 * the bitstream binary loaded into memory.
 */
static void sec_load_bitstream(){
	u32 status;
	s32 fpga_status;
	u8 bitstream_digest[48];
	u32 msg_buf[8]; //Buffer to hold message to R5
	u32 resp_buf[2] = {0};
	u32 i;
	u32 bytes_sent = 0;

	if(bitstream_size == 0 || bitstream_addr == NULL){
		XPfw_Printf(DEBUG_ERROR, "PMU: Bitstream address or size\r\n");
		return;
	}


	//XPfw_Printf(DEBUG_DETAILED, "PMU: Loading bitstream from address 0x%08x\r\n",
	//		bitstream_addr);
	//XPfw_Printf(DEBUG_DETAILED, "PMU: bitstream size %d\r\n", bitstream_size);

//	for(i = 0; i < bitstream_size; i++){
//		XPfw_Printf(DEBUG_DETAILED, "%02x", bitstream_addr[i]);
//	}
//	XPfw_Printf(DEBUG_DETAILED, "\r\n");

	//Hash the bitstream first with SHA3
	XCsuDma_Config *csu_config;
	csu_config = XCsuDma_LookupConfig(XPAR_PSU_CSUDMA_DEVICE_ID);
	if (csu_config == NULL){
		XPfw_Printf(DEBUG_ERROR, "PMU: Failed to configure CSU\r\n");
		return;
	}
	status = XCsuDma_CfgInitialize(&csu_dma, csu_config, csu_config->BaseAddress);
	if (status != XST_SUCCESS){
		XPfw_Printf(DEBUG_ERROR, "PMU: Failed to initialize CSU\r\n");
		return;
	}
	XSecure_Sha3Initialize(&secure_sha3, &csu_dma);
	if (status != XST_SUCCESS){
		XPfw_Printf(DEBUG_ERROR, "PMU: Failed to initialize SHA3\r\n");
		return;
	}
	XSecure_Sha3Digest(&secure_sha3, bitstream_addr, bitstream_size, bitstream_digest);

	//Load the bitstream through PCAP.
	fpga_status = XFpga_PL_BitSream_Load(bitstream_addr, 0, 0);
	if(fpga_status == XFPGA_SUCCESS){
		XPfw_Printf(DEBUG_DETAILED, "PMU: PL Configuration successful\r\n");
	}
	else{
		XPfw_Printf(DEBUG_DETAILED, "PMU: PL Configuration failed\r\n");
	}

	//Send an IPI to the sender (R5_0) containing the hash of the bitstream
//	XPfw_Printf(DEBUG_DETAILED, "PMU: Bitstream hash is 0x");
//	for(i = 0; i < 48; i++){
//		XPfw_Printf(DEBUG_DETAILED, "%02x", bitstream_digest[i]);
//	}
//	XPfw_Printf(DEBUG_DETAILED, "\r\n");



	while(bytes_sent < SHA3_SIZE){
		msg_buf[1] = IPI_BITSTREAM_HASH_MASK;
		memcpy(&msg_buf[2], &bitstream_digest[bytes_sent], 16);

		status = XPfw_IpiWriteMessage(sec_ipi_mod_ptr, IPI_PMU_0_IER_RPU_0_MASK,
				msg_buf, 8);
		if(status != XST_SUCCESS){
			XPfw_Printf(DEBUG_ERROR, "PMU: IPI Write Message Failed \r\n");
			return;
		}
		status = XPfw_IpiTrigger(IPI_PMU_0_IER_RPU_0_MASK);
		if(status != XST_SUCCESS){
			XPfw_Printf(DEBUG_ERROR, "PMU: IPI Trigger failed \r\n");
			return;
		}
		status = XPfw_IpiPollForAck(IPI_PMU_0_IER_RPU_0_MASK, (~0));
		if(status != XST_SUCCESS){
			XPfw_Printf(DEBUG_ERROR, "PMU: IPI Poll for Ack Failed \r\n");
			return;
		}
		status = XPfw_IpiReadResponse(sec_ipi_mod_ptr, IPI_PMU_0_IER_RPU_0_MASK,
				resp_buf, 2);
		if(status != XST_SUCCESS){
			XPfw_Printf(DEBUG_ERROR, "PMU: IPI Read Response failed \r\n");
			return;
		}


		//Check that the expected reply matches
		if(resp_buf[1] != IPI_BITSTREAM_HASH_MASK){
			XPfw_Printf(DEBUG_ERROR, "PMU: RPU failed to ack hash command\r\n");
			return;
		}
		bytes_sent += 16;
	}
	return;
}


/**
* Code to handle the incoming IPI message from the security monitor
*/
static void sec_ipi_handler(const XPfw_Module_t* mod_ptr, u32 ipi_num, u32 src_mask,
		const u32* payload, u8 len){
	u32 status;
	u32 resp_buf[2] = {0};
	u32 cmd;

	//First, check if the ipi is on the correct channel (i.e. channel 0)
	if (ipi_num > 0){
		XPfw_Printf(DEBUG_ERROR, "PMU: Error: sec_ipi_handler only handles IPI on PMU-0\r\n");
		return;
	}


	//For debug, print out the payload
//	XPfw_Printf(DEBUG_DETAILED, "PMU: Payload Received len %d:",len);
	int i;
//	for(i = 0; i < len; i++){
//		XPfw_Printf(DEBUG_DETAILED, "i:%d,%x \r\n", i, payload[i]);
//	}
//	XPfw_Printf(DEBUG_DETAILED, "\r\n");

	//Redirect the interrupt to the appropriate callback
	memcpy(&cmd, &payload[1], 4);

	//XPfw_Printf(DEBUG_DETAILED, "PMU: Received command 0x%08x", cmd);
	if(cmd == IPI_BITSTREAM_HASH_MASK){
		//Load bitstream addr and size into global variables
		memcpy(&bitstream_addr, &payload[2], 4);
		memcpy(&bitstream_size, &payload[3], 4);

		//XPfw_Printf(DEBUG_DETAILED, "PMU: Received FPGA Program cmd \r\n");

		//Schedule the task to load the bitstream into FPGA
		status = XPfw_CoreScheduleTask(mod_ptr, 0U, sec_load_bitstream);
	}
	else{ //Certificate hash case

		//Store the attestation PK in local memory
		//Check the bounds on the payload
		u16 start_index = payload[1] >> 16;
		if (start_index % 16U != 0){
			XPfw_Printf(DEBUG_ERROR, "PMU:Error: invalid index for cert hash\r\n");
			return;
		}
		memcpy(&cert_hash[start_index], &payload[2], 16);

		//Check if the full attestation PK has been received.
		if(start_index == (u16)32U){
//			XPfw_Printf(DEBUG_DETAILED, "PMU:Received full attestation key:0x");
//			for(i = 0; i < 32; i++){
//				XPfw_Printf(DEBUG_DETAILED, "%x", attest_pk[i]);
//			}
//			XPfw_Printf(DEBUG_DETAILED, "\r\n");
			//If so, schedule the task to sign the attestation key.
			status = XPfw_CoreScheduleTask(mod_ptr, 0U, sec_sign_cert);
			if (status == XST_FAILURE){
				XPfw_Printf(DEBUG_ERROR, "PMU: Failed to schedule sign cert\r\n");
			}
		}
	}
	//Write the response
	resp_buf[1] = payload[1];
	XPfw_IpiWriteResponse(mod_ptr, src_mask, resp_buf, 2);


	return;
}

/**
* Initializes the configuration. Schedules periodic tasks.
*/
static void sec_ipi_cfg_init(const XPfw_Module_t* mod_ptr, const u32* cfg_data, u32 Len){
	//Schedule any periodic tasks here.
	return;
}


/**
* This function is called from xpfw_user_startup.c. Initializes and registers this
* module and associated handlers.
*/
void sec_ipi_mod_init(void){
	sec_ipi_mod_ptr = XPfw_CoreCreateMod();

	if (XPfw_CoreSetCfgHandler(sec_ipi_mod_ptr, sec_ipi_cfg_init) != XST_SUCCESS){
		XPfw_Printf(DEBUG_DETAILED, "PMU: Warning: sec_ipi_mod_ptr: Failed to set cfg_handler \r\n");
	}

	(void)XPfw_CoreSetIpiHandler(sec_ipi_mod_ptr, sec_ipi_handler, SEC_MOD_IPI_HANDLER_ID);
}


