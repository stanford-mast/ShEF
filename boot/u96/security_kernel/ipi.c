/**
* This file contains methods to initiate IPI with the PMUFW. IPI is used to call into
* the PMUFW to obtain certificates and other crypto resources from the hardware.
*/

#include "ipi.h"

volatile u32 kernel_cert_sig_bytes_read = 0;

/**
* Initializes the RPU GIC and connects interrupts with handlers
*/
u32 rpu_gic_init(XScuGic *intc_inst_ptr, u32 int_id, Xil_ExceptionHandler handler,
		void *periph_inst_ptr){
	XScuGic_Config *intc_config;
	u32 status = XST_FAILURE;

	intc_config = XScuGic_LookupConfig(XPAR_SCUGIC_0_DEVICE_ID);

	if(intc_config == NULL){
		xil_printf("RPU: Error: GIC config failed\r\n");
		return XST_FAILURE;
	}

	status = XScuGic_CfgInitialize(intc_inst_ptr, intc_config,
			intc_config->CpuBaseAddress);

	if(status != XST_SUCCESS){
		xil_printf("RPU: Error: GIC init failed\r\n");
		return XST_FAILURE;
	}

	//Connect the interrupt controller handler to the hardware
	//handling logic in proc
	Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,
			(Xil_ExceptionHandler)XScuGic_InterruptHandler, intc_inst_ptr);
	
	//Connect the IntID of the interrupt source and the associated handler
	(void)XScuGic_Connect(intc_inst_ptr, int_id, handler, periph_inst_ptr);
	XScuGic_Enable(intc_inst_ptr, int_id);

	//Enable processor interrupts
	Xil_ExceptionEnableMask(XIL_EXCEPTION_IRQ);
	
	xil_printf("RPU: rpu_gic_init done\r\n");
	return status;
}

/**
* Initializes the RPU IPI and enables IPI Interrupts
*
*/
u32 rpu_ipi_init(XIpiPsu *ipi_inst_ptr){
	u32 status = XST_FAILURE;
	XIpiPsu_Config *cfg_ptr;

	//Initialize IPI
	cfg_ptr = XIpiPsu_LookupConfig(XPAR_XIPIPSU_0_DEVICE_ID);
	if(cfg_ptr == NULL){
		xil_printf("RPU: Error: IPI config failed \r\n");
		return status;
	}

	//Config IPI
	status = XIpiPsu_CfgInitialize(ipi_inst_ptr, cfg_ptr, cfg_ptr->BaseAddress);
	if (status != XST_SUCCESS){
		xil_printf("RPU: Error: IPI init failed\r\n");
		return status;
	}

	//Enable IPI from PMU to RPU
	//This writes 0xF0000 to the CH1 Interrupt Enable Register
	//Enables CH3-CH6 (PMU IPI0-IPI3).
	Xil_Out32(IPI_CH1_IER, 0xF0000U);

	xil_printf("RPU: rpu_ipi_init() done\r\n");
	return status;
}


/**
* IPI handler handles interrupts from the PMU
*/
u32 rpu_ipi_handler(XIpiPsu *ipi_inst_ptr){
	u32 reg_val;
	u32 status = XST_FAILURE;
	u32 ipi_buf[8];
	u32 resp_buf[2] = {PMU_IPI_HEADER, XST_SUCCESS};

	// Check if the IPI is from PMU channel 1
	reg_val = Xil_In32(IPI_CH1_ISR);
	//xil_printf("RPU ISR: %x\r\n", reg_val);
	if((reg_val & (u32)IPI_PMU_PM_INT_MASK_RECV) == 0U){
		//xil_printf("RPU: Error: Received IPI from invalid source, ISR:%x\r\n", reg_val);
		return XST_FAILURE;
	}

	//Read the IPI payload into the buffer
	status = (u32)XIpiPsu_ReadMessage(ipi_inst_ptr, IPI_PMU_PM_INT_MASK_RECV,
			ipi_buf, IPI_MSG_LEN, XIPIPSU_BUF_TYPE_MSG);

	if(status != (u32)XST_SUCCESS){
		xil_printf("RPU: Error: IPI Payload buffer read failed\r\n");
		return XST_FAILURE;
	}

	//Check what payload it is
	if(ipi_buf[1] == IPI_BITSTREAM_HASH_MASK){
		//Read 6 byte (48 bits) hash from buffer
		//memcpy(&bitstream_hash[bitstream_hash_bytes_read], &ipi_buf[2], 16);
		//bitstream_hash_bytes_read += 16;
		xil_printf("RPU: Error - bitstream hash not supported.");
	}
	else{
		if(kernel_cert_sig_bytes_read > RSA_SIZE - 4){
			xil_printf("RPU: Error: Overflow of attestation signature buffer\r\n");
			return XST_FAILURE;
		}

		int i;

		for(i = 2; i < 6; i++){
			u32 msg_word = ipi_buf[i];
			kernel_cert_sig[kernel_cert_sig_bytes_read] = ((msg_word >> 24) & 0xff);
			kernel_cert_sig[kernel_cert_sig_bytes_read+1] = ((msg_word >> 16) & 0xff);
			kernel_cert_sig[kernel_cert_sig_bytes_read+2] = ((msg_word >> 8) & 0xff);
			kernel_cert_sig[kernel_cert_sig_bytes_read+3] = ((msg_word >> 0) & 0xff);

			kernel_cert_sig_bytes_read += 4;
		}
	}

	//Echo the command
	resp_buf[1] = ipi_buf[1];


	//Send a response to the PMU
	status = XIpiPsu_WriteMessage(ipi_inst_ptr, IPI_PMU_PM_INT_MASK_RECV, resp_buf,
			2, XIPIPSU_BUF_TYPE_RESP);
	if(status != (u32)XST_SUCCESS){
		xil_printf("RPU: Error: IPI response write failed.\r\n");
	}

	//Clear the ISR register
	Xil_Out32(IPI_CH1_ISR, (reg_val & (u32)IPI_PMU_PM_INT_MASK_RECV));

	return status;
}


/**
 * Thus function sends an IPI to the PMU.
 * msg_buf must have max length of 8.
 * resp_buf is of size 2.
 */
int send_ipi_pmu(u32* msg_buf, u32* resp_buf, u32 len){
	u32 status;

	status = XIpiPsu_WriteMessage(&ipi_inst, IPI_PMU_PM_INT_MASK_SEND,
			msg_buf, len, XIPIPSU_BUF_TYPE_MSG);

	if(status != XST_SUCCESS){
		xil_printf("RPU: Error: IPI write message failed\r\n");
		return XST_FAILURE;
	}

	status = XIpiPsu_TriggerIpi(&ipi_inst, IPI_PMU_PM_INT_MASK_SEND);

	if(status != XST_SUCCESS){
		xil_printf("RPU: Error: IPI Trigger failed\r\n");
		return XST_FAILURE;
	}

	status = XIpiPsu_PollForAck(&ipi_inst, IPI_PMU_PM_INT_MASK_SEND, (~0));

	if(status != XST_SUCCESS){
		xil_printf("RPU: Error: IPI Poll for ack failed \r\n");
		return XST_FAILURE;
	}

	//Read the reply
	status = XIpiPsu_ReadMessage(&ipi_inst, IPI_PMU_PM_INT_MASK_SEND, resp_buf,
			2U, XIPIPSU_BUF_TYPE_RESP);

	if(status != XST_SUCCESS){
		xil_printf("RPU: Error: IPI Read response failed\r\n");
		return XST_FAILURE;
	}

//	xil_printf("RPU: Response received \r\n");
//	xil_printf("RPU: IPI Response header: 0x%x\r\n", resp_buf[0]);
//	xil_printf("RPU: IPI Response status: 0x%x\r\n", resp_buf[1]);

	return XST_SUCCESS;

}

/** This function sends the kernel certificate hash to the PMUFW.
 *  Once the signature is ready, it will be sent back to the security monitor
 *  through an interrupt.
 *
 *  cert_hash: 64 byte buffer containing the hash of the kernel certificate
 */
u32 get_kernel_certificate_signature(unsigned char* cert_hash){
	u32 msg_buf[8]; //Buffer to hold message to PMUFW
	u32 resp_buf[2] = {0};
	u32 status;
	u16 bytes_sent = 0U;

	msg_buf[0] = PMU_IPI_HEADER;


	while(bytes_sent < 48){ //48 bytes in the certificate hash
		/* Each packet is formatted with the first word as the header.
		 * The next word contains the start and end index of the corresponding
		 * bytes of the certificate
		 * Finally, the next four words (word 2-5) contain the actual certificate
		 * chunk.
		 */
		u16 start_index = bytes_sent;
		u16 end_index = bytes_sent + 16U;
		msg_buf[1] = (bytes_sent << 16) | end_index;

		//Send 16 bytes of the certificate
		memcpy(&msg_buf[2], &cert_hash[bytes_sent], 16);
		bytes_sent = end_index;

		//Actually write the message
		status = send_ipi_pmu(msg_buf, resp_buf, 6); //header, indices, + 4 words.
		if (status != XST_SUCCESS){
			xil_printf("RPU:Error: failed to send attest_pk to PMU\r\n");
			return XST_FAILURE;
		}

		//Check that the expected indices match up
		if(resp_buf[1] != ((start_index << 16) | (end_index))){
			xil_printf("RPU:Error: PMU failed to ack byte indices\r\n");
			return XST_FAILURE;
		}
	}

	//Block until signature is received
	while(kernel_cert_sig_bytes_read < RSA_SIZE){
		//Spin
	}


	return 0;
}



///** This function sends the attestation PK to the PMUFW.
// *  Once the certificate is ready, it will be sent back to the security monitor
// *  through an interrupt.
// */
//u32 send_pk_pmu(unsigned char* attest_pk){
//	u32 msg_buf[8]; //Buffer to hold message to PMUFW
//	u32 resp_buf[2] = {0};
//	u32 status;
//	u16 bytes_sent = 0U;
//
//	msg_buf[0] = PMU_IPI_HEADER;
//
//
//	while(bytes_sent < 32){ //32 bytes in the attestation PK
//		/* Each packet is formatted with the first word as the header.
//		 * The next word contains the start and end index of the corresponding
//		 * bytes of the attestation PK.
//		 * Finally, the next four words (word 2-5) contain the actual attestation PK
//		 * chunk.
//		 */
//		u16 start_index = bytes_sent;
//		u16 end_index = bytes_sent + 16U;
//		msg_buf[1] = (bytes_sent << 16) | end_index;
//
//		//Send 16 bytes of the pk
//		memcpy(&msg_buf[2], &attest_pk[bytes_sent], 16);
//		bytes_sent = end_index;
//
////		int i;
////		for(i = 0; i < 4; i++){ //We can fit 4 words per message.
////
////			msg_buf[2+i] = attest_pk[bytes_sent] << 24 | attest_pk[bytes_sent + 1] << 16 |
////					attest_pk[bytes_sent + 2] << 8 | attest_pk[bytes_sent + 3];
////
////			//We just sent 4 bytes.
////			bytes_sent = bytes_sent + 4U;
////		}
//
//		//Actually write the message
//		status = send_ipi_pmu(msg_buf, resp_buf, 6); //header, indices, + 4 words.
//		if (status != XST_SUCCESS){
//			xil_printf("RPU:Error: failed to send attest_pk to PMU\r\n");
//			return XST_FAILURE;
//		}
//
//		//Check that the expected indices match up
//		if(resp_buf[1] != ((start_index << 16) | (end_index))){
//			xil_printf("RPU:Error: PMU failed to ack byte indices\r\n");
//			return XST_FAILURE;
//		}
//	}
//
//
//	return 0;
//}
//
///**
// * This function sends a command to the PMUFW to load the bitstream supplied by
// * the user. The bitstream must be loaded before this function call at address
// * bitstream_addr. The bitstream size is supplied in bytes.
// *
// */
//u32 send_load_bitstream_pmu(u8* bitstream_addr, u32 bitstream_size){
//	u32 msg_buf[8]; //Buffer to hold message to PMUFW
//	u32 resp_buf[2] = {0};
//	u32 status;
//
//
//	msg_buf[0] = PMU_IPI_HEADER; //Header for PMU_SEC module.
//
//	msg_buf[1] = FLIP_ENDIAN(IPI_BITSTREAM_HASH_MASK); //flip endian due to memcpy in pmufw
//
//	memcpy(&msg_buf[2], &bitstream_addr, 4);
//	memcpy(&msg_buf[3], &bitstream_size, 4);
//
//
//	status = send_ipi_pmu(msg_buf, resp_buf, 8);
//	if (status != XST_SUCCESS){
//		xil_printf("RPU:Error: failed to send bitstream to PMU\r\n");
//		return XST_FAILURE;
//	}
//
//	//Check that the expected indices match up
//	if(resp_buf[1] != msg_buf[1]){
//		xil_printf("RPU:Error: PMU failed to ack IPI\r\n");
//		return XST_FAILURE;
//	}
//
//	return XST_SUCCESS;
//}
//
//int test_ipi(void){
//	//Send a packet to the PMU. Expect a reply back.
//	u32 msg_buf[3] = {PMU_IPI_HEADER, 0xdeadbeef, 0xcabbac00};
//	u32 resp_buf[2] = {0};
//
//	u32 status;
//
//	status = XIpiPsu_WriteMessage(&ipi_inst, IPI_PMU_PM_INT_MASK_SEND,
//			msg_buf, 3U, XIPIPSU_BUF_TYPE_MSG);
//
//	if(status != XST_SUCCESS){
//		xil_printf("RPU: Error: IPI write message failed\r\n");
//		return -1;
//	}
//
//	status = XIpiPsu_TriggerIpi(&ipi_inst, IPI_PMU_PM_INT_MASK_SEND);
//
//	if(status != XST_SUCCESS){
//		xil_printf("RPU: Error: IPI Trigger failed\r\n");
//		return -1;
//	}
//
//	status = XIpiPsu_PollForAck(&ipi_inst, IPI_PMU_PM_INT_MASK_SEND, (~0));
//
//	if(status != XST_SUCCESS){
//		xil_printf("RPU: Error: IPI Poll for ack failed \r\n");
//		return -1;
//	}
//
//	//Read the reply
//	status = XIpiPsu_ReadMessage(&ipi_inst, IPI_PMU_PM_INT_MASK_SEND, resp_buf,
//			2U, XIPIPSU_BUF_TYPE_RESP);
//
//	if(status != XST_SUCCESS){
//		xil_printf("RPU: Error: IPI Read response failed\r\n");
//		return -1;
//	}
//
//	xil_printf("RPU: Response received \r\n");
//	xil_printf("RPU: IPI Response header: 0x%x\r\n", resp_buf[0]);
//	xil_printf("RPU: IPI Response status: 0x%x\r\n", resp_buf[1]);
//
//	return 0;
//
//}


