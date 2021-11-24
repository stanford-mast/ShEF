/*
 * sd_driver.h
 *
 *  Created on: Mar 18, 2019
 *      Author: myzhao
 */

#ifndef SRC_SD_DRIVER_H_
#define SRC_SD_DRIVER_H_

//Address to store bitstream from SD card. Make sure that it
//doesn't overlap with anything so nothing explodes
#define SD_TEMP_BITSTREAM_LOAD_ADDR		0x3FFFFC



u32 read_sd_bitstream(u8* load_addr);

#endif /* SRC_SD_DRIVER_H_ */
