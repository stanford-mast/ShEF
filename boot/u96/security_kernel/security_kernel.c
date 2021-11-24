/*
 * security_kernel.c
 *
 *  Created on: Mar 7, 2019
 *      Author: myzhao
 *
 *  Includes functions that perform crypto operations for attestation
 */
#include "xsecure_aes.h"
#include "xparameters.h"
#include "security_kernel.h"
#include "sha3.h"
#include <sleep.h>
#include "ed25519.h"
//#include "xsecure.h"


static u32 Secure_ConvertStringToHexBE(const char * Str, u8 * Buf, u32 Len);
static u32 Secure_ConvertCharToNibble(char InChar, u8 *Num);
static void psu_mask_write(u32 addr, u32 mask, u32 val);

u8 aes_data[XSECURE_DATA_SIZE]__attribute__ ((aligned (64)));
u8 aes_iv[XSECURE_IV_SIZE];
u8 aes_key[XSECURE_KEY_SIZE];

u8 chunk_buffer[CHUNK_SIZE] __attribute__ ((aligned (64)));


/**
 * Given a 48-byte SHA3 hash of the security kernel and the corresponding public attestation key,
 * generate an unsigned certificate hash written in cert.
 *
 * cert_hash: 48 byte buffer to hold the generated certificate hash
 * kernel_hash: 48 byte input containing hash of security kernel
 * attest_pk: 32 byte input containing attestation public key
 */
void get_kernel_certificate_hash(unsigned char* cert_hash, unsigned char* kernel_hash, unsigned char* attest_pk){
	sha3_ctx_t hash;

	sha3_init(&hash, 48);
	sha3_update(&hash, kernel_hash, 48);
	sha3_update(&hash, attest_pk, 32);
	sha3_final(cert_hash, &hash);
}

/**
 *
 */
void clear_shared_memory(){
	//Clear shared memory with runtime
	int i;
	for (i = 0; i < SHARED_MEM_SIZE/4; i++){
		Xil_Out32(SHARED_MEM_BASE + 4*i, 0x00000000);
	}
	return;
}

/**
 * Spin until runtime writes to flag in shared memory
 */
void wait_for_runtime(){
	while(Xil_In8(SHARED_MEM_BASE + FLAG_OFFSET) == 0x01);
	return;
}

/**
 * Signal the runtime
 * Assumes dcache is disabled
 */
void signal_runtime(){
	Xil_Out8(SHARED_MEM_BASE + FLAG_OFFSET, 0x01);
}
/**
 * Given an attestation public key and secret key, a kernel certificate + sig, generate an attestation and
 * store it in shared memory
 */
void generate_attestation(unsigned char* attest_pk, unsigned char* attest_sk, unsigned char* kernel_hash,
		unsigned char* kernel_sig, unsigned char* session_key){
	//Flush and disable the dcache while we're using shared memory
	Xil_DCacheFlush();
	Xil_DCacheDisable();

	int i;
	unsigned char attest_sig[64];
	unsigned char verifier_pk[32];
	unsigned char shared_secret[32];
	unsigned char shared_secret_sig[64];

	//Write the flag
	signal_runtime();

	//Wait for nonce and verifier_pk to be written
	wait_for_runtime();

	xil_printf("Nonce: ");
	for(i = 0; i < NONCE_SIZE; i++){
		xil_printf("%02x", Xil_In8(SHARED_MEM_BASE+NONCE_OFFSET+i));
	}
	xil_printf("\r\n");

	//Copy the attestation data into shared memory
	unsigned char* attest_base_ptr = (unsigned char*)(SHARED_MEM_BASE + ATTESTATION_OFFSET);
	unsigned char* attest_pk_dest = (unsigned char*)(SHARED_MEM_BASE + ATTEST_PK_OFFSET);
	unsigned char* kernel_hash_dest = (unsigned char*)(SHARED_MEM_BASE + KERNEL_HASH_OFFSET);
	unsigned char* kernel_sig_dest = (unsigned char*)(SHARED_MEM_BASE + KERNEL_CERT_SIG_OFFSET);
	unsigned char* attest_sig_dest = (unsigned char*)(SHARED_MEM_BASE + ATTEST_SIG_OFFSET);
	unsigned char* shared_secret_sig_dest = (unsigned char*)(SHARED_MEM_BASE + SHARED_SECRET_SIG_OFFSET);

	xil_printf("Attest PK:");
	for(i=0; i < ATTEST_PK_SIZE; i++){
		xil_printf("%02x", *(attest_pk_dest + i));
	}


	xil_printf("\r\n");

	memcpy(attest_pk_dest, attest_pk, ATTEST_PK_SIZE);
	memcpy(kernel_hash_dest, kernel_hash, KERNEL_HASH_SIZE);
	memcpy(kernel_sig_dest, kernel_sig, KERNEL_CERT_SIG_SIZE);

	xil_printf("Attest PK:");
	for(i=0; i < ATTEST_PK_SIZE; i++){
		xil_printf("%02x", *(attest_pk_dest + i));
	}
	xil_printf("\r\n");

	//Sign the attestation with the attestation secret key
	ed25519_sign(attest_sig, attest_base_ptr, (ATTESTATION_SIZE - ATTEST_SIG_SIZE), attest_pk, attest_sk);

	int success = ed25519_verify(attest_sig, attest_base_ptr, (ATTESTATION_SIZE - ATTEST_SIG_SIZE), attest_pk);
	xil_printf("CHECK ON SIGNATURE %d\r\n",success);
	//Write the signature to memory
	memcpy(attest_sig_dest, attest_sig, ATTEST_SIG_SIZE);

	xil_printf("Attest Signature:");
		for(i=0; i < ATTEST_SIG_SIZE; i++){
			xil_printf("%02x", attest_sig[i]);
	}

	//Generate the shared secret with the verifier.
	unsigned char* verifier_pk_src = (unsigned char*)(SHARED_MEM_BASE + VERIFIER_PK_OFFSET);
	memcpy(verifier_pk, verifier_pk_src, VERIFIER_PK_SIZE);

	xil_printf("Verifier PK:");
	for(i=0; i < 32; i++){
		xil_printf("%02x", *(verifier_pk + i));
	}
	xil_printf("\r\n");

	ed25519_key_exchange(shared_secret, verifier_pk, attest_sk);

	sha3(shared_secret, 32, session_key, 32);


	xil_printf("Shared Secret:");
	for(i=0; i < 32; i++){
		xil_printf("%02x",shared_secret[i]);
	}
	xil_printf("\r\n");

	//Sign the shared secret with the attestation key.
	ed25519_sign(shared_secret_sig, shared_secret, 32, attest_pk, attest_sk);
	//Copy it to memory
	memcpy(shared_secret_sig_dest, shared_secret_sig, SHARED_SECRET_SIG_SIZE);

	xil_printf("Session Key:");
	for(i=0; i < 32; i++){
		xil_printf("%02x",session_key[i]);
	}
	xil_printf("\r\n");

	//Signal to the runtime that the attestation is ready
	signal_runtime();


	//Enable the data cache before exiting
	Xil_DCacheEnable();
	return;
}

/**
 * Given the session key, decrypt a 256-bit (32-byte) AES key into a provided buffer with the session key.
 *
 * decryption_key: 32-byte writable buffer containing the key used to encrypt the bitstream decryption key
 * session_key: 256-bit session key shared with remote user
 *
 * Return XST_SUCCESS on success, error code on failure
 */
u32 decrypt_bitstream_key(u8* bitstream_key_buffer, u8* session_key){
	XSecure_Aes secure_aes;
	XCsuDma csu_dma;
	XCsuDma_Config *dma_config;

	int status;

	//Get the pointer to the tag, ciphertext, and IV
	u8* iv_addr = (u8*) (SHARED_MEM_BASE + BITSTREAM_KEY_OFFSET);
	u8* gcm_tag_addr = (u8*) (SHARED_MEM_BASE + BITSTREAM_KEY_OFFSET + IV_SIZE);
	u8* ciphertext_addr = (u8*) (SHARED_MEM_BASE + BITSTREAM_KEY_OFFSET + IV_SIZE + TAG_SIZE);

	//Initialize CSU DMA driver
	dma_config = XCsuDma_LookupConfig(XSECURE_CSUDMA_DEVICEID);
	if (NULL == dma_config){
		xil_printf("DMA Failed to config \r\n");
		return;
	}

	status = XCsuDma_CfgInitialize(&csu_dma, dma_config, dma_config->BaseAddress);
	if (status != XST_SUCCESS){
		xil_printf("DMA failed to initialize\r\n");
	}


	//Initialize AES driver with the nonce in shared memory and the session key
	XSecure_AesInitialize(&secure_aes, &csu_dma, XSECURE_CSU_AES_KEY_SRC_KUP, (u32 *) iv_addr, (u32 *) session_key);

	//Set the destination of decryption to be the bitstream key buffer.
	XSecure_AesDecryptInit(&secure_aes, bitstream_key_buffer, 32, gcm_tag_addr);

	//Perform the decryption
	status = XSecure_AesDecryptUpdate(&secure_aes, ciphertext_addr, 32);

	return status;

}
//
///**
// * Test AES crypto engine
// */
//void test_aes(){
//	XSecure_Aes secure_aes;
//	XCsuDma csu_dma;
//
//	u8 dec_data[XSECURE_DATA_SIZE]__attribute__((aligned (64)));
//	u8 enc_data[XSECURE_DATA_SIZE + XSECURE_SECURE_GCM_TAG_SIZE] __attribute__((aligned (64)));
//
//	int Status;
//
//	Status = Secure_ConvertStringToHexBE(
//			(const char *) (XSECURE_AES_KEY), aes_key, XSECURE_KEY_SIZE * 2);
//	if (Status != XST_SUCCESS) {
//			xil_printf(
//				"String Conversion error (KEY):%08x !!!\r\n", Status);
//			return;
//	}
//
//	Status = Secure_ConvertStringToHexBE(
//				(const char *) (XSECURE_IV),
//					aes_iv, XSECURE_IV_SIZE * 2);
//	if (Status != XST_SUCCESS) {
//		xil_printf(
//			"String Conversion error (IV):%08x !!!\r\n", Status);
//		return;
//	}
//
//	Status = Secure_ConvertStringToHexBE(
//			(const char *) (XSECURE_DATA),
//				aes_data, XSECURE_DATA_SIZE * 2);
//	if (Status != XST_SUCCESS) {
//		xil_printf(
//			"String Conversion error (Data):%08x !!!\r\n", Status);
//		return;
//	}
//
//	XCsuDma_Config *dma_config;
//	u32 i;
//
//	//Initialize CSU DMA driver
//	dma_config = XCsuDma_LookupConfig(XSECURE_CSUDMA_DEVICEID);
//	if (NULL == dma_config){
//		xil_printf("DMA Failed to config \r\n");
//		return;
//	}
//
//	Status = XCsuDma_CfgInitialize(&csu_dma, dma_config, dma_config->BaseAddress);
//	if (Status != XST_SUCCESS){
//		xil_printf("Dma failed to initialize\r\n");
//	}
//
//	//Initialize AES driver
//	XSecure_AesInitialize(&secure_aes, &csu_dma, XSECURE_CSU_AES_KEY_SRC_KUP, (u32 *) aes_iv, (u32 *) aes_key);
//
//	XSecure_AesEncryptInit(&secure_aes, enc_data, XSECURE_DATA_SIZE);
//	XSecure_AesEncryptUpdate(&secure_aes, aes_data, XSECURE_DATA_SIZE);
//
//	xil_printf("Encrypted data: \r\n");
//	for (i = 0; i < XSECURE_DATA_SIZE; i++){
//		xil_printf("%02x", enc_data[i]);
//	}
//	xil_printf("\r\n");
//
//	xil_printf("tag: \r\n");
//	for (i = 0; i < XSECURE_SECURE_GCM_TAG_SIZE; i++){
//		xil_printf("%02x", enc_data[i + XSECURE_DATA_SIZE]);
//	}
//
//
//	XSecure_AesDecryptInit(&secure_aes, dec_data, XSECURE_DATA_SIZE, enc_data + XSECURE_DATA_SIZE);
//	Status = XSecure_AesDecryptUpdate(&secure_aes, enc_data, XSECURE_DATA_SIZE);
//
//	if (Status != XST_SUCCESS){
//		xil_printf("Decryption failed");
//	}
//
//	xil_printf("Decrypted data \r\n");
//	for (i = 0; i < XSECURE_DATA_SIZE; i++){
//		xil_printf("%02x", dec_data[i]);
//	}
//
//
//
//	return;
//}

u32 wait_for_bitstream_load(){
	Xil_DCacheFlush();
	Xil_DCacheDisable();

	wait_for_runtime();

	u32 bitstream_size = Xil_In32(SD_TEMP_BITSTREAM_LOAD_ADDR);

	xil_printf("Kernel: Read bitstream size: %08x\r\n", bitstream_size);

	Xil_DCacheEnable();

	return bitstream_size;
}
/**
 * Program the bitstream onto the PL
 *
 * @param addr: Address of encrypted bitstream
 * @param size: size of bitstream ciphertext (incl. tag/IV for each chunk)
 */
void program_bitstream(u8* bitstream_key, u8* addr, u32 size){
	Xil_DCacheFlush();
	Xil_DCacheDisable();

	xil_printf("Programming bitstream\r\n");

	u32 reg_val;
	u32 status;
	u32 i;
	u32 chunk_ptr = 0;

	//================================ AES/DMA Initialization ====================================
	//Initialize AES
	XSecure_Aes secure_aes;
	//Initialize DMA
	XCsuDma csu_dma = {0};
	XCsuDma_Config *dma_config;

	//Format AES key and IV
//	status = Secure_ConvertStringToHexBE(
//			(const char *) (XSECURE_AES_KEY), aes_key, XSECURE_KEY_SIZE * 2);
//	if (status != XST_SUCCESS) {
//			xil_printf(
//				"String Conversion error (KEY):%08x !!!\r\n", status);
//			return;
//	}
//
//	status = Secure_ConvertStringToHexBE(
//				(const char *) (XSECURE_IV),
//					aes_iv, XSECURE_IV_SIZE * 2);
//	if (status != XST_SUCCESS) {
//		xil_printf(
//			"String Conversion error (IV):%08x !!!\r\n", status);
//		return;
//	}

	//Initialize CSU DMA driver
	dma_config = XCsuDma_LookupConfig(XSECURE_CSUDMA_DEVICEID);
	if (NULL == dma_config){
		xil_printf("DMA Failed to config \r\n");
		return;
	}

	status = XCsuDma_CfgInitialize(&csu_dma, dma_config, dma_config->BaseAddress);
	if (status != XST_SUCCESS){
		xil_printf("DMA failed to initialize\r\n");
	}




	//Initialize PCAP
	reg_val = Xil_In32(CSU_PCAP_RESET);
	reg_val &= (~CSU_PCAP_RESET_RESET_MASK);
	Xil_Out32(CSU_PCAP_RESET, reg_val);

	Xil_Out32(CSU_PCAP_CTRL, 0x00000001U);
	Xil_Out32(CSU_PCAP_RDWR, 0x00000000U);

	//Power up PL
	reg_val = Xil_In32(CSU_PCAP_STATUS);
	xil_printf("reg_val: %08x\r\n", reg_val);

	reg_val = Xil_In32(PMU_GLOBAL_REQ_PWRUP_INT_EN);
	xil_printf("reg_val: %08x\r\n", reg_val);
	reg_val &= ~(PMU_GLOBAL_REQ_PWRUP_INT_EN_PL_MASK);
	reg_val |= PMU_GLOBAL_REQ_PWRUP_INT_EN_PL_MASK;
	Xil_Out32(PMU_GLOBAL_REQ_PWRUP_INT_EN, reg_val);

	reg_val = Xil_In32(PMU_GLOBAL_REQ_PWRUP_TRIG);
	xil_printf("reg_val: %08x\r\n", reg_val);
	reg_val &= ~(PMU_GLOBAL_REQ_PWRUP_TRIG_PL_MASK);
	reg_val |= PMU_GLOBAL_REQ_PWRUP_TRIG_PL_MASK;
	Xil_Out32(PMU_GLOBAL_REQ_PWRUP_TRIG, reg_val);

	reg_val = Xil_In32(CSU_PCAP_STATUS);
	xil_printf("reg_val: %08x\r\n", reg_val);

	do{
		reg_val = Xil_In32(PMU_GLOBAL_REQ_PWRUP_STATUS);
		reg_val = reg_val & PMU_GLOBAL_REQ_PWRUP_TRIG_PL_MASK;
	}while(reg_val != 0x0U);
	xil_printf("PMU PL Power up\r\n");


	//Reset PL
	Xil_Out32(CSU_PCAP_PROG, 0x00000000U);
	sleep(1);
	Xil_Out32(CSU_PCAP_PROG, 0x00000001U);

	do{
		reg_val = Xil_In32(CSU_PCAP_STATUS);
		reg_val = reg_val & CSU_PCAP_STATUS_PL_CFG_RST_MASK;
	}while (reg_val != CSU_PCAP_STATUS_PL_CFG_RST_MASK);

	do{
		reg_val = Xil_In32(CSU_PCAP_STATUS);
		reg_val = reg_val & CSU_PCAP_STATUS_PL_INIT_MASK;
	} while(reg_val != CSU_PCAP_STATUS_PL_INIT_MASK);

	xil_printf("PCAP reset \r\n");

	sleep(1);

	i = 0;

	while(chunk_ptr < size){
		//Get the pointer to the tag, ciphertext, and IV
		u8* iv_addr = (u8*) ((UINTPTR)addr + chunk_ptr);
		u8* gcm_tag_addr = (u8*) ((UINTPTR)addr + (chunk_ptr + IV_SIZE));
		u8* chunk_addr = (u8*) ((UINTPTR)addr + (chunk_ptr + IV_SIZE + TAG_SIZE));

		//Initialize AES and route SSS to AES engine. Program key and IV into AES engine
		XSecure_AesInitialize(&secure_aes, &csu_dma, XSECURE_CSU_AES_KEY_SRC_KUP, (u32 *) iv_addr, (u32 *) bitstream_key);

		//Check if this is the last chunk (smaller than CHUNK_SIZE)
		u32 chunk_len = CHUNK_SIZE;
		if(size - chunk_ptr < CHUNK_SIZE + IV_SIZE + TAG_SIZE){
			chunk_len = size - chunk_ptr - IV_SIZE - TAG_SIZE;
		}

		//Set the destination of decryption to OCM buffer.
		XSecure_AesDecryptInit(&secure_aes, chunk_buffer, chunk_len, gcm_tag_addr);

		//Perform the decryption
		status = XSecure_AesDecryptUpdate(&secure_aes, chunk_addr, chunk_len);

		if (status != XST_SUCCESS){
			xil_printf("Failed to decrypt chunk with code %d", status);
			return;
		}

		//Once the AES decryption is done, reprogram the DMA engine to copy the chunk from OCM to PCAP
		dma_config = XCsuDma_LookupConfig(XSECURE_CSUDMA_DEVICEID);
		if (NULL == dma_config){
			xil_printf("DMA Failed to config \r\n");
			return;
		}

		status = XCsuDma_CfgInitialize(&csu_dma, dma_config, dma_config->BaseAddress);
		if (status != XST_SUCCESS){
			xil_printf("DMA failed to initialize\r\n");
		}

		reg_val = Xil_In32(ADMA_CH0_ZDMA_CH_CTRL0);
		reg_val &= (ADMA_CH0_ZDMA_CH_CTRL0_POINT_TYPE_MASK | ADMA_CH0_ZDMA_CH_CTRL0_MODE_MASK);
		Xil_Out32(ADMA_CH0_ZDMA_CH_CTRL0, reg_val);

		Xil_Out32(CSU_CSU_SSS_CFG ,CSU_CSU_SSS_CFG_PCAP_SSS_SRC_DMA);

		//Perform the actual DMA transfer and wait for the PCAP to finish programming
		XCsuDma_Transfer(&csu_dma, XCSUDMA_SRC_CHANNEL, (UINTPTR)chunk_buffer, chunk_len/4, 0);
		XCsuDma_WaitForDone(&csu_dma, XCSUDMA_SRC_CHANNEL);
		XCsuDma_IntrClear(&csu_dma, XCSUDMA_SRC_CHANNEL, XCSUDMA_IXR_DONE_MASK);
		XSecure_PcapWaitForDone();

		//Bump the chunk pointer
		chunk_ptr = chunk_ptr + chunk_len + IV_SIZE + TAG_SIZE;
		i = i + 1;
	}

	xil_printf("num chunks: %d\r\n", i);


	xil_printf("CSUDMA finished\r\n");

	//Wait for the PCAP to finish programming
	do{
		reg_val = Xil_In32(XSECURE_CSU_PCAP_STATUS);
		reg_val = reg_val & XSECURE_CSU_PCAP_STATUS_PCAP_WR_IDLE_MASK;
	}while(reg_val != XSECURE_CSU_PCAP_STATUS_PCAP_WR_IDLE_MASK);

	//Wait for PL to be done
	xil_printf("Waiting for PL and  resetting PCAP\r\n");
	do{
		reg_val = Xil_In32(XSECURE_CSU_PCAP_STATUS);
		reg_val = reg_val & CSU_PCAP_STATUS_PL_DONE_MASK;
	}
	while(reg_val != CSU_PCAP_STATUS_PL_DONE_MASK);

	xil_printf("PL Done programming\r\n");

	reg_val = Xil_In32(CSU_PCAP_RESET);
	reg_val |= CSU_PCAP_RESET_RESET_MASK;
	Xil_Out32(CSU_PCAP_RESET, reg_val);

	do{
		reg_val = Xil_In32(CSU_PCAP_RESET);
		reg_val = reg_val & CSU_PCAP_RESET_RESET_MASK;
	}while(reg_val != CSU_PCAP_RESET_RESET_MASK);



	xil_printf("PCAP finished\r\n");
	//Clean up the DMA registers
	Xil_Out32(ADMA_CH0_ZDMA_CH_CTRL0, 0x00000080U);
	Xil_Out32(ADMA_CH0_ZDMA_CH_DST_DSCR_WORD0, 0x00000000U);
	Xil_Out32(ADMA_CH0_ZDMA_CH_DST_DSCR_WORD1, 0x00000000U);
	Xil_Out32(ADMA_CH0_ZDMA_CH_DST_DSCR_WORD2, 0x00000000U);
	Xil_Out32(ADMA_CH0_ZDMA_CH_DST_DSCR_WORD3, 0x00000000U);
	Xil_Out32(ADMA_CH0_ZDMA_CH_SRC_DSCR_WORD0, 0x00000000U);
	Xil_Out32(ADMA_CH0_ZDMA_CH_SRC_DSCR_WORD1, 0x00000000U);
	Xil_Out32(ADMA_CH0_ZDMA_CH_SRC_DSCR_WORD2, 0x00000000U);
	Xil_Out32(ADMA_CH0_ZDMA_CH_SRC_DSCR_WORD3, 0x00000000U);

	//Remove isolation between PS-PL
	psu_mask_write(PMU_GLOBAL_REQ_PWRUP_INT_EN, PMU_GLOBAL_REQ_PWRUP_INT_EN_PL_MASK, PMU_GLOBAL_REQ_PWRUP_INT_EN_PL_MASK);
	psu_mask_write(PMU_GLOBAL_REQ_PWRUP_TRIG, PMU_GLOBAL_REQ_PWRUP_TRIG_PL_MASK, PMU_GLOBAL_REQ_PWRUP_TRIG_PL_MASK);


	do{
		reg_val = Xil_In32(PMU_GLOBAL_REQ_PWRUP_STATUS);
		reg_val = reg_val & PMU_GLOBAL_REQ_PWRUP_TRIG_PL_MASK;
	}while(reg_val != 0x0U);
	xil_printf("PMU PL Power up\r\n");


	//Reset the PL
	psu_mask_write(GPIO_MASK_DATA_5_MSW, 0xFFFF0000U, 0x80000000U);
	psu_mask_write(GPIO_MASK_DIRM, 0xFFFFFFFFU, 0x80000000U);
	psu_mask_write(GPIO_OEN_5, 0xFFFFFFFFU, 0x80000000U);
	psu_mask_write(GPIO_DATA_5, 0xFFFFFFFFU, 0x80000000U);
	sleep(1);
	psu_mask_write(GPIO_DATA_5, 0xFFFFFFFFU, 0x00000000U);
	sleep(1);
	psu_mask_write(GPIO_DATA_5, 0xFFFFFFFFU, 0x80000000U);

	xil_printf("ps-pl isolation config\r\n");



	//Signal the Runtime that bitstream programming is done
	signal_runtime();

	//Enable caches
	Xil_DCacheEnable();

	xil_printf("Finished programming\r\n");

	return;
}


/****************************************************************************/
/**
 * Converts the char into the equivalent nibble.
 *	Ex: 'a' -> 0xa, 'A' -> 0xa, '9'->0x9
 *
 * @param	InChar is input character. It has to be between 0-9,a-f,A-F
 * @param	Num is the output nibble.
 *
 * @return
 * 		- XST_SUCCESS no errors occured.
 *		- ERROR when input parameters are not valid
 *
 * @note	None.
 *
 *****************************************************************************/
static u32 Secure_ConvertCharToNibble(char InChar, u8 *Num)
{
	/* Convert the char to nibble */
	if ((InChar >= '0') && (InChar <= '9'))
		*Num = InChar - '0';
	else if ((InChar >= 'a') && (InChar <= 'f'))
		*Num = InChar - 'a' + 10;
	else if ((InChar >= 'A') && (InChar <= 'F'))
		*Num = InChar - 'A' + 10;
	else
		return XST_FAILURE;

	return XST_SUCCESS;
}

/****************************************************************************/
/**
 * Converts the string into the equivalent Hex buffer.
 *	Ex: "abc123" -> {Buf[2] = 0x23, Buf[1] = 0xc1, Buf[0] = 0xab}
 *
 * @param	Str is a Input String. Will support the lower and upper
 *		case values. Value should be between 0-9, a-f and A-F
 *
 * @param	Buf is Output buffer.
 * @param	Len of the input string. Should have even values
 *
 * @return
 *		- XST_SUCCESS no errors occured.
 *		- ERROR when input parameters are not valid
 *		- an error when input buffer has invalid values
 *
 * @note	None.
 *
 *****************************************************************************/
static u32 Secure_ConvertStringToHexBE(const char * Str, u8 * Buf, u32 Len)
{
	u32 ConvertedLen = 0;
	u8 LowerNibble, UpperNibble;

	/* Check the parameters */
	if (Str == NULL)
		return XST_FAILURE;

	if (Buf == NULL)
		return XST_FAILURE;

	/* Len has to be multiple of 2 */
	if ((Len == 0) || (Len % 2 == 1))
		return XST_FAILURE;

	ConvertedLen = 0;
	while (ConvertedLen < Len) {
		/* Convert char to nibble */
		if (Secure_ConvertCharToNibble(Str[ConvertedLen],
				&UpperNibble) ==XST_SUCCESS) {
			/* Convert char to nibble */
			if (Secure_ConvertCharToNibble(
					Str[ConvertedLen + 1],
					&LowerNibble) == XST_SUCCESS) {
				/* Merge upper and lower nibble to Hex */
				Buf[ConvertedLen / 2] =
					(UpperNibble << 4) | LowerNibble;
			} else {
				/* Error converting Lower nibble */
				return XST_FAILURE;
			}
		} else {
			/* Error converting Upper nibble */
			return XST_FAILURE;
		}
		ConvertedLen += 2;
	}

	return XST_SUCCESS;
}

static void psu_mask_write(u32 addr, u32 mask, u32 val)
{
	u32 RegVal = 0x0;

	RegVal = Xil_In32(addr);
	RegVal &= ~(mask);
	RegVal |= (val & mask);
	Xil_Out32(addr, RegVal);
}
