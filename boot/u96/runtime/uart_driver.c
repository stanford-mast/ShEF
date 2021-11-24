/*
 * uart_driver.c
 *
 *  Created on: Mar 25, 2019
 *      Author: myzhao
 */


#include <stdio.h>
#include <stdlib.h>
#include "platform.h"
#include "xil_printf.h"
#include "sleep.h"
#include "uart_driver.h"
#include "kernel_driver.h"


static u8 user_pk_received = 0;
static u8 user_nonce_received = 0;


/**
 * UART packet is formatted as follows:
 *
 * | COMMAND | METADATA   |PACKET_LEN | BODY
 * | 1 byte  | 1 byte     | 1 byte	  | PACKET_LEN-3 bytes (up to MAX_UART_BUFFER_SIZE)
 *
 * Returns how many bytes were read into read_buf (byte buffer of length buf_len).
 */
u32 read_packet(u8* read_buf, u16 buf_len){
	u16 i;
	u8 tmp;
	u8 packet_cmd;
	u8 metadata;
	u16 packet_len;

	//Read a packet from the UART terminal.

	//Read header
	packet_cmd = inbyte();
	metadata = inbyte();
	packet_len = inbyte();


	if(packet_len > buf_len){
		return 0;
	}

	//Copy packet into read buffer
	read_buf[0] = packet_cmd;
	read_buf[1] = metadata;
	read_buf[2] = packet_len & 0xff;
	for(i = UART_PACKET_HEADER_SIZE; i < packet_len; i++){
		tmp = inbyte();
		read_buf[i] = tmp;
	}

	return packet_len;
}

/**
 * Writes a packet out through UART from write_buf, where the packet
 * is packet_len long
 *
 * | COMMAND | METADATA   | PACKET_LEN | BODY
 * | 1 byte  | 1 byte     | 1 byte     | PACKET_LEN-3 bytes (up to MAX_UART_BUFFER_SIZE)
 *
 */
void write_packet(u8* packet_body, u8 cmd, u8 metadata, u8 body_len){
	u16 i;
	u16 packet_len = body_len + 3;

	if(packet_len > MAX_UART_BUFFER_SIZE){
		return;
	}
	outbyte(cmd);
	outbyte(metadata);
	outbyte(packet_len & 0xff);
	for(i = 0; i < body_len; i++){
		outbyte(packet_body[i]);
	}
}

/**
 * This function synchronizes with the host.
 *
 * Waits for a SYN command. Replies with a SYN_ACK. Returns once ACK is received
 */
u32 sync_host(void){
	u8 read_buf[32];
	u8 write_buf[32];
	u16 read_len;

	//Block until a SYN command is received
	read_len = read_packet(read_buf, 32);

	//Check if it is a SYN
	if (read_len == UART_PACKET_HEADER_SIZE && read_buf[0] == UART_CMD_SYN){
	}
	else{
		//xil_printf("RPU: Error - did not receive SYN from host\r\n");
		return XST_FAILURE;
	}

	//Reply with SYNACK
	write_packet(write_buf, UART_CMD_SYNACK, 0, 0);

	//Expect back ACK
	read_len = read_packet(read_buf, 32);
	if (read_len == UART_PACKET_HEADER_SIZE && read_buf[0] == UART_CMD_ACK){
		return XST_SUCCESS;
	}
	else{
		return XST_FAILURE;
	}
}

/**
 * Send a NACK to the user
 */
void send_nack(){
	write_packet(NULL, UART_CMD_NACK, 0, 0);
}

/**
 * Send an ACK to the user
 */
void send_ack(){
	write_packet(NULL, UART_CMD_ACK, 0, 0);
}


/**
 * Once a connection is established with a host, begin handling inputs
 * from the remote user.
 *
 * Returns flags corresponding to terminating condition
 */
u32 handle_uart_cmd(void){
	u8 read_buf[MAX_UART_BUFFER_SIZE];
	u8 write_buf[MAX_UART_BUFFER_SIZE];
	u16 read_len = 0;
	u32 i;
	u32 user_data;
	u32 tmp;

	//Pointer to AXI-lite bus on PL
	volatile unsigned int *accel = (volatile unsigned int *) FPGA_ADDER_BASE_ADDR;

	//First sync with the host if verifier has not sent pk or nonce
	if(user_pk_received == 0 && user_nonce_received == 0){
		sync_host();
	}

	//Spin and handle commands
	while(1){
		//Read input into the buffer
		read_len = read_packet(read_buf, MAX_UART_BUFFER_SIZE);

		switch(read_buf[0]){
			case UART_CMD_PUSH_USER_PK:
				//User is sending me its PK
				if(read_len != UART_PACKET_HEADER_SIZE + VERIFIER_PK_SIZE || user_pk_received == 1){
					send_nack();
				}
				else{
					//Copy the verifier's PK into memory
					unsigned char* verif_pk_ptr = (unsigned char*)(SHARED_MEM_BASE + VERIFIER_PK_OFFSET);
					memcpy(verif_pk_ptr, &read_buf[UART_PACKET_HEADER_SIZE], VERIFIER_PK_SIZE);
					send_ack();
					user_pk_received = 1;

					//Return if the nonce and verifier PK are received
					if(user_nonce_received){
						return UART_RETURN_PK_NONCE;
					}
				}
				break;

			case UART_CMD_PUSH_USER_NONCE:
				if(read_len != UART_PACKET_HEADER_SIZE + NONCE_SIZE || user_nonce_received == 1){
					send_nack();
				}
				else{
					//Copy nonce into memory
					unsigned char* verif_nonce_ptr = (unsigned char*)(SHARED_MEM_BASE + NONCE_OFFSET);
					memcpy(verif_nonce_ptr, &read_buf[UART_PACKET_HEADER_SIZE], NONCE_SIZE);
					send_ack();
					user_nonce_received = 1;

					//Return if nonce and pk are received
					if(user_pk_received){
						return UART_RETURN_PK_NONCE;
					}
				}
				break;

			case UART_CMD_PULL_ATTESTATION: ; //empty statement
				//pointer to attestation
				unsigned char* attestation_ptr = (unsigned char*)(SHARED_MEM_BASE + ATTESTATION_OFFSET);
				u32 bytes_sent = 0;

				while(bytes_sent < ATTESTATION_SIZE + SHARED_SECRET_SIG_SIZE){
					//Send in chunks of 188 bytes
					u8 bytes_to_send = 188U;
					if(bytes_sent + 188 > ATTESTATION_SIZE + SHARED_SECRET_SIG_SIZE){
						bytes_to_send = (ATTESTATION_SIZE + SHARED_SECRET_SIG_SIZE) - bytes_sent;
					}

					//Metadata contains bytes sent in words
					write_packet(&attestation_ptr[bytes_sent],
							UART_CMD_PULL_ATTESTATION,
							((bytes_sent/4) & 0xff),
							bytes_to_send);

					//Expect back an ACK
					read_packet(read_buf, MAX_UART_BUFFER_SIZE);
					if(read_buf[0] != UART_CMD_ACK){
						return UART_RETURN_FAILURE;
					}
					bytes_sent = bytes_sent + bytes_to_send;
				}


				break;

			case UART_CMD_PUSH_BITSTREAM_KEY:
				if(read_len != UART_PACKET_HEADER_SIZE + BITSTREAM_KEY_SIZE){
					send_nack();
				}
				else{
					//Copy the encrypted AES key into shared memory
					unsigned char* decryption_key_ptr = (unsigned char*)(SHARED_MEM_BASE + BITSTREAM_KEY_OFFSET);
					memcpy(decryption_key_ptr, &read_buf[UART_PACKET_HEADER_SIZE], BITSTREAM_KEY_SIZE);
					send_ack();

					//Return from the loop
					return UART_RETURN_BITSTREAM_KEY;
				}
				break;


//
//			case UART_CMD_PULL_FPGA_PK:
//				//User requests my PK
//				write_packet(attest_pk, UART_CMD_PULL_FPGA_PK, 0, 32);
//
//				//Expect back an ACK
//				read_packet(read_buf, MAX_UART_BUFFER_SIZE);
//				if(read_buf[0] != UART_CMD_ACK){
//					//TODO: Handle this...
//					break;
//				}
//				break;
//
//			case UART_CMD_CALC_FPGA_SS:
//				//Calculate my shared secret
//				if(user_pk_received == 1){
//					ed25519_key_exchange(shared_secret, user_pk, attest_sk);
//					send_ack();
//				}
//				else{
//					send_nack();
//				}
//				break;
//
//			case UART_CMD_PULL_FPGA_PK_SIG:
//				//User requests signature for my PK
//				for(i = 0; i < 4; i++){
//					write_packet(&attest_signature[i*128],
//							UART_CMD_PULL_FPGA_PK_SIG,
//							(i & 0xff),
//							128);
//
//					//Expect back an ACK
//					read_packet(read_buf, MAX_UART_BUFFER_SIZE);
//					if(read_buf[0] != UART_CMD_ACK){
//						//TODO: Handle this...
//						break;
//					}
//				}
//				break;
//			case UART_CMD_PULL_BITSTREAM_SIG:
//				//User requests signature for bitstream
//				write_packet(bitstream_signature,
//								UART_CMD_PULL_BITSTREAM_SIG,
//								0,
//								64);
//
//				//Expect back an ACK
//				read_packet(read_buf, MAX_UART_BUFFER_SIZE);
//				if(read_buf[0] != UART_CMD_ACK){
//					//TODO: Handle this..
//					break;
//				}
//
//				break;

			case UART_CMD_PUSH_FPGA_DATA:
				//Map the input buffers to the AXI bus

				user_data = read_buf[3] << 24 | read_buf[4] << 16 | read_buf[5] << 8 | read_buf[6];
				//xil_printf("%08x_ DEBUG: user_data \r\n", user_data);
				accel[1] = read_buf[3] << 24 | read_buf[4] << 16 | read_buf[5] << 8 | read_buf[6];
				accel[2] = read_buf[7] << 24 | read_buf[8] << 16 | read_buf[9] << 8 | read_buf[10];
				accel[3] = read_buf[11] << 24 | read_buf[12] << 16 | read_buf[13] << 8 | read_buf[14];
				accel[4] = read_buf[15] << 24 | read_buf[16] << 16 | read_buf[17] << 8 | read_buf[18];

				//Send an ack
				send_ack();

				sleep(1);
				//Start the accel
				accel[0] = 0x000000c1;
				sleep(1);

				//Wait for the response from the FPGA
				while(1){
					if(accel[5] == 0x60000001){
						break;
					}
				}

				//Send the data back to the host
				tmp = accel[6];
				write_buf[0] = (tmp >> 24) & 0xff;
				write_buf[1] = (tmp >> 16) & 0xff;
				write_buf[2] = (tmp >> 8)  & 0xff;
				write_buf[3] =  tmp        & 0xff;
				tmp = accel[7];
				write_buf[4] = (tmp >> 24) & 0xff;
				write_buf[5] = (tmp >> 16) & 0xff;
				write_buf[6] = (tmp >> 8)  & 0xff;
				write_buf[7] =  tmp        & 0xff;
				tmp = accel[8];
				write_buf[8] = (tmp >> 24) & 0xff;
				write_buf[9] = (tmp >> 16) & 0xff;
				write_buf[10] = (tmp >> 8)  & 0xff;
				write_buf[11] =  tmp        & 0xff;
				tmp = accel[9];
				write_buf[12] = (tmp >> 24) & 0xff;
				write_buf[13] = (tmp >> 16) & 0xff;
				write_buf[14] = (tmp >> 8)  & 0xff;
				write_buf[15] =  tmp        & 0xff;

				write_packet(write_buf, UART_CMD_PUSH_FPGA_DATA, 0, 16);
				//Expect back an ACK
				read_packet(read_buf, MAX_UART_BUFFER_SIZE);
				if(read_buf[0] != UART_CMD_ACK){
					//TODO: Handle this...
					break;
				}
				break;


			default: //send NACK
				send_nack();
		}
	}
}
