/*
 * kernel_driver.h
 *
 *  Created on: Mar 12, 2019
 *      Author: myzhao
 */

#ifndef SRC_KERNEL_DRIVER_H_
#define SRC_KERNEL_DRIVER_H_


#define SHARED_MEM_BASE 0x300000
#define ATTESTATION_OFFSET 0x0
#define ATTESTATION_SIZE 0x2B0
#define NONCE_OFFSET 0x0
#define NONCE_SIZE 0x20
#define ATTEST_PK_OFFSET 0x20
#define ATTEST_PK_SIZE 0x20
#define KERNEL_CERT_HASH_OFFSET 0x40
#define KERNEL_CERT_HASH_SIZE 0x30
#define KERNEL_CERT_SIG_OFFSET 0x70
#define KERNEL_CERT_SIG_SIZE 0x200
#define ATTEST_SIG_OFFSET 0x270
#define ATTEST_SIG_SIZE 0x40
#define SHARED_SECRET_SIG_OFFSET 0x2B0
#define SHARED_SECRET_SIG_SIZE 0x40
#define VERIFIER_PK_OFFSET 0x2F0
#define VERIFIER_PK_SIZE 0x20
#define FLAG_OFFSET 0x310

#define BITSTREAM_KEY_OFFSET 0x324 //The ciphertext should be 64-byte aligned (NOT including header)
#define BITSTREAM_KEY_SIZE 0x3C //28 byte header + 32 byte ciphertext

#define SHARED_MEM_SIZE 0x360



#define FPGA_AXI_BASE_ADDR 0xA0000000;

void wait_for_kernel();
void signal_kernel();
void get_attestation();
void load_bitstream();


#endif /* SRC_KERNEL_DRIVER_H_ */
