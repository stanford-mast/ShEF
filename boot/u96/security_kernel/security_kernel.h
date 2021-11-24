/*
 * security_kernel.h
 *
 *  Created on: Mar 5, 2019
 *      Author: myzhao
 */

#ifndef SRC_SECURITY_KERNEL_H_
#define SRC_SECURITY_KERNEL_H_


/****************************** Include Files *******************/
//#include "xcsudma.h"
//#include "xsecure_sha.h"
//#include "xsecure_aes.h"


//extern XCsuDma csu_dma;
//extern XSecure_Sha3 secure_sha3;


#define SEC_BUFFER_SIZE 512

/************************** Address Mappings **********************/
#define SHARED_MEM_BASE 0x300000
#define ATTESTATION_OFFSET 0x0
#define ATTESTATION_SIZE 0x2B0
#define NONCE_OFFSET 0x0
#define NONCE_SIZE 0x20
#define ATTEST_PK_OFFSET 0x20
#define ATTEST_PK_SIZE 0x20
#define KERNEL_HASH_OFFSET 0x40
#define KERNEL_HASH_SIZE 0x30
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



#define SD_TEMP_BITSTREAM_LOAD_ADDR		0x3FFFFC

#define CHUNK_SIZE (1024)
#define TAG_SIZE (16)
#define IV_SIZE (12)

/* Harcoded KUP key for encryption of data */
#define	XSECURE_AES_KEY	\
	"F878B838D8589818E868A828C8488808F070B030D0509010E060A020C0408000"
/* Harcoded IV for encryption of data */
#define	XSECURE_IV	"D2450E07EA5DE0426C0FA133"

#define XSECURE_DATA	\
	"1234567808F070B030D0509010E060A020C0408000A5DE08D85898A5A5FEDCA10134" \
	"ABCDEF12345678900987654321123487654124456679874309713627463801AD1056"


#define XSECURE_DATA_SIZE	(68)
#define XSECURE_IV_SIZE		(12)
#define XSECURE_KEY_SIZE	(32)

#define XSECURE_CSUDMA_DEVICEID	XPAR_XCSUDMA_0_DEVICE_ID

//DMA Channel 0
#define ADMA_CH0_BASE_ADDR 0xFFA80000U
#define ADMA_CH0_ZDMA_CH_CTRL0 ( (ADMA_CH0_BASE_ADDR) + 0x00000110U )
#define ADMA_CH0_ZDMA_CH_CTRL0_POINT_TYPE_MASK  (u32)0x00000040U
#define ADMA_CH0_ZDMA_CH_CTRL0_MODE_MASK		(u32)0x00000030U

#define ADMA_CH0_ZDMA_CH_DST_DSCR_WORD0 ( (ADMA_CH0_BASE_ADDR) + 0x00000138U )
#define ADMA_CH0_ZDMA_CH_DST_DSCR_WORD1 ( (ADMA_CH0_BASE_ADDR) + 0x0000013CU )
#define ADMA_CH0_ZDMA_CH_DST_DSCR_WORD2 ( (ADMA_CH0_BASE_ADDR) + 0x00000140U )
#define ADMA_CH0_ZDMA_CH_DST_DSCR_WORD3 ( (ADMA_CH0_BASE_ADDR) + 0x00000144U )

#define ADMA_CH0_ZDMA_CH_SRC_DSCR_WORD0 ( (ADMA_CH0_BASE_ADDR) + 0x00000128U )
#define ADMA_CH0_ZDMA_CH_SRC_DSCR_WORD1 ( (ADMA_CH0_BASE_ADDR) + 0x0000012CU )
#define ADMA_CH0_ZDMA_CH_SRC_DSCR_WORD2 ( (ADMA_CH0_BASE_ADDR) + 0x00000130U )
#define ADMA_CH0_ZDMA_CH_SRC_DSCR_WORD3 ( (ADMA_CH0_BASE_ADDR) + 0x00000134U )


//CSU and SSS config
#define CSU_BASE_ADDR 0xFFCA0000U
#define CSU_CSU_SSS_CFG ( (CSU_BASE_ADDR) + 0x00000008U )
#define CSU_CSU_SSS_CFG_PCAP_SSS_SRC_DMA 0x5U

#define CSU_PCAP_PROG  ( (CSU_BASE_ADDR) + 0x00003000U )
#define CSU_PCAP_RDWR ( (CSU_BASE_ADDR) + 0x00003004U )
#define CSU_PCAP_RESET ( (CSU_BASE_ADDR) + 0x0000300CU )
#define CSU_PCAP_CTRL ( (CSU_BASE_ADDR) + 0x00003008U )
#define CSU_PCAP_STATUS ( (CSU_BASE_ADDR) + 0x00003010U )

#define CSU_PCAP_RESET_RESET_MASK 0x00000001U
#define CSU_PCAP_STATUS_PL_DONE_MASK 0x00000008U
#define CSU_PCAP_STATUS_PL_CFG_RST_MASK 0x00000040U
#define CSU_PCAP_STATUS_PL_INIT_MASK 0x00000004U

//PMU Registers
#define PMU_GLOBAL_BASE_ADDR 0xFFD80000U
#define PMU_GLOBAL_REQ_PWRUP_INT_EN  ( (PMU_GLOBAL_BASE_ADDR) + 0x00000118U)
#define PMU_GLOBAL_REQ_PWRUP_INT_EN_PL_MASK 0x00800000U
#define PMU_GLOBAL_REQ_PWRUP_TRIG  ( (PMU_GLOBAL_BASE_ADDR) + 0x00000120U)
#define PMU_GLOBAL_REQ_PWRUP_TRIG_PL_MASK  0x00800000U
#define PMU_GLOBAL_REQ_PWRUP_STATUS  ( (PMU_GLOBAL_BASE_ADDR) + 0x00000110U)

//GPIO registers
#define GPIO_MASK_DATA_5_MSW 0xFF0A002C
#define GPIO_MASK_DIRM  0xFF0A0344
#define GPIO_OEN_5 0xFF0A0348
#define GPIO_DATA_5 0xFF0A0054




/**************************Function prototypes ******************/
void get_kernel_certificate_hash(unsigned char* cert_hash, unsigned char* kernel_hash, unsigned char* attest_pk);
void clear_shared_memory();
void signal_runtime();

void generate_attestation(unsigned char* attest_pk, unsigned char* attest_sk, unsigned char* kernel_hash,
		unsigned char* kernel_sig, unsigned char* session_key);

u32 decrypt_bitstream_key(u8* bitstream_key_buffer, u8* session_key);

u32 wait_for_bitstream_load();

void program_bitstream(u8* bitstream_key, u8* addr, u32 size);



/************************** Data structures ******************/
typedef struct{
	unsigned char nonce[32];
	unsigned char attest_pk[32];
	unsigned char kernel_cert_hash[48];
	unsigned char kernel_cert_sig[512];
	unsigned char attest_sig[64];
} attestation_t;


#endif /* SRC_SECURITY_KERNEL_H_ */
