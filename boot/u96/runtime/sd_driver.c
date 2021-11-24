/*
 * sd_driver.c
 *
 *  Created on: Mar 18, 2019
 *      Author: myzhao
 */


/*
 * sd.c
 *
 *  Created on: Nov 27, 2018
 *      Author: myzhao
 *
 *      Contains functions to read SD card, load bitstream.
 */

#include "xparameters.h"
#include "xsdps.h"
#include "xil_printf.h"
#include "ff.h"
#include "xil_cache.h"
#include "xplatform_info.h"

#include "sd_driver.h"



//XCsuDma csu_dma;

static FIL fil; //File object
static FATFS fatfs;

static char bitname[32] = "bitstr.bin";
static char *sd_file;
u8 sd_bitstream_hash[48];
u32 platform;

/**
 * Given an address, load the bitstream in the SD card to the
 * linear address range starting at load_addr
 *
 * returns size of the bitstream.
 */
u32 read_sd_bitstream(u8* load_addr){
	u32 bytes_read;
	//u32 status;
	FRESULT res;
	u32 bitstream_size = 0;
	//u8 bitstream_digest[48];

//	XCsuDma_Config *csu_config;
//		csu_config = XCsuDma_LookupConfig(XPAR_PSU_CSUDMA_DEVICE_ID);
//		if (csu_config == NULL){
//			xil_printf("RPU: Failed to configure CSU\r\n");
//			return;
//		}
//		status = XCsuDma_CfgInitialize(&csu_dma, csu_config, csu_config->BaseAddress);
//		if (status != XST_SUCCESS){
//			xil_printf( "RPU: Failed to initialize CSU\r\n");
//			return;
//		}
//		XSecure_Sha3Initialize(&secure_sha3, &csu_dma);
//		if (status != XST_SUCCESS){
//			xil_printf("RPU: Failed to initialize SHA3\r\n");
//			return;
//		}

	//Read in the bitstream from the SD card.
	//Logical drive 0
	TCHAR *path = "0:/";
	res = f_mount(&fatfs, path, 0);
	if (res != FR_OK){
		xil_printf("RPU: Failed to mount SD card\r\n");
		return 0;
	}

	//Open file
	sd_file = (char *)bitname;

	res = f_open(&fil, sd_file, FA_READ);
	if (res){
		xil_printf("RPU: Failed to open file\r\n");
		return 0;
	}

	//Pointer to beginning of file
	res = f_lseek(&fil, 0);
	if (res){
		xil_printf("RPU: Failed to seek to beginning of file\r\n");
		return 0;
	}
	res = f_read(&fil, (void*)load_addr, fil.fsize, &bytes_read);
	if(res){
		xil_printf("RPU: Failed to read file\r\n");
		return 0;
	}
	bitstream_size = fil.fsize;
	xil_printf("RPU: Read %d bytes from SD card \r\n", bitstream_size);
	//XSecure_Sha3Digest(&secure_sha3, load_addr, bitstream_size, bitstream_digest);

	//xil_printf("RPU: Bitstream hash is 0x");
	u32 i;
	//for(i = 0; i < 48; i++){
	//	xil_printf("%02x", bitstream_digest[i]);
	//}
	//xil_printf("\r\n");

	res = f_close(&fil);
	if (res){
		xil_printf("Runtime: Unable to close file\r\n");
		return 0;
	}

	return bitstream_size;
}
