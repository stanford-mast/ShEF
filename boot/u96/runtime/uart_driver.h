/*
 * uart_driver.h
 *
 *  Created on: Mar 25, 2019
 *      Author: myzhao
 */

#ifndef SRC_UART_DRIVER_H_
#define SRC_UART_DRIVER_H_

#define FPGA_ADDER_BASE_ADDR	0xa0000000


#define MAX_UART_BUFFER_SIZE	255
#define UART_PACKET_HEADER_SIZE 3

#define XST_SUCCESS			0L
#define XST_FAILURE			1L

/*	Command definitions 	*/
#define UART_CMD_ACK		0x01
#define UART_CMD_SYN		0x02
#define	UART_CMD_SYNACK		0x03
#define UART_CMD_NACK		0x04
#define UART_CMD_PUSH_USER_PK 0x05
#define UART_CMD_PULL_FPGA_PK 0x06
#define UART_CMD_CALC_FPGA_SS 0x07
#define UART_CMD_PULL_FPGA_PK_SIG 0x08
#define UART_CMD_PULL_BITSTREAM_SIG 0x09
#define UART_CMD_PUSH_FPGA_DATA 0x0a
#define UART_CMD_PUSH_USER_NONCE 0x0b
#define UART_CMD_PULL_ATTESTATION 0x0c
#define UART_CMD_PUSH_BITSTREAM_KEY 0x0d

#define UART_RETURN_SUCCESS  0x00
#define UART_RETURN_FAILURE  0x01
#define UART_RETURN_PK_NONCE 0x02
#define UART_RETURN_PUSH_ATTESTATION 0x03
#define UART_RETURN_BITSTREAM_KEY 0x04


extern void outbyte(char c);
extern char inbyte();

u32 read_packet(u8* read_buf, u16 buf_len);
void write_packet(u8* packet_body, u8 cmd, u8 metadata, u8 body_len);
u32 sync_host(void);
void send_nack(void);
void send_ack(void);
void send_attestation(void);
u32 handle_uart_cmd(void);


#endif /* SRC_UART_DRIVER_H_ */
