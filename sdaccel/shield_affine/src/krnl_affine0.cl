/**********
Copyright (c) 2018, Xilinx, Inc.
All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice,
this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation
and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors
may be used to endorse or promote products derived from this software
without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
**********/
#define PI     3.14159265359f
#define WHITE  0xffffffff //(short)(1)
#define BLACK  0x00000000 //(short)(0)

#define X_SIZE 512
#define Y_SIZE 512

#define BLOCK_WORD_SIZE 16
#define RAM_HEADER_SIZE 2 //Size of the ram header in words
#define BLOCK_INDEX_SHAMT 4 //convert array index to block offset (log2(block size in bytes) - log2(word size in bytes))
#define CHUNK_SIZE 80 //block size + tag size in bytes

pipe unsigned int r0 __attribute__((xcl_reqd_pipe_depth(32)));
pipe unsigned int r1 __attribute__((xcl_reqd_pipe_depth(32)));
pipe unsigned int r2 __attribute__((xcl_reqd_pipe_depth(32)));
pipe unsigned int r3 __attribute__((xcl_reqd_pipe_depth(32)));
pipe unsigned int r4 __attribute__((xcl_reqd_pipe_depth(32)));
pipe unsigned int r5 __attribute__((xcl_reqd_pipe_depth(32)));
pipe unsigned int r6 __attribute__((xcl_reqd_pipe_depth(32)));
pipe unsigned int r7 __attribute__((xcl_reqd_pipe_depth(32)));
pipe unsigned int r8 __attribute__((xcl_reqd_pipe_depth(32)));
pipe unsigned int r9 __attribute__((xcl_reqd_pipe_depth(32)));
pipe unsigned int r10 __attribute__((xcl_reqd_pipe_depth(32)));
pipe unsigned int r11 __attribute__((xcl_reqd_pipe_depth(32)));
pipe unsigned int r12 __attribute__((xcl_reqd_pipe_depth(32)));
pipe unsigned int r13 __attribute__((xcl_reqd_pipe_depth(32)));
pipe unsigned int r14 __attribute__((xcl_reqd_pipe_depth(32)));
pipe unsigned int r15 __attribute__((xcl_reqd_pipe_depth(32)));
pipe unsigned int o0 __attribute__((xcl_reqd_pipe_depth(32)));
pipe unsigned int o1 __attribute__((xcl_reqd_pipe_depth(32)));
pipe unsigned int o2 __attribute__((xcl_reqd_pipe_depth(32)));
pipe unsigned int o3 __attribute__((xcl_reqd_pipe_depth(32)));

static void send_req(unsigned int* inbuf0, unsigned int* outbuf0, unsigned int* inbuf1, unsigned int* outbuf1,
			unsigned int* inbuf2, unsigned int* outbuf2, unsigned int* inbuf3, unsigned int* outbuf3,
			unsigned int* inbuf4, unsigned int* outbuf4, unsigned int* inbuf5, unsigned int* outbuf5,
			unsigned int* inbuf6, unsigned int* outbuf6, unsigned int* inbuf7, unsigned int* outbuf7){


	unsigned int write_itr = 2;

	//Write the input command
	for(int i = 0; i < write_itr; i++){
		while(write_pipe(r0, &inbuf0[i]) != 0){}
		while(write_pipe(r2, &inbuf1[i]) != 0){}
		while(write_pipe(r4, &inbuf2[i]) != 0){}
		while(write_pipe(r6, &inbuf3[i]) != 0){}
		while(write_pipe(r8, &inbuf4[i]) != 0){}
		while(write_pipe(r10, &inbuf5[i]) != 0){}
		while(write_pipe(r12, &inbuf6[i]) != 0){}
		while(write_pipe(r14, &inbuf7[i]) != 0){}
	}
	barrier(CLK_LOCAL_MEM_FENCE);

	//Read the response - if it's a read command
	if(inbuf0[0] != 0xffffffff){
		for(int i = 0; i < BLOCK_WORD_SIZE; i++){
			unsigned int result0;
			unsigned int result1;
			unsigned int result2;
			unsigned int result3;
			unsigned int result4;
			unsigned int result5;
			unsigned int result6;
			unsigned int result7;
			read_pipe_block(r1, &result0);
			outbuf0[i] = result0;
			read_pipe_block(r3, &result1);
			outbuf1[i] = result1;
			read_pipe_block(r5, &result2);
			outbuf2[i] = result2;
			read_pipe_block(r7, &result3);
			outbuf3[i] = result3;
			read_pipe_block(r9, &result4);
			outbuf4[i] = result4;
			read_pipe_block(r11, &result5);
			outbuf5[i] = result5;
			read_pipe_block(r13, &result6);
			outbuf6[i] = result6;
			read_pipe_block(r15, &result7);
			outbuf7[i] = result7;
		}
	}

	//barrier(CLK_LOCAL_MEM_FENCE);
}
//
//static void send_req_01(unsigned int* inbuf, unsigned int* outbuf){
//	unsigned int req_addr;
//	unsigned int req_hdr;
//
//	unsigned int write_itr;
//
//	//Decide how if it's a read or write request
//	if((inbuf[0] & 0x03) == 0x01){
//		write_itr = BLOCK_WORD_SIZE + RAM_HEADER_SIZE; //total chunk size - 4 (tag) + 2 (header)
//	}
//	else{
//		write_itr = 2;
//	}
//
//	//Write the input command
//	for(int i = 0; i < write_itr; i++){
//		while(write_pipe(p0, &inbuf[i]) != 0){}
//	}
//	barrier(CLK_LOCAL_MEM_FENCE);
//
//	//Read the response - if it's a read command
//	if((inbuf[0] & 0x03) == 0x00){
//		for(int i = 0; i < BLOCK_WORD_SIZE; i++){
//			unsigned int result;
//			read_pipe_block(p1, &result);
//			outbuf[i] = result;
//		}
//	}
//	//barrier(CLK_LOCAL_MEM_FENCE);
//}
//
//
//static void send_req_23(unsigned int* inbuf, unsigned int* outbuf){
//	unsigned int req_addr;
//	unsigned int req_hdr;
//
//	unsigned int write_itr;
//
//	//Decide how if it's a read or write request
//	if((inbuf[0] & 0x03) == 0x01){
//		write_itr = BLOCK_WORD_SIZE + RAM_HEADER_SIZE; //total chunk size - 4 (tag) + 2 (header)
//	}
//	else{
//		write_itr = 2;
//	}
//
//	//Write the input command
//	for(int i = 0; i < write_itr; i++){
//		while(write_pipe(p2, &inbuf[i]) != 0){}
//	}
//	barrier(CLK_LOCAL_MEM_FENCE);
//
//	//Read the response - if it's a read command
//	if((inbuf[0] & 0x03) == 0x00){
//		for(int i = 0; i < BLOCK_WORD_SIZE; i++){
//			unsigned int result;
//			read_pipe_block(p3, &result);
//			outbuf[i] = result;
//		}
//	}
//	//barrier(CLK_LOCAL_MEM_FENCE);
//}
//
//
//
//
//static void send_req_45(unsigned int* inbuf, unsigned int* outbuf){
//	unsigned int req_addr;
//	unsigned int req_hdr;
//
//	unsigned int write_itr;
//
//	//Decide how if it's a read or write request
//	if((inbuf[0] & 0x03) == 0x01){
//		write_itr = BLOCK_WORD_SIZE + RAM_HEADER_SIZE; //total chunk size - 4 (tag) + 2 (header)
//	}
//	else{
//		write_itr = 2;
//	}
//
//	//Write the input command
//	for(int i = 0; i < write_itr; i++){
//		while(write_pipe(p4, &inbuf[i]) != 0){}
//	}
//	barrier(CLK_LOCAL_MEM_FENCE);
//
//	//Read the response - if it's a read command
//	if((inbuf[0] & 0x03) == 0x00){
//		for(int i = 0; i < BLOCK_WORD_SIZE; i++){
//			unsigned int result;
//			read_pipe_block(p5, &result);
//			outbuf[i] = result;
//		}
//	}
//	//barrier(CLK_LOCAL_MEM_FENCE);
//}
//
//
//
//
//static void send_req_67(unsigned int* inbuf, unsigned int* outbuf){
//	unsigned int req_addr;
//	unsigned int req_hdr;
//
//	unsigned int write_itr;
//
//	//Decide how if it's a read or write request
//	if((inbuf[0] & 0x03) == 0x01){
//		write_itr = BLOCK_WORD_SIZE + RAM_HEADER_SIZE; //total chunk size - 4 (tag) + 2 (header)
//	}
//	else{
//		write_itr = 2;
//	}
//
//	//Write the input command
//	for(int i = 0; i < write_itr; i++){
//		while(write_pipe(p6, &inbuf[i]) != 0){}
//	}
//	barrier(CLK_LOCAL_MEM_FENCE);
//
//	//Read the response - if it's a read command
//	if((inbuf[0] & 0x03) == 0x00){
//		for(int i = 0; i < BLOCK_WORD_SIZE; i++){
//			unsigned int result;
//			read_pipe_block(p7, &result);
//			outbuf[i] = result;
//		}
//	}
//	//barrier(CLK_LOCAL_MEM_FENCE);
//}

//void __attribute__((always_inline))write_output(unsigned int* out_lcl, unsigned int row){
//	unsigned int out_val = 0;
//
//	//Write the IV
//	if(row == 0){
//		write_pipe(p5, &out_val);
//		write_pipe(p5, &out_val);
//		write_pipe(p5, &out_val);
//	}
//
//    for(int itr = 0; itr < X_SIZE; itr++) {
//    	out_val = out_lcl[itr];
//    	write_pipe(p5, &out_val);
//        //out[stride + itr] = out_lcl[itr];
//    }
//}


void calculate_row_pixel_addresses(int y, float* x_buf, float* y_buf, float* i_beta, float* i_affine){
	int x;
	__attribute__((xcl_pipeline_loop))
	address_loop: for (x = 0; x < X_SIZE; x++){
		float x_new    = i_beta[0] + i_affine[0]*(x-X_SIZE/2.0f) + i_affine[1]*(y-Y_SIZE/2.0f) + X_SIZE/2.0f;
		float y_new    = i_beta[1] + i_affine[2]*(x-X_SIZE/2.0f) + i_affine[3]*(y-Y_SIZE/2.0f) + Y_SIZE/2.0f;
		x_buf[x] = x_new;
		y_buf[x] = y_new;
	}
}
//
//void __attribute__((always_inline))read_pixels(int m, int n, unsigned int* req_buf_01, unsigned int* resp_buf_01,
//		unsigned int* pixel_tl, unsigned int* pixel_tr){
//	if ((m >= 0) && (m + 1 < X_SIZE) && (n >= 0) && (n+1 < Y_SIZE))
//	{
//		unsigned int pixel_tl_offset = ((n * X_SIZE) + m);
//		unsigned int pixel_tl_resp_index = pixel_tl_offset % 3;
//		//unsigned int pixel_tl_index = pixel_tl_offset >> BLOCK_INDEX_SHAMT;
//		unsigned int pixel_tl_index = pixel_tl_offset / 3;
//		//Read the chunk for pixel tl
//		req_buf_01[0] = ((pixel_tl_index & 0x1ffff) << 2) | 0x00;
//		req_buf_01[1] = pixel_tl_index * CHUNK_SIZE;
//		send_req_01(req_buf_01, resp_buf_01);
//		*pixel_tl = resp_buf_01[pixel_tl_resp_index];
//
//		//if (pixel_tl_resp_index != 2){
//		*pixel_tr = resp_buf_01[pixel_tl_resp_index + 1];
//		//}
//		//else{
//			//pixel_tr = resp_buf_01[3];
////			//Read the next block for pixel tr
////			req_buf_01[0] = (((pixel_tl_index + 1) & 0xffff) << 2) | 0x00;
////			req_buf_01[1] = (pixel_tl_index + 1) * CHUNK_SIZE;
////			send_req_01(req_buf_01, resp_buf_01);
////			*pixel_tr = resp_buf_01[0];
//		//}
//	}
//	else if (((m + 1 == X_SIZE) && (n >= 0) && (n < Y_SIZE)) || ((n + 1 == Y_SIZE) && (m >= 0) && (m < X_SIZE)))
//	{
//		unsigned int pixel_offset = ((n * X_SIZE) + m);
//		//unsigned int pixel_resp_index = pixel_offset & 0xf;
//		unsigned int pixel_resp_index = pixel_offset % 3;
//		//unsigned int pixel_index = pixel_offset >> BLOCK_INDEX_SHAMT;
//		unsigned int pixel_index = pixel_offset / 3;
//		//Read the chunk for pixel tl
//		req_buf_01[0] = ((pixel_index & 0x1ffff) << 2) | 0x00;
//		req_buf_01[1] = pixel_index * CHUNK_SIZE;
//		send_req_01(req_buf_01, resp_buf_01);
//		unsigned int pixel = resp_buf_01[pixel_resp_index];
//
//		*pixel_tl = pixel;
//		*pixel_tr = pixel;
//	}
//	else{
//		*pixel_tl = WHITE;
//		*pixel_tr = WHITE;
//	}
//}
//
//
//void __attribute__((always_inline))read_pixel_p01(int m, int n, unsigned int* req_buf_01, unsigned int* resp_buf_01,
//		unsigned int* pixel_tl, unsigned int* pixel_tr){
//	if ((m >= 0) && (m + 1 < X_SIZE) && (n >= 0) && (n+1 < Y_SIZE))
//	{
//		unsigned int pixel_tl_offset = ((n * X_SIZE) + m);
//		unsigned int pixel_tl_resp_index = pixel_tl_offset % 3;
//		//unsigned int pixel_tl_index = pixel_tl_offset >> BLOCK_INDEX_SHAMT;
//		unsigned int pixel_tl_index = pixel_tl_offset / 3;
//		//Read the chunk for pixel tl
//		req_buf_01[0] = ((pixel_tl_index & 0x1ffff) << 2) | 0x00;
//		req_buf_01[1] = pixel_tl_index * CHUNK_SIZE;
//		send_req_01(req_buf_01, resp_buf_01);
//		*pixel_tl = resp_buf_01[pixel_tl_resp_index];
//
//		//if (pixel_tl_resp_index != 2){
//		*pixel_tr = resp_buf_01[pixel_tl_resp_index + 1];
//		//}
//		//else{
//			//pixel_tr = resp_buf_01[3];
////			//Read the next block for pixel tr
////			req_buf_01[0] = (((pixel_tl_index + 1) & 0xffff) << 2) | 0x00;
////			req_buf_01[1] = (pixel_tl_index + 1) * CHUNK_SIZE;
////			send_req_01(req_buf_01, resp_buf_01);
////			*pixel_tr = resp_buf_01[0];
//		//}
//	}
//	else if (((m + 1 == X_SIZE) && (n >= 0) && (n < Y_SIZE)) || ((n + 1 == Y_SIZE) && (m >= 0) && (m < X_SIZE)))
//	{
//		unsigned int pixel_offset = ((n * X_SIZE) + m);
//		//unsigned int pixel_resp_index = pixel_offset & 0xf;
//		unsigned int pixel_resp_index = pixel_offset % 3;
//		//unsigned int pixel_index = pixel_offset >> BLOCK_INDEX_SHAMT;
//		unsigned int pixel_index = pixel_offset / 3;
//		//Read the chunk for pixel tl
//		req_buf_01[0] = ((pixel_index & 0x1ffff) << 2) | 0x00;
//		req_buf_01[1] = pixel_index * CHUNK_SIZE;
//		send_req_01(req_buf_01, resp_buf_01);
//		unsigned int pixel = resp_buf_01[pixel_resp_index];
//
//		*pixel_tl = pixel;
//		*pixel_tr = pixel;
//	}
//	else{
//		*pixel_tl = WHITE;
//		*pixel_tr = WHITE;
//	}
//}
//
//
//void __attribute__((always_inline))read_pixel_p23(int m, int n, unsigned int* req_buf_23, unsigned int* resp_buf_23,
//		unsigned int* pixel_bl, unsigned int* pixel_br){
////Get the next row
//	if ((m >= 0) && (m + 1 < X_SIZE) && (n >= 0) && (n+1 < Y_SIZE)){
//		unsigned int pixel_bl_offset = ((n + 1) * X_SIZE) + m; //Read BL
//		unsigned int pixel_bl_resp_index = pixel_bl_offset % 3;
//		unsigned int pixel_bl_index = pixel_bl_offset / 3; //pixel_bl_offset >> BLOCK_INDEX_SHAMT;
//		req_buf_23[0] = ((pixel_bl_index & 0x1ffff) << 2) | 0x00;
//		req_buf_23[1] = pixel_bl_index * CHUNK_SIZE;
//		send_req_23(req_buf_23, resp_buf_23);
//		*pixel_bl = resp_buf_23[pixel_bl_resp_index];
//		*pixel_br = resp_buf_23[pixel_bl_resp_index + 1];
//
//
//	}
//	else if (((m + 1 == X_SIZE) && (n >= 0) && (n < Y_SIZE)) || ((n + 1 == Y_SIZE) && (m >= 0) && (m < X_SIZE)))
//	{
//		unsigned int pixel_offset = ((n * X_SIZE) + m); //read TL, not BL
//		unsigned int pixel_resp_index = pixel_offset % 3;
//		unsigned int pixel_index = pixel_offset / 3;
//		//Read the chunk for pixel tl
//		req_buf_23[0] = ((pixel_index & 0x1ffff) << 2) | 0x00;
//		req_buf_23[1] = pixel_index * CHUNK_SIZE;
//		send_req_23(req_buf_23, resp_buf_23);
//		unsigned int pixel = resp_buf_23[pixel_resp_index];
//
//		*pixel_bl = pixel;
//		*pixel_br = pixel;
//	}
//	else{
//		*pixel_bl = WHITE;
//		*pixel_br = WHITE;
//	}
//}
//
//
//void __attribute__((always_inline))read_pixel_p45(int m, int n, unsigned int* req_buf, unsigned int* resp_buf,
//		unsigned int* pixel_tl, unsigned int* pixel_tr){
//	if ((m >= 0) && (m + 1 < X_SIZE) && (n >= 0) && (n+1 < Y_SIZE))
//	{
//		unsigned int pixel_tl_offset = ((n * X_SIZE) + m);
//		unsigned int pixel_tl_resp_index = pixel_tl_offset % 3;
//		//unsigned int pixel_tl_index = pixel_tl_offset >> BLOCK_INDEX_SHAMT;
//		unsigned int pixel_tl_index = pixel_tl_offset / 3;
//		//Read the chunk for pixel tl
//		req_buf[0] = ((pixel_tl_index & 0x1ffff) << 2) | 0x00;
//		req_buf[1] = pixel_tl_index * CHUNK_SIZE;
//		send_req_45(req_buf, resp_buf);
//		*pixel_tl = resp_buf[pixel_tl_resp_index];
//
//		//if (pixel_tl_resp_index != 2){
//		*pixel_tr = resp_buf[pixel_tl_resp_index + 1];
//		//}
//		//else{
//			//pixel_tr = resp_buf_01[3];
////			//Read the next block for pixel tr
////			req_buf_01[0] = (((pixel_tl_index + 1) & 0xffff) << 2) | 0x00;
////			req_buf_01[1] = (pixel_tl_index + 1) * CHUNK_SIZE;
////			send_req_01(req_buf_01, resp_buf_01);
////			*pixel_tr = resp_buf_01[0];
//		//}
//	}
//	else if (((m + 1 == X_SIZE) && (n >= 0) && (n < Y_SIZE)) || ((n + 1 == Y_SIZE) && (m >= 0) && (m < X_SIZE)))
//	{
//		unsigned int pixel_offset = ((n * X_SIZE) + m);
//		//unsigned int pixel_resp_index = pixel_offset & 0xf;
//		unsigned int pixel_resp_index = pixel_offset % 3;
//		//unsigned int pixel_index = pixel_offset >> BLOCK_INDEX_SHAMT;
//		unsigned int pixel_index = pixel_offset / 3;
//		//Read the chunk for pixel tl
//		req_buf[0] = ((pixel_index & 0x1ffff) << 2) | 0x00;
//		req_buf[1] = pixel_index * CHUNK_SIZE;
//		send_req_45(req_buf, resp_buf);
//		unsigned int pixel = resp_buf[pixel_resp_index];
//
//		*pixel_tl = pixel;
//		*pixel_tr = pixel;
//	}
//	else{
//		*pixel_tl = WHITE;
//		*pixel_tr = WHITE;
//	}
//}
//
//
//void __attribute__((always_inline))read_pixel_p67(int m, int n, unsigned int* req_buf, unsigned int* resp_buf,
//		unsigned int* pixel_bl, unsigned int* pixel_br){
////Get the next row
//	if ((m >= 0) && (m + 1 < X_SIZE) && (n >= 0) && (n+1 < Y_SIZE)){
//		unsigned int pixel_bl_offset = ((n + 1) * X_SIZE) + m; //Read BL
//		unsigned int pixel_bl_resp_index = pixel_bl_offset % 3;
//		unsigned int pixel_bl_index = pixel_bl_offset / 3; //pixel_bl_offset >> BLOCK_INDEX_SHAMT;
//		req_buf[0] = ((pixel_bl_index & 0x1ffff) << 2) | 0x00;
//		req_buf[1] = pixel_bl_index * CHUNK_SIZE;
//		send_req_67(req_buf, resp_buf);
//		*pixel_bl = resp_buf[pixel_bl_resp_index];
//		*pixel_br = resp_buf[pixel_bl_resp_index + 1];
//
//
//	}
//	else if (((m + 1 == X_SIZE) && (n >= 0) && (n < Y_SIZE)) || ((n + 1 == Y_SIZE) && (m >= 0) && (m < X_SIZE)))
//	{
//		unsigned int pixel_offset = ((n * X_SIZE) + m); //read TL, not BL
//		unsigned int pixel_resp_index = pixel_offset % 3;
//		unsigned int pixel_index = pixel_offset / 3;
//		//Read the chunk for pixel tl
//		req_buf[0] = ((pixel_index & 0x1ffff) << 2) | 0x00;
//		req_buf[1] = pixel_index * CHUNK_SIZE;
//		send_req_67(req_buf, resp_buf);
//		unsigned int pixel = resp_buf[pixel_resp_index];
//
//		*pixel_bl = pixel;
//		*pixel_br = pixel;
//	}
//	else{
//		*pixel_bl = WHITE;
//		*pixel_br = WHITE;
//	}
//}

void __attribute__((always_inline)) prepare_buffer(int pixel_offset, unsigned int* req_buf){
	unsigned int pixel_index = pixel_offset / 3;
	//unsigned int pixel_tl_index = pixel_tl_offset >> BLOCK_INDEX_SHAMT;

	//Read the chunk for pixel tl
	req_buf[0] = ((pixel_index & 0x1ffff) << 2) | 0x00;
	req_buf[1] = pixel_index * CHUNK_SIZE;
}

//__attribute__((xcl_dataflow))
void read_row_pixels( float* x_addr, float* y_addr, float* x_frac, float* y_frac, unsigned int* row_buffer){
	int i;
	int j;

	__attribute__((xcl_pipeline_loop))
		read_loop: for( i = 0; i < X_SIZE; i = i + 4){
			float x0_new = x_addr[i];
			float y0_new = y_addr[i];
			float x1_new = x_addr[i+1];
			float y1_new = y_addr[i+1];
			float x2_new = x_addr[i+2];
			float y2_new = y_addr[i+2];
			float x3_new = x_addr[i+3];
			float y3_new = y_addr[i+3];

			//These are the first pixels
			//Pixel 0, top left coord
			int m0t = (int)floor(x0_new);
			int n0t = (int)floor(y0_new);

			//Pixel 1, top left coord
			int m1t = (int)floor(x1_new);
			int n1t = (int)floor(y1_new);
			int m2t = (int)floor(x2_new);
			int n2t = (int)floor(y2_new);
			int m3t = (int)floor(x3_new);
			int n3t = (int)floor(y3_new);

			x_frac[i] = x0_new - m0t;
			y_frac[i] = y0_new - n0t;
			x_frac[i+1] = x1_new - m1t;
			y_frac[i+1] = y1_new - n1t;
			x_frac[i+2] = x2_new - m2t;
			y_frac[i+2] = y2_new - n2t;
			x_frac[i+3] = x3_new - m3t;
			y_frac[i+3] = y3_new - n3t;

			//Pixel 0, bottom left coord
			int m0b;
			int n0b;
			//Pozel 1, bottom left
			int m1b;
			int n1b;
			int m2b;
			int n2b;
			int m3b;
			int n3b;

			if ((m0t >= 0) && (m0t + 1 < X_SIZE) && (n0t >= 0) && (n0t+1 < Y_SIZE)){
				m0b = m0t;
				n0b = n0t + 1;
			}
			else if (((m0t + 1 == X_SIZE) && (n0t >= 0) && (n0t < Y_SIZE)) || ((n0t + 1 == Y_SIZE) && (m0t >= 0) && (m0t < X_SIZE)))
			{
				m0b = m0t;
				n0b = n0t;
			}
			else{
				m0b = 0;
				n0b = 0;
				m0t = 0;
				n0t = 0;
			}

			if ((m1t >= 0) && (m1t + 1 < X_SIZE) && (n1t >= 0) && (n1t+1 < Y_SIZE)){
				m1b = m1t;
				n1b = n1t + 1;
			}
			else if (((m1t + 1 == X_SIZE) && (n1t >= 0) && (n1t < Y_SIZE)) || ((n1t + 1 == Y_SIZE) && (m1t >= 0) && (m1t < X_SIZE)))
			{
				m1b = m1t;
				n1b = n1t;
			}
			else{
				m1b = 0;
				n1b = 0;
				m1t = 0;
				n1t = 0;
			}

			if ((m2t >= 0) && (m2t + 1 < X_SIZE) && (n2t >= 0) && (n2t+1 < Y_SIZE)){
				m2b = m2t;
				n2b = n2t + 1;
			}
			else if (((m2t + 1 == X_SIZE) && (n2t >= 0) && (n2t < Y_SIZE)) || ((n2t + 1 == Y_SIZE) && (m2t >= 0) && (m2t < X_SIZE)))
			{
				m2b = m2t;
				n2b = n2t;
			}
			else{
				m2b = 0;
				n2b = 0;
				m2t = 0;
				n2t = 0;
			}

			if ((m3t >= 0) && (m3t + 1 < X_SIZE) && (n3t >= 0) && (n3t+1 < Y_SIZE)){
				m3b = m3t;
				n3b = n3t + 1;
			}
			else if (((m3t + 1 == X_SIZE) && (n3t >= 0) && (n3t < Y_SIZE)) || ((n3t + 1 == Y_SIZE) && (m3t >= 0) && (m3t < X_SIZE)))
			{
				m3b = m3t;
				n3b = n3t;
			}
			else{
				m3b = 0;
				n3b = 0;
				m3t = 0;
				n3t = 0;
			}

			unsigned int pixel0t_offset = ((n0t * X_SIZE) + m0t);
			unsigned int pixel0b_offset = ((n0b * X_SIZE) + m0b);
			unsigned int pixel1t_offset = ((n1t * X_SIZE) + m1t);
			unsigned int pixel1b_offset = ((n1b * X_SIZE) + m1b);
			unsigned int pixel0t_index = pixel0t_offset % 3;
			unsigned int pixel0b_index = pixel0b_offset % 3;
			unsigned int pixel1t_index = pixel1t_offset % 3;
			unsigned int pixel1b_index = pixel1b_offset % 3;

			unsigned int pixel2t_offset = ((n2t * X_SIZE) + m2t);
			unsigned int pixel2b_offset = ((n2b * X_SIZE) + m2b);
			unsigned int pixel3t_offset = ((n3t * X_SIZE) + m3t);
			unsigned int pixel3b_offset = ((n3b * X_SIZE) + m3b);
			unsigned int pixel2t_index = pixel2t_offset % 3;
			unsigned int pixel2b_index = pixel2b_offset % 3;
			unsigned int pixel3t_index = pixel3t_offset % 3;
			unsigned int pixel3b_index = pixel3b_offset % 3;




			unsigned int resp_buf_01[BLOCK_WORD_SIZE] __attribute__((xcl_array_partition(complete, 1)));
			unsigned int req_buf_01[RAM_HEADER_SIZE];
			unsigned int resp_buf_23[BLOCK_WORD_SIZE] __attribute__((xcl_array_partition(complete, 1)));
			unsigned int req_buf_23[RAM_HEADER_SIZE];
			unsigned int resp_buf_45[BLOCK_WORD_SIZE] __attribute__((xcl_array_partition(complete, 1)));
			unsigned int req_buf_45[RAM_HEADER_SIZE];
			unsigned int resp_buf_67[BLOCK_WORD_SIZE] __attribute__((xcl_array_partition(complete, 1)));
			unsigned int req_buf_67[RAM_HEADER_SIZE];
			unsigned int resp_buf_89[BLOCK_WORD_SIZE] __attribute__((xcl_array_partition(complete, 1)));
			unsigned int req_buf_89[RAM_HEADER_SIZE];
			unsigned int resp_buf_1011[BLOCK_WORD_SIZE] __attribute__((xcl_array_partition(complete, 1)));
			unsigned int req_buf_1011[RAM_HEADER_SIZE];
			unsigned int resp_buf_1213[BLOCK_WORD_SIZE] __attribute__((xcl_array_partition(complete, 1)));
			unsigned int req_buf_1213[RAM_HEADER_SIZE];
			unsigned int resp_buf_1415[BLOCK_WORD_SIZE] __attribute__((xcl_array_partition(complete, 1)));
			unsigned int req_buf_1415[RAM_HEADER_SIZE];

			prepare_buffer(pixel0t_offset, req_buf_01);
			prepare_buffer(pixel0b_offset, req_buf_23);
			prepare_buffer(pixel1t_offset, req_buf_45);
			prepare_buffer(pixel1b_offset, req_buf_67);
			prepare_buffer(pixel2t_offset, req_buf_89);
			prepare_buffer(pixel2b_offset, req_buf_1011);
			prepare_buffer(pixel3t_offset, req_buf_1213);
			prepare_buffer(pixel3b_offset, req_buf_1415);

			send_req(req_buf_01, resp_buf_01, req_buf_23, resp_buf_23,
					req_buf_45, resp_buf_45, req_buf_67, resp_buf_67,
					req_buf_89, resp_buf_89, req_buf_1011, resp_buf_1011,
					req_buf_1213, resp_buf_1213, req_buf_1415, resp_buf_1415);

			unsigned int pixel0_tl_img0 = resp_buf_01[pixel0t_index];
			unsigned int pixel0_tr_img0 = resp_buf_01[pixel0t_index + 1];
			unsigned int pixel0_bl_img0 = resp_buf_23[pixel0b_index];
			unsigned int pixel0_br_img0 = resp_buf_23[pixel0b_index + 1];
			unsigned int pixel1_tl_img0 = resp_buf_45[pixel1t_index];
			unsigned int pixel1_tr_img0 = resp_buf_45[pixel1t_index + 1];
			unsigned int pixel1_bl_img0 = resp_buf_67[pixel1b_index];
			unsigned int pixel1_br_img0 = resp_buf_67[pixel1b_index + 1];
			unsigned int pixel2_tl_img0 = resp_buf_89[pixel2t_index];
			unsigned int pixel2_tr_img0 = resp_buf_89[pixel2t_index + 1];
			unsigned int pixel2_bl_img0 = resp_buf_1011[pixel2b_index];
			unsigned int pixel2_br_img0 = resp_buf_1011[pixel2b_index + 1];
			unsigned int pixel3_tl_img0 = resp_buf_1213[pixel3t_index];
			unsigned int pixel3_tr_img0 = resp_buf_1213[pixel3t_index + 1];
			unsigned int pixel3_bl_img0 = resp_buf_1415[pixel3b_index];
			unsigned int pixel3_br_img0 = resp_buf_1415[pixel3b_index + 1];

			unsigned int pixel0_tl_img1 =   resp_buf_01[pixel0t_index + 4];
			unsigned int pixel0_tr_img1 =   resp_buf_01[pixel0t_index + 5];
			unsigned int pixel0_bl_img1 =   resp_buf_23[pixel0b_index + 4];
			unsigned int pixel0_br_img1 =   resp_buf_23[pixel0b_index + 5];
			unsigned int pixel1_tl_img1 =   resp_buf_45[pixel1t_index + 4];
			unsigned int pixel1_tr_img1 =   resp_buf_45[pixel1t_index + 5];
			unsigned int pixel1_bl_img1 =   resp_buf_67[pixel1b_index + 4];
			unsigned int pixel1_br_img1 =   resp_buf_67[pixel1b_index + 5];
			unsigned int pixel2_tl_img1 =   resp_buf_89[pixel2t_index + 4];
			unsigned int pixel2_tr_img1 =   resp_buf_89[pixel2t_index + 5];
			unsigned int pixel2_bl_img1 = resp_buf_1011[pixel2b_index + 4];
			unsigned int pixel2_br_img1 = resp_buf_1011[pixel2b_index + 5];
			unsigned int pixel3_tl_img1 = resp_buf_1213[pixel3t_index + 4];
			unsigned int pixel3_tr_img1 = resp_buf_1213[pixel3t_index + 5];
			unsigned int pixel3_bl_img1 = resp_buf_1415[pixel3b_index + 4];
			unsigned int pixel3_br_img1 = resp_buf_1415[pixel3b_index + 5];

			unsigned int pixel0_tl_img2 =   resp_buf_01[pixel0t_index + 8];
			unsigned int pixel0_tr_img2 =   resp_buf_01[pixel0t_index + 9];
			unsigned int pixel0_bl_img2 =   resp_buf_23[pixel0b_index + 8];
			unsigned int pixel0_br_img2 =   resp_buf_23[pixel0b_index + 9];
			unsigned int pixel1_tl_img2 =   resp_buf_45[pixel1t_index + 8];
			unsigned int pixel1_tr_img2 =   resp_buf_45[pixel1t_index + 9];
			unsigned int pixel1_bl_img2 =   resp_buf_67[pixel1b_index + 8];
			unsigned int pixel1_br_img2 =   resp_buf_67[pixel1b_index + 9];
			unsigned int pixel2_tl_img2 =   resp_buf_89[pixel2t_index + 8];
			unsigned int pixel2_tr_img2 =   resp_buf_89[pixel2t_index + 9];
			unsigned int pixel2_bl_img2 = resp_buf_1011[pixel2b_index + 8];
			unsigned int pixel2_br_img2 = resp_buf_1011[pixel2b_index + 9];
			unsigned int pixel3_tl_img2 = resp_buf_1213[pixel3t_index + 8];
			unsigned int pixel3_tr_img2 = resp_buf_1213[pixel3t_index + 9];
			unsigned int pixel3_bl_img2 = resp_buf_1415[pixel3b_index + 8];
			unsigned int pixel3_br_img2 = resp_buf_1415[pixel3b_index + 9];

			unsigned int pixel0_tl_img3 =   resp_buf_01[pixel0t_index + 12];
			unsigned int pixel0_tr_img3 =   resp_buf_01[pixel0t_index + 13];
			unsigned int pixel0_bl_img3 =   resp_buf_23[pixel0b_index + 12];
			unsigned int pixel0_br_img3 =   resp_buf_23[pixel0b_index + 13];
			unsigned int pixel1_tl_img3 =   resp_buf_45[pixel1t_index + 12];
			unsigned int pixel1_tr_img3 =   resp_buf_45[pixel1t_index + 13];
			unsigned int pixel1_bl_img3 =   resp_buf_67[pixel1b_index + 12];
			unsigned int pixel1_br_img3 =   resp_buf_67[pixel1b_index + 13];
			unsigned int pixel2_tl_img3 =   resp_buf_89[pixel2t_index + 12];
			unsigned int pixel2_tr_img3 =   resp_buf_89[pixel2t_index + 13];
			unsigned int pixel2_bl_img3 = resp_buf_1011[pixel2b_index + 12];
			unsigned int pixel2_br_img3 = resp_buf_1011[pixel2b_index + 13];
			unsigned int pixel3_tl_img3 = resp_buf_1213[pixel3t_index + 12];
			unsigned int pixel3_tr_img3 = resp_buf_1213[pixel3t_index + 13];
			unsigned int pixel3_bl_img3 = resp_buf_1415[pixel3b_index + 12];
			unsigned int pixel3_br_img3 = resp_buf_1415[pixel3b_index + 13];

			row_buffer[i*16]      = pixel0_tl_img0;
			row_buffer[i*16 + 1]  = pixel0_tr_img0;
			row_buffer[i*16 + 2]  = pixel0_bl_img0;
			row_buffer[i*16 + 3]  = pixel0_br_img0;
			row_buffer[i*16 + 4]  = pixel1_tl_img0;
			row_buffer[i*16 + 5]  = pixel1_tr_img0;
			row_buffer[i*16 + 6]  = pixel1_bl_img0;
			row_buffer[i*16 + 7]  = pixel1_br_img0;
			row_buffer[i*16 + 8]  = pixel2_tl_img0;
			row_buffer[i*16 + 9]  = pixel2_tr_img0;
			row_buffer[i*16 + 10] = pixel2_bl_img0;
			row_buffer[i*16 + 11] = pixel2_br_img0;
			row_buffer[i*16 + 12] = pixel3_tl_img0;
			row_buffer[i*16 + 13] = pixel3_tr_img0;
			row_buffer[i*16 + 14] = pixel3_bl_img0;
			row_buffer[i*16 + 15] = pixel3_br_img0;

			row_buffer[i*16 + 16] = pixel0_tl_img1;
			row_buffer[i*16 + 17] = pixel0_tr_img1;
			row_buffer[i*16 + 18] = pixel0_bl_img1;
			row_buffer[i*16 + 19] = pixel0_br_img1;
			row_buffer[i*16 + 20] = pixel1_tl_img1;
			row_buffer[i*16 + 21] = pixel1_tr_img1;
			row_buffer[i*16 + 22] = pixel1_bl_img1;
			row_buffer[i*16 + 23] = pixel1_br_img1;
			row_buffer[i*16 + 24] = pixel2_tl_img1;
			row_buffer[i*16 + 25] = pixel2_tr_img1;
			row_buffer[i*16 + 26] = pixel2_bl_img1;
			row_buffer[i*16 + 27] = pixel2_br_img1;
			row_buffer[i*16 + 28] = pixel3_tl_img1;
			row_buffer[i*16 + 29] = pixel3_tr_img1;
			row_buffer[i*16 + 30] = pixel3_bl_img1;
			row_buffer[i*16 + 31] = pixel3_br_img1;

			row_buffer[i*16 + 32] = pixel0_tl_img2;
			row_buffer[i*16 + 33] = pixel0_tr_img2;
			row_buffer[i*16 + 34] = pixel0_bl_img2;
			row_buffer[i*16 + 35] = pixel0_br_img2;
			row_buffer[i*16 + 36] = pixel1_tl_img2;
			row_buffer[i*16 + 37] = pixel1_tr_img2;
			row_buffer[i*16 + 38] = pixel1_bl_img2;
			row_buffer[i*16 + 39] = pixel1_br_img2;
			row_buffer[i*16 + 40] = pixel2_tl_img2;
			row_buffer[i*16 + 41] = pixel2_tr_img2;
			row_buffer[i*16 + 42] = pixel2_bl_img2;
			row_buffer[i*16 + 43] = pixel2_br_img2;
			row_buffer[i*16 + 44] = pixel3_tl_img2;
			row_buffer[i*16 + 45] = pixel3_tr_img2;
			row_buffer[i*16 + 46] = pixel3_bl_img2;
			row_buffer[i*16 + 47] = pixel3_br_img2;

			row_buffer[i*16 + 48] = pixel0_tl_img3;
			row_buffer[i*16 + 49] = pixel0_tr_img3;
			row_buffer[i*16 + 50] = pixel0_bl_img3;
			row_buffer[i*16 + 51] = pixel0_br_img3;
			row_buffer[i*16 + 52] = pixel1_tl_img3;
			row_buffer[i*16 + 53] = pixel1_tr_img3;
			row_buffer[i*16 + 54] = pixel1_bl_img3;
			row_buffer[i*16 + 55] = pixel1_br_img3;
			row_buffer[i*16 + 56] = pixel2_tl_img3;
			row_buffer[i*16 + 57] = pixel2_tr_img3;
			row_buffer[i*16 + 58] = pixel2_bl_img3;
			row_buffer[i*16 + 59] = pixel2_br_img3;
			row_buffer[i*16 + 60] = pixel3_tl_img3;
			row_buffer[i*16 + 61] = pixel3_tr_img3;
			row_buffer[i*16 + 62] = pixel3_bl_img3;
			row_buffer[i*16 + 63] = pixel3_br_img3;
		}
}

void calculate_row_pixels(float* frac_x, float* frac_y, unsigned int* row_buffer, 
										unsigned int* output_buffer_img0, unsigned int* output_buffer_img1, 
										unsigned int* output_buffer_img2, unsigned int* output_buffer_img3){
	int i;
	__attribute__((xcl_pipeline_loop))
	calc_loop: for( i = 0; i < X_SIZE; i++){
		float x_frac = frac_x[i];
		float y_frac = frac_y[i];

		unsigned int pixel_tl_img0 = row_buffer[i*16    ];
		unsigned int pixel_tr_img0 = row_buffer[i*16 + 1];
		unsigned int pixel_bl_img0 = row_buffer[i*16 + 2];
		unsigned int pixel_br_img0 = row_buffer[i*16 + 3];
		unsigned int pixel_tl_img1 = row_buffer[i*16 + 4];
		unsigned int pixel_tr_img1 = row_buffer[i*16 + 5];
		unsigned int pixel_bl_img1 = row_buffer[i*16 + 6];
		unsigned int pixel_br_img1 = row_buffer[i*16 + 7];
		unsigned int pixel_tl_img2 = row_buffer[i*16 + 8];
		unsigned int pixel_tr_img2 = row_buffer[i*16 + 9];
		unsigned int pixel_bl_img2 = row_buffer[i*16 + 10];
		unsigned int pixel_br_img2 = row_buffer[i*16 + 11];
		unsigned int pixel_tl_img3 = row_buffer[i*16 + 12];
		unsigned int pixel_tr_img3 = row_buffer[i*16 + 13];
		unsigned int pixel_bl_img3 = row_buffer[i*16 + 14];
		unsigned int pixel_br_img3 = row_buffer[i*16 + 15];


		unsigned int pixel_img0;
		unsigned int pixel_img1;
		unsigned int pixel_img2;
		unsigned int pixel_img3;

		if (pixel_tl_img0 == pixel_tr_img0 && pixel_tr_img0 == pixel_bl_img0 && pixel_bl_img0 == pixel_br_img0){
			pixel_img0 = pixel_tl_img0;
			pixel_img1 = pixel_tl_img1;
			pixel_img2 = pixel_tl_img2;
			pixel_img3 = pixel_tl_img3;
		}
		else{

			unsigned char pixel_tl_r_img0 = (pixel_tl_img0 >> 24) & 0xff;
			unsigned char pixel_tl_g_img0 = (pixel_tl_img0 >> 16) & 0xff;
			unsigned char pixel_tl_b_img0 = (pixel_tl_img0 >> 8) & 0xff;
			unsigned char pixel_tl_a_img0 = (pixel_tl_img0 & 0xff);
			unsigned char pixel_tr_r_img0 = (pixel_tr_img0 >> 24) & 0xff;
			unsigned char pixel_tr_g_img0 = (pixel_tr_img0 >> 16) & 0xff;
			unsigned char pixel_tr_b_img0 = (pixel_tr_img0 >> 8) & 0xff;
			unsigned char pixel_tr_a_img0 = (pixel_tr_img0 & 0xff);
			unsigned char pixel_bl_r_img0 = (pixel_bl_img0 >> 24) & 0xff;
			unsigned char pixel_bl_g_img0 = (pixel_bl_img0 >> 16) & 0xff;
			unsigned char pixel_bl_b_img0 = (pixel_bl_img0 >> 8) & 0xff;
			unsigned char pixel_bl_a_img0 = (pixel_bl_img0 & 0xff);
			unsigned char pixel_br_r_img0 = (pixel_br_img0 >> 24) & 0xff;
			unsigned char pixel_br_g_img0 = (pixel_br_img0 >> 16) & 0xff;
			unsigned char pixel_br_b_img0 = (pixel_br_img0 >> 8) & 0xff;
			unsigned char pixel_br_a_img0 = (pixel_br_img0 & 0xff);
			unsigned char pixel_tl_r_img1 = (pixel_tl_img1 >> 24) & 0xff;
			unsigned char pixel_tl_g_img1 = (pixel_tl_img1 >> 16) & 0xff;
			unsigned char pixel_tl_b_img1 = (pixel_tl_img1 >> 8) & 0xff;
			unsigned char pixel_tl_a_img1 = (pixel_tl_img1 & 0xff);
			unsigned char pixel_tr_r_img1 = (pixel_tr_img1 >> 24) & 0xff;
			unsigned char pixel_tr_g_img1 = (pixel_tr_img1 >> 16) & 0xff;
			unsigned char pixel_tr_b_img1 = (pixel_tr_img1 >> 8) & 0xff;
			unsigned char pixel_tr_a_img1 = (pixel_tr_img1 & 0xff);
			unsigned char pixel_bl_r_img1 = (pixel_bl_img1 >> 24) & 0xff;
			unsigned char pixel_bl_g_img1 = (pixel_bl_img1 >> 16) & 0xff;
			unsigned char pixel_bl_b_img1 = (pixel_bl_img1 >> 8) & 0xff;
			unsigned char pixel_bl_a_img1 = (pixel_bl_img1 & 0xff);
			unsigned char pixel_br_r_img1 = (pixel_br_img1 >> 24) & 0xff;
			unsigned char pixel_br_g_img1 = (pixel_br_img1 >> 16) & 0xff;
			unsigned char pixel_br_b_img1 = (pixel_br_img1 >> 8) & 0xff;
			unsigned char pixel_br_a_img1 = (pixel_br_img1 & 0xff);
			unsigned char pixel_tl_r_img2 = (pixel_tl_img2 >> 24) & 0xff;
			unsigned char pixel_tl_g_img2 = (pixel_tl_img2 >> 16) & 0xff;
			unsigned char pixel_tl_b_img2 = (pixel_tl_img2 >> 8) & 0xff;
			unsigned char pixel_tl_a_img2 = (pixel_tl_img2 & 0xff);
			unsigned char pixel_tr_r_img2 = (pixel_tr_img2 >> 24) & 0xff;
			unsigned char pixel_tr_g_img2 = (pixel_tr_img2 >> 16) & 0xff;
			unsigned char pixel_tr_b_img2 = (pixel_tr_img2 >> 8) & 0xff;
			unsigned char pixel_tr_a_img2 = (pixel_tr_img2 & 0xff);
			unsigned char pixel_bl_r_img2 = (pixel_bl_img2 >> 24) & 0xff;
			unsigned char pixel_bl_g_img2 = (pixel_bl_img2 >> 16) & 0xff;
			unsigned char pixel_bl_b_img2 = (pixel_bl_img2 >> 8) & 0xff;
			unsigned char pixel_bl_a_img2 = (pixel_bl_img2 & 0xff);
			unsigned char pixel_br_r_img2 = (pixel_br_img2 >> 24) & 0xff;
			unsigned char pixel_br_g_img2 = (pixel_br_img2 >> 16) & 0xff;
			unsigned char pixel_br_b_img2 = (pixel_br_img2 >> 8) & 0xff;
			unsigned char pixel_br_a_img2 = (pixel_br_img2 & 0xff);
			unsigned char pixel_tl_r_img3 = (pixel_tl_img3 >> 24) & 0xff;
			unsigned char pixel_tl_g_img3 = (pixel_tl_img3 >> 16) & 0xff;
			unsigned char pixel_tl_b_img3 = (pixel_tl_img3 >> 8) & 0xff;
			unsigned char pixel_tl_a_img3 = (pixel_tl_img3 & 0xff);
			unsigned char pixel_tr_r_img3 = (pixel_tr_img3 >> 24) & 0xff;
			unsigned char pixel_tr_g_img3 = (pixel_tr_img3 >> 16) & 0xff;
			unsigned char pixel_tr_b_img3 = (pixel_tr_img3 >> 8) & 0xff;
			unsigned char pixel_tr_a_img3 = (pixel_tr_img3 & 0xff);
			unsigned char pixel_bl_r_img3 = (pixel_bl_img3 >> 24) & 0xff;
			unsigned char pixel_bl_g_img3 = (pixel_bl_img3 >> 16) & 0xff;
			unsigned char pixel_bl_b_img3 = (pixel_bl_img3 >> 8) & 0xff;
			unsigned char pixel_bl_a_img3 = (pixel_bl_img3 & 0xff);
			unsigned char pixel_br_r_img3 = (pixel_br_img3 >> 24) & 0xff;
			unsigned char pixel_br_g_img3 = (pixel_br_img3 >> 16) & 0xff;
			unsigned char pixel_br_b_img3 = (pixel_br_img3 >> 8) & 0xff;
			unsigned char pixel_br_a_img3 = (pixel_br_img3 & 0xff);

			float r_new_img0 = (1.0f - y_frac) * ((1.0f - x_frac) * pixel_tl_r_img0 + x_frac * pixel_tr_r_img0) +
							y_frac * ((1.0f - x_frac) * pixel_bl_r_img0 + x_frac * pixel_br_r_img0);
			float g_new_img0 = (1.0f - y_frac) * ((1.0f - x_frac) * pixel_tl_g_img0 + x_frac * pixel_tr_g_img0) +
							y_frac * ((1.0f - x_frac) * pixel_bl_g_img0 + x_frac * pixel_br_g_img0);
			float b_new_img0 = (1.0f - y_frac) * ((1.0f - x_frac) * pixel_tl_b_img0 + x_frac * pixel_tr_b_img0) +
							y_frac * ((1.0f - x_frac) * pixel_bl_b_img0 + x_frac * pixel_br_b_img0);
			float a_new_img0 = (1.0f - y_frac) * ((1.0f - x_frac) * pixel_tl_a_img0 + x_frac * pixel_tr_a_img0) +
							y_frac * ((1.0f - x_frac) * pixel_bl_a_img0 + x_frac * pixel_br_a_img0);

			float r_new_img1 = (1.0f - y_frac) * ((1.0f - x_frac) * pixel_tl_r_img1 + x_frac * pixel_tr_r_img1) +
							y_frac * ((1.0f - x_frac) * pixel_bl_r_img1 + x_frac * pixel_br_r_img1);
			float g_new_img1 = (1.0f - y_frac) * ((1.0f - x_frac) * pixel_tl_g_img1 + x_frac * pixel_tr_g_img1) +
							y_frac * ((1.0f - x_frac) * pixel_bl_g_img1 + x_frac * pixel_br_g_img1);
			float b_new_img1 = (1.0f - y_frac) * ((1.0f - x_frac) * pixel_tl_b_img1 + x_frac * pixel_tr_b_img1) +
							y_frac * ((1.0f - x_frac) * pixel_bl_b_img1 + x_frac * pixel_br_b_img1);
			float a_new_img1 = (1.0f - y_frac) * ((1.0f - x_frac) * pixel_tl_a_img1 + x_frac * pixel_tr_a_img1) +
							y_frac * ((1.0f - x_frac) * pixel_bl_a_img1 + x_frac * pixel_br_a_img1);

			float r_new_img2 = (1.0f - y_frac) * ((1.0f - x_frac) * pixel_tl_r_img2 + x_frac * pixel_tr_r_img2) +
							y_frac * ((1.0f - x_frac) * pixel_bl_r_img2 + x_frac * pixel_br_r_img2);
			float g_new_img2 = (1.0f - y_frac) * ((1.0f - x_frac) * pixel_tl_g_img2 + x_frac * pixel_tr_g_img2) +
							y_frac * ((1.0f - x_frac) * pixel_bl_g_img2 + x_frac * pixel_br_g_img2);
			float b_new_img2 = (1.0f - y_frac) * ((1.0f - x_frac) * pixel_tl_b_img2 + x_frac * pixel_tr_b_img2) +
							y_frac * ((1.0f - x_frac) * pixel_bl_b_img2 + x_frac * pixel_br_b_img2);
			float a_new_img2 = (1.0f - y_frac) * ((1.0f - x_frac) * pixel_tl_a_img2 + x_frac * pixel_tr_a_img2) +
							y_frac * ((1.0f - x_frac) * pixel_bl_a_img2 + x_frac * pixel_br_a_img2);

			float r_new_img3 = (1.0f - y_frac) * ((1.0f - x_frac) * pixel_tl_r_img3 + x_frac * pixel_tr_r_img3) +
							y_frac * ((1.0f - x_frac) * pixel_bl_r_img3 + x_frac * pixel_br_r_img3);
			float g_new_img3 = (1.0f - y_frac) * ((1.0f - x_frac) * pixel_tl_g_img3 + x_frac * pixel_tr_g_img3) +
							y_frac * ((1.0f - x_frac) * pixel_bl_g_img3 + x_frac * pixel_br_g_img3);
			float b_new_img3 = (1.0f - y_frac) * ((1.0f - x_frac) * pixel_tl_b_img3 + x_frac * pixel_tr_b_img3) +
							y_frac * ((1.0f - x_frac) * pixel_bl_b_img3 + x_frac * pixel_br_b_img3);
			float a_new_img3 = (1.0f - y_frac) * ((1.0f - x_frac) * pixel_tl_a_img3 + x_frac * pixel_tr_a_img3) +
							y_frac * ((1.0f - x_frac) * pixel_bl_a_img3 + x_frac * pixel_br_a_img3);

			float r_sepia_img0 = (r_new_img0 * 0.393f) + (g_new_img0 * 0.769f) + (b_new_img0 * 0.189f);
			float g_sepia_img0 = (r_new_img0 * 0.349f) + (g_new_img0 * 0.686f) + (b_new_img0 * 0.168f);
			float b_sepia_img0 = (r_new_img0 * 0.272f) + (g_new_img0 * 0.534f) + (b_new_img0 * 0.131f);
			float r_sepia_img1 = (r_new_img1 * 0.393f) + (g_new_img1 * 0.769f) + (b_new_img1 * 0.189f);
			float g_sepia_img1 = (r_new_img1 * 0.349f) + (g_new_img1 * 0.686f) + (b_new_img1 * 0.168f);
			float b_sepia_img1 = (r_new_img1 * 0.272f) + (g_new_img1 * 0.534f) + (b_new_img1 * 0.131f);
			float r_sepia_img2 = (r_new_img2 * 0.393f) + (g_new_img2 * 0.769f) + (b_new_img2 * 0.189f);
			float g_sepia_img2 = (r_new_img2 * 0.349f) + (g_new_img2 * 0.686f) + (b_new_img2 * 0.168f);
			float b_sepia_img2 = (r_new_img2 * 0.272f) + (g_new_img2 * 0.534f) + (b_new_img2 * 0.131f);
			float r_sepia_img3 = (r_new_img3 * 0.393f) + (g_new_img3 * 0.769f) + (b_new_img3 * 0.189f);
			float g_sepia_img3 = (r_new_img3 * 0.349f) + (g_new_img3 * 0.686f) + (b_new_img3 * 0.168f);
			float b_sepia_img3 = (r_new_img3 * 0.272f) + (g_new_img3 * 0.534f) + (b_new_img3 * 0.131f);


			unsigned char pixel_r_new_img0 = (unsigned char) r_sepia_img0;
			unsigned char pixel_g_new_img0 = (unsigned char) g_sepia_img0;
			unsigned char pixel_b_new_img0 = (unsigned char) b_sepia_img0;
			unsigned char pixel_a_new_img0 = (unsigned char) a_new_img0;
			unsigned char pixel_r_new_img1 = (unsigned char) r_sepia_img1;
			unsigned char pixel_g_new_img1 = (unsigned char) g_sepia_img1;
			unsigned char pixel_b_new_img1 = (unsigned char) b_sepia_img1;
			unsigned char pixel_a_new_img1 = (unsigned char) a_new_img1;
			unsigned char pixel_r_new_img2 = (unsigned char) r_sepia_img2;
			unsigned char pixel_g_new_img2 = (unsigned char) g_sepia_img2;
			unsigned char pixel_b_new_img2 = (unsigned char) b_sepia_img2;
			unsigned char pixel_a_new_img2 = (unsigned char) a_new_img2;
			unsigned char pixel_r_new_img3 = (unsigned char) r_sepia_img3;
			unsigned char pixel_g_new_img3 = (unsigned char) g_sepia_img3;
			unsigned char pixel_b_new_img3 = (unsigned char) b_sepia_img3;
			unsigned char pixel_a_new_img3 = (unsigned char) a_new_img3;

			pixel_img0 = (pixel_r_new_img0 << 24) | (pixel_g_new_img0 << 16) |
				(pixel_b_new_img0 << 8) | (pixel_a_new_img0);
			pixel_img1 = (pixel_r_new_img1 << 24) | (pixel_g_new_img1 << 16) |
				(pixel_b_new_img1 << 8) | (pixel_a_new_img1);
			pixel_img2 = (pixel_r_new_img2 << 24) | (pixel_g_new_img2 << 16) |
				(pixel_b_new_img2 << 8) | (pixel_a_new_img2);
			pixel_img3 = (pixel_r_new_img3 << 24) | (pixel_g_new_img3 << 16) |
				(pixel_b_new_img3 << 8) | (pixel_a_new_img3);
		}
		output_buffer_img0[i] = pixel_img0;
		output_buffer_img1[i] = pixel_img1;
		output_buffer_img2[i] = pixel_img2;
		output_buffer_img3[i] = pixel_img3;
	}
}

__attribute__ ((reqd_work_group_size(1, 1, 1)))
__attribute__((xcl_dataflow))
__kernel void affine_kernel0(__global unsigned int* dummy)
{
/*
   float    lx_rot   = *x_rot;
   float    ly_rot   = *y_rot; 
   float    lx_expan = *x_expan;
   float    ly_expan = *y_expan; 
   int      lx_move  = *x_move;
   int      ly_move  = *y_move;
*/
   float    lx_rot   = 85.0f;
   float    ly_rot   = 85.0f;
   float    lx_expan = 1.2f;
   float    ly_expan = 1.2f;
   int      lx_move  = 0;
   int      ly_move  = 0;

   //float    affine[2][2];
   //float    i_affine[2][2];
   float affine[4] __attribute__((xcl_array_partition(complete, 1)));
   float i_affine[4] __attribute__((xcl_array_partition(complete, 1)));
   float    beta[2] __attribute__((xcl_array_partition(complete, 1)));
   float    i_beta[2] __attribute__((xcl_array_partition(complete, 1)));
   float    det;
   //float    x_new, y_new;
   //float    x_frac, y_frac;
   //float    gray_new;
   int      x, y;//, m, n;
   unsigned int out_val0 = 0;
   unsigned int out_val1 = 0;
   unsigned int out_val2 = 0;
   unsigned int out_val3 = 0;

   unsigned int    output_buffer_img0[X_SIZE];
   unsigned int    output_buffer_img1[X_SIZE];
   unsigned int    output_buffer_img2[X_SIZE];
   unsigned int    output_buffer_img3[X_SIZE];
   float address_x[X_SIZE] __attribute__((xcl_array_partition(cyclic, 2, 1)));
   float address_y[X_SIZE] __attribute__((xcl_array_partition(cyclic, 2, 1)));
   float frac_x[X_SIZE] __attribute__((xcl_array_partition(cyclic, 2, 1)));
   float frac_y[X_SIZE] __attribute__((xcl_array_partition(cyclic, 2, 1)));


   //unsigned int input_buffer[X_SIZE];
 	//TODO: partition this
   unsigned int row_buffer[X_SIZE * 16] __attribute__((xcl_array_partition(cyclic, 64, 1)));

   write_pipe(o0, &out_val0);
   write_pipe(o0, &out_val0);
   write_pipe(o0, &out_val0);
   write_pipe(o1, &out_val1);
   write_pipe(o1, &out_val1);
   write_pipe(o1, &out_val1);
   write_pipe(o2, &out_val2);
   write_pipe(o2, &out_val2);
   write_pipe(o2, &out_val2);
   write_pipe(o3, &out_val3);
   write_pipe(o3, &out_val3);
   write_pipe(o3, &out_val3);


   // forward affine transformation
   affine[0] = lx_expan * cos((float)(lx_rot*PI/180.0f));
   affine[1] = ly_expan * sin((float)(ly_rot*PI/180.0f));
   affine[2] = lx_expan * sin((float)(lx_rot*PI/180.0f));
   affine[3] = ly_expan * cos((float)(ly_rot*PI/180.0f));
   beta[0]      = lx_move;
   beta[1]      = ly_move;
  
   // determination of inverse affine transformation
   det = (affine[0] * affine[3]) - (affine[1] * affine[2]);
   if (det == 0.0f)
   {
      i_affine[0]   = 1.0f;
      i_affine[1]   = 0.0f;
      i_affine[2]   = 0.0f;
      i_affine[3]   = 1.0f;
      i_beta[0]        = -beta[0];
      i_beta[1]        = -beta[1];
   } 
   else 
   {
      i_affine[0]   =  affine[3]/det;
      i_affine[1]   = -affine[1]/det;
      i_affine[2]   = -affine[2]/det;
      i_affine[3]   =  affine[0]/det;
      i_beta[0]        = -i_affine[0]*beta[0]-i_affine[1]*beta[1];
      i_beta[1]        = -i_affine[2]*beta[0]-i_affine[3]*beta[1];
   }
  
   // Output image generation by inverse affine transformation and bilinear transformation
   __attribute__((xcl_pipeline_loop))
   main_loop: for (y = 0; y < Y_SIZE; y++)
   {
	   calculate_row_pixel_addresses(y, address_x, address_y, i_beta, i_affine);
	   read_row_pixels(address_x, address_y, frac_x, frac_y, row_buffer);
	   calculate_row_pixels(frac_x, frac_y, row_buffer, output_buffer_img0, output_buffer_img1, output_buffer_img2, output_buffer_img3);
	   barrier(CLK_LOCAL_MEM_FENCE);
	   //write_output(output_buffer, y);

	   out_loop: for(x = 0; x < X_SIZE; x++){
		   out_val0 = output_buffer_img0[x];
		   write_pipe(o0, &out_val0);
		   out_val1 = output_buffer_img1[x];
		   write_pipe(o1, &out_val1);
		   out_val2 = output_buffer_img2[x];
		   write_pipe(o2, &out_val2);
		   out_val3 = output_buffer_img3[x];
		   write_pipe(o3, &out_val3);
	   }

   }
	//Close the shield modules
	unsigned int resp_buf0[BLOCK_WORD_SIZE];
	unsigned int req_buf0[RAM_HEADER_SIZE];
	unsigned int resp_buf1[BLOCK_WORD_SIZE];
	unsigned int req_buf1[RAM_HEADER_SIZE];
	unsigned int resp_buf2[BLOCK_WORD_SIZE];
	unsigned int req_buf2[RAM_HEADER_SIZE];
	unsigned int resp_buf3[BLOCK_WORD_SIZE];
	unsigned int req_buf3[RAM_HEADER_SIZE];
	unsigned int resp_buf4[BLOCK_WORD_SIZE];
	unsigned int req_buf4[RAM_HEADER_SIZE];
	unsigned int resp_buf5[BLOCK_WORD_SIZE];
	unsigned int req_buf5[RAM_HEADER_SIZE];
	unsigned int resp_buf6[BLOCK_WORD_SIZE];
	unsigned int req_buf6[RAM_HEADER_SIZE];
	unsigned int resp_buf7[BLOCK_WORD_SIZE];
	unsigned int req_buf7[RAM_HEADER_SIZE];
	req_buf0[0] = 0xffffffff;
	req_buf0[1] = 0xffffffff;
	req_buf1[0] = 0xffffffff;
	req_buf1[1] = 0xffffffff;
	req_buf2[0] = 0xffffffff;
	req_buf2[1] = 0xffffffff;
	req_buf3[0] = 0xffffffff;
	req_buf3[1] = 0xffffffff;
	req_buf4[0] = 0xffffffff;
	req_buf4[1] = 0xffffffff;
	req_buf5[0] = 0xffffffff;
	req_buf5[1] = 0xffffffff;
	req_buf6[0] = 0xffffffff;
	req_buf6[1] = 0xffffffff;
	req_buf7[0] = 0xffffffff;
	req_buf7[1] = 0xffffffff;
	send_req(req_buf0, resp_buf0, req_buf1, resp_buf1, req_buf2, resp_buf2, req_buf3, resp_buf3,
			req_buf4, resp_buf4, req_buf5, resp_buf5, req_buf6, resp_buf6, req_buf7, resp_buf7);
}
