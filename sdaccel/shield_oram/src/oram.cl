//
#define L 16
#define Z 4    //capacity of each bucket (in blocks)
#define N 87382 //total number of blocks outsourced
#define B 64   //block size in bytes
#define C 50 //Stash size in blocks, excluding transient storage (L+1)Z

//
#define BLOCK_SIZE 68 //B + HEADER_SIZE
#define TREE_SIZE 131071 //pow(2, L+1) - 1
#define LEAF_SIZE 65536 //pow(2, L)
#define LEAF_MIN 65535 //When stored as a contiguous array, offset of first leaf
#define LEAF_MAX 131070 //when stored as contiguous array, offset to last leaf



//
//#define L 6
//#define Z 4    //capacity of each bucket (in blocks)
//#define N 4 //total number of blocks outsourced
//#define B 64   //block size in bytes
//#define C 50 //Stash size in blocks, excluding transient storage (L+1)Z
#define HEADER_SIZE 4


//#define BLOCK_SIZE 68 //B + META_ADDR_SIZE + META_LEAF_SIZE
////#define TREE_SIZE 127 //pow(2, L+1) - 1
//#define TREE_SIZE 127
//#define LEAF_SIZE 64
////#define LEAF_SIZE 64 //pow(2, L)
//#define LEAF_MIN 63
//#define LEAF_MAX 126


#define BOT 0xff

#define BUCKET_WORD_SIZE 68 //Z*BLOCK_SIZE/4. Size of each bucket in words
#define BLOCK_WORD_SIZE 17 //BLOCK_SIZE/4
#define CHUNK_SIZE 72 //bucket word size + tag (4 words)
#define RAM_HEADER_SIZE 2 //Size of the ram header in words

#define B_WORD_SIZE 16 //size of input stream in words = B/4

#define PI     3.14159265359f
#define WHITE  0xffffffff //(short)(1)
#define BLACK  0x00000000 //(short)(0)

#define X_SIZE 512
#define Y_SIZE 512


pipe unsigned int r0 __attribute__((xcl_reqd_pipe_depth(32)));
pipe unsigned int r1 __attribute__((xcl_reqd_pipe_depth(32)));
pipe unsigned int p2 __attribute__((xcl_reqd_pipe_depth(32)));
pipe unsigned int p3 __attribute__((xcl_reqd_pipe_depth(32)));
//pipe unsigned int i0 __attribute__((xcl_reqd_pipe_depth(32)));
pipe unsigned int o0 __attribute__((xcl_reqd_pipe_depth(32)));
//pipe unsigned int o1 __attribute__((xcl_reqd_pipe_depth(32)));
//pipe unsigned int o2 __attribute__((xcl_reqd_pipe_depth(32)));
//pipe unsigned int o3 __attribute__((xcl_reqd_pipe_depth(32)));

//
//#define L 10
//#define Z 4    //capacity of each bucket (in blocks)
//#define N 1024 //total number of blocks outsourced
//#define B 64   //block size in bytes
//#define C 50 //Stash size in blocks, excluding transient storage (L+1)Z
//#define META_ADDR_SIZE 2 //size of address metadata in bytes
//
//#define BLOCK_SIZE 66 //B + META_ADDR_SIZE + META_LEAF_SIZE
//#define TREE_SIZE 2047 //pow(2, L+1) - 1
//#define LEAF_SIZE 1024 //pow(2, L)
//#define LEAF_MIN 1023 //When stored as a contiguous array, offset of first leaf
//#define LEAF_MAX 2046 //when stored as contiguous array, offset to last leaf


static void send_req(__local unsigned int* inbuf, __local unsigned int* outbuf){
	unsigned int req_addr;
	unsigned int req_hdr;

	unsigned int write_itr;

	//Decide how if it's a read or write request
	if((inbuf[0] & 0x03) == 0x01){
		write_itr = CHUNK_SIZE - 2; //total chunk size - 4 (tag) + 2 (header)
	}
	else{
		write_itr = 2;
	}

	//Write the input command
	for(int i = 0; i < write_itr; i++){
		while(write_pipe(r0, &inbuf[i]) != 0){}
	}
	barrier(CLK_LOCAL_MEM_FENCE);

	//Read the response - if it's a read command
	if((inbuf[0] & 0x03) == 0x00){
		for(int i = 0; i < BUCKET_WORD_SIZE; i++){
			unsigned int result;
			read_pipe_block(r1, &result);
			outbuf[i] = result;
		}
	}
}




// top-level function
//__attribute__ ((reqd_work_group_size(1, 1, 1)))
//__kernel void oram(__global unsigned char* server)
void init_oram(__local unsigned char* stash,
		__local unsigned int* req_buf, __local unsigned int* resp_buf)
{
	int i, j, k;

//	for(i = 0; i < BUCKET_WORD_SIZE + RAM_HEADER_SIZE; i++){
//		req_buf[i] = 0;
//	}
//
//	//Initialize the server by writing dummy blocks everywhere
//	//printf("Initializing server\n");
//	//for each node in the tree
//	for (i = 0; i < TREE_SIZE; i = i + 1){
//		//Clear the node
//		req_buf[0] = ((i & 0x1ffff) << 2) | 0x01; //Write command to index i
//		req_buf[1] = (i * CHUNK_SIZE * 4); //Byte address of bucket i
//		//Set each block in the bucket to be BOT
//		for(j = 0; j < Z; j++){
//			int idx = j*(BLOCK_WORD_SIZE);
//			req_buf[idx + 2] = 0xffffffff; //BOT
//		}
//		//Write the bucket out to DRAM
//		send_req(req_buf, resp_buf);
//	}

	//Initialize the posmap
	//printf("Initializing posmap\n");
//	__attribute__((xcl_pipeline_loop))
//	for (i = 0; i < N; i++){
//		//unsigned short rng = pseudo_rand();
//		unsigned short rng = 0;
//		posmap[i] = rng % LEAF_SIZE;
//		//posmap[i] = 1;
//		//rand = pseudo_rand(rand);
//		//rand = pseudo_rand();
//	}

//	//Initialize the stash
	//printf("Initializing stash\n");
	for (i = 0; i < (L+1)*Z + C; i++ ){
		//The stash should initially be empty
		int idx = i * BLOCK_SIZE;
		//TODO: SIZE
		stash[idx] = BOT;
		stash[idx + 1] = BOT;
		stash[idx + 2] = BOT;
		stash[idx + 3] = BOT;
	}
}
//
void access(int op, unsigned int a, __local unsigned char* data,
		__local unsigned short* posmap, __local unsigned char* stash,
		__local unsigned int* req_buf, __local unsigned int* resp_buf, unsigned short rng){
	//printf("=============================\n");
	//printf("Performing op %d on address %d\n", op, a);
	int x = posmap[a] + LEAF_MIN;
	//printf("Current leaf= %d (node %d)\n", posmap[a], posmap[a] + LEAF_MIN);
	//posmap[a] = rand() % LEAF_SIZE;
	//unsigned short rng = pseudo_rand();
	//unsigned short rng = 0;
	posmap[a] = rng % LEAF_SIZE;
	//*rng = pseudo_rand(*rng);
	//printf("New leaf= %d (node %d)\n", posmap[a], posmap[a] + LEAF_MIN);

	unsigned int path[L+1] = {0};
	path[0] = 0;
	//Generate the path
	int l;
	int i, j;
	int s;
	int z_idx;
	int leafmin = LEAF_MIN;
	int leafmax = LEAF_MAX;
	for(l = 0;l < L; l++){
		int mid = (leafmax - leafmin) / 2 + leafmin;

		if (x <= mid){
			//Go down the left child
			path[l+1] = path[l] * 2 + 1;
			leafmax = mid;
		}
		else{
			//Go down the right child
			path[l+1] = path[l] * 2 + 2;
			leafmin = mid + 1;
		}
	}

//	for(l = 0; l <= L; l++){
//		//printf("Eviction path level %d is node %d\n", l, path[l]);
//	}

	//printf("#Reading buckets along path into the stash\n");
	for(l = 0; l <= L; l++){
		//Read the bucket into the stash
		int bucket_index = path[l];
		req_buf[0] = ((bucket_index & 0x1ffff) << 2) | 0x00; //Read command to read bucket path[l]
		req_buf[1] = (bucket_index * CHUNK_SIZE * 4); //Byte address of bucket path[l]
		//Read the bucket into local memory
		send_req(req_buf, resp_buf);

		for(z_idx = 0; z_idx < Z; z_idx++){
			//printf("Reading block %d of bucket %d\n", z_idx, path[l]);
			for(s = 0; s < (L+1)*Z + C; s++){
				//Get the first open space in the stash
				//TODO: size change
				if(stash[s*BLOCK_SIZE] == BOT && stash[s*BLOCK_SIZE+1] == BOT
						&& stash[s*BLOCK_SIZE+2] == BOT && stash[s*BLOCK_SIZE+3] == BOT){
					break;
				}
			}
			//int server_offset = path[l]*Z*BLOCK_SIZE + z_idx * BLOCK_SIZE;
			int server_offset = z_idx * BLOCK_WORD_SIZE;

			//Copy over the response into the stash
			for(i = 0; i < BLOCK_WORD_SIZE; i++){
				unsigned int tmp = resp_buf[server_offset + i];
				stash[s*BLOCK_SIZE + i*4] = (tmp >> 24) & 0xff;
				stash[s*BLOCK_SIZE + i*4 + 1] = (tmp >> 16) & 0xff;
				stash[s*BLOCK_SIZE + i*4 + 2] = (tmp >> 8) & 0xff;
				stash[s*BLOCK_SIZE + i*4 + 3] = tmp & 0xff;
			}
			//TODO: SIZE
			//short block_addr = (server[server_offset] << 8) | server[server_offset+1];
			//printf("Server addr = %d\n", server_offset);
			//printf("Block addr = %d, block leaf = %d\n", block_addr, block_leaf);
//			for(i = 0; i < BLOCK_SIZE; i++){
//				stash[s*BLOCK_SIZE + i] = server[server_offset+i];
//			}
			//TODO: SIZE
			//short short_bot = (BOT << 8) | BOT;
//			if(block_addr != short_bot){
//				printf("Read offset %d of bucket %d into stash position %d\n", z_idx, path[l], s);
//			}
		}
	}

	if (op == 1){
		//int open_idx = 0;
		for(s = 0; s < (L+1)*Z + C; s++){
			//TODO: SIZE
			unsigned int stash_addr = (stash[s*BLOCK_SIZE] << 24) |
					(stash[s*BLOCK_SIZE + 1] << 16) |
					(stash[s*BLOCK_SIZE + 2] << 8) |
					stash[s*BLOCK_SIZE + 3];
			if(stash_addr == a){
				//printf("Block %d found in stash at position %d\n", a, s);
				break;
			}
		}
		if(s == (L+1)*Z + C){
			//printf("Addr %d not found in stash. Must be first write\n", a);
			//Find an open space in the stash
			for(s = 0; s < (L+1)*Z + C; s++){
			//TODO: SIZE
				if(stash[s*BLOCK_SIZE] == BOT && stash[s*BLOCK_SIZE + 1] == BOT &&
						stash[s*BLOCK_SIZE + 2] == BOT && stash[s*BLOCK_SIZE + 3] == BOT){
					break;
				}
			}
		}
		//printf("Adding data for block %d to stash at position %d\n", a, s);
		//TODO: SIZE
		stash[s*BLOCK_SIZE] = (a >> 24) & 0xff;
		stash[s*BLOCK_SIZE+1] = (a >> 16) & 0xff;
		stash[s*BLOCK_SIZE+2] = (a >> 8) & 0xff;
		stash[s*BLOCK_SIZE+3] = a & 0xff;
		for(i = 0; i < B; i++){
			//Fill the rest of the block with the write data
			stash[s*BLOCK_SIZE+HEADER_SIZE+i] = data[i];
		}
	}
	else{
		//Set data to be block a from S
		for(s = 0; s < (L+1)*Z + C; s++){
			//TODO: SIZE
			unsigned int block_addr = (stash[s*BLOCK_SIZE] << 24) |
					(stash[s*BLOCK_SIZE+1] << 16) |
					(stash[s*BLOCK_SIZE+2] << 8) |
					stash[s*BLOCK_SIZE+3];
			if(block_addr == a){
				for(i = 0; i < B; i++){
					data[i] = stash[s*BLOCK_SIZE+HEADER_SIZE+i];
				}
				//printf("Reading data from block %d from stash position %d\n", a, s);
				break;
			}
		}
	}

	//printf("Evicting blocks\n");

	for(l = L; l >= 0; l = l-1){
		//printf("Evicting stash to level %d\n", l);
		int blocks_written = 0;
		//We need to write an entire bucket out to path[l]
		int bucket_index = path[l]; //get the bucket index in ram
		req_buf[0] = ((bucket_index & 0x1ffff) << 2) | 0x01; //write command to bucket path[l]
		req_buf[1] = (bucket_index * CHUNK_SIZE * 4); //Byte address of bucket path[l]

		//Scan through the stash
		for(s = 0; s < (L+1)*Z + C; s++){
			//If there are already Z blocks written out, don't write any more
			if(blocks_written == Z){
				break;
			}
			//Check if the address is valid
			//TODO: SIZE
			if(stash[s*BLOCK_SIZE] == BOT && stash[s*BLOCK_SIZE + 1] == BOT &&
					stash[s*BLOCK_SIZE + 2] == BOT && stash[s*BLOCK_SIZE + 3] == BOT){
				continue;
			}
			unsigned int a_prime = (stash[s*BLOCK_SIZE] << 24) |
							(stash[s*BLOCK_SIZE + 1] << 16) |
							(stash[s*BLOCK_SIZE + 2] << 8) |
							stash[s*BLOCK_SIZE + 3];
			int a_prime_path = posmap[a_prime] + LEAF_MIN;

			//Check if the paths overlap
			leafmin = LEAF_MIN;
			leafmax = LEAF_MAX;
			int evict_path[L+1] = {0};
			for(i = 0; i < L; i++){
				int mid = (leafmax - leafmin) / 2 + leafmin;

				if(a_prime_path <= mid){
					//Go down the left child
					evict_path[i+1] = evict_path[i] * 2 + 1;
					leafmax = mid;
				}
				else{
					//go down right child
					evict_path[i+1] = evict_path[i] * 2 + 2;
					leafmin = mid + 1;
				}
			}

			//Check if the path overlaps at this level
			if(path[l] == evict_path[l]){
//				printf("Found valid block %d in stash at position %d with leaf %d (node %d)\n", a_prime, s, posmap[a_prime], a_prime_path);
//				printf("Path overlaps - writing to bucket %d at level %d\n", path[l], l);
//				printf("Eviction path: ");
//				for(i = 0; i <=L; i++){
//					printf("%d, ", path[i]);
//				}
//				printf("\n");
//				printf("Stash path: ");
//				for(i = 0; i <=L; i++){
//					printf("%d, ", evict_path[i]);
//				}
//				printf("\n");
				//If so, then write the block into the server
//				int server_offset = path[l]*Z*BLOCK_SIZE + blocks_written * BLOCK_SIZE;
//				//TODO: SIZE
//				server[server_offset] = (a_prime >> 8) & 0xff;
//				server[server_offset + 1] = (a_prime & 0xff);
//				for(i = 0; i < B; i++){
//					server[server_offset + HEADER_SIZE + i] = stash[s*BLOCK_SIZE + HEADER_SIZE + i];
//				}

				int server_offset = blocks_written * BLOCK_WORD_SIZE; //get which block in the bucket to write to
				req_buf[RAM_HEADER_SIZE + server_offset] = a_prime; //write the address of a'
				for(int k = 0; k < BLOCK_WORD_SIZE - 1; k++){
					unsigned int tmp = 0;
					//convert the data (not including the header) in the block into unsigned ints
					unsigned char s1 = stash[s*BLOCK_SIZE + HEADER_SIZE + k*4];
					unsigned char s2 = stash[s*BLOCK_SIZE + HEADER_SIZE + k*4 + 1];
					unsigned char s3 = stash[s*BLOCK_SIZE + HEADER_SIZE + k*4 + 2];
					unsigned char s4 = stash[s*BLOCK_SIZE + HEADER_SIZE + k*4 + 3];
					tmp = (s1 << 24) | (s2 << 16) | (s3 << 8) | (s4);
					req_buf[RAM_HEADER_SIZE + server_offset + k + 1] = tmp; //and fill it into the request
				}

				//Remove this block from the stash
				//printf("Clearing stash position %d\n", s);
				//TODO: SIZE
				stash[s*BLOCK_SIZE] = BOT;
				stash[s*BLOCK_SIZE+1] = BOT;
				stash[s*BLOCK_SIZE+2] = BOT;
				stash[s*BLOCK_SIZE+3] = BOT;
				blocks_written = blocks_written + 1;

				continue; //Go on to the next element in the stash
			}
		}

		//If fewer than Z real blocks were written, fill the rest of the bucket with dummies
		if(blocks_written < Z){
			int dummies_to_write = Z-blocks_written;
			//printf("Only wrote %d real blocks. Filling bucket %d with %d dummies \n", blocks_written, path[l], dummies_to_write);
			for(i = 0; i < dummies_to_write; i++){
				int server_offset = blocks_written * BLOCK_WORD_SIZE;
				req_buf[RAM_HEADER_SIZE + server_offset] = 0xffffffff; //BOT
//				for(int k = 1; k < BLOCK_WORD_SIZE; k++){
//					req_buf[RAM_HEADER_SIZE + server_offset + k] = 3;
//				}

//				int server_offset = path[l]*Z*BLOCK_SIZE + blocks_written*BLOCK_SIZE;
//				//TODO:SIZE
//				server[server_offset] = BOT;
//				server[server_offset+1] = BOT;
//				for(j = 0; j < B; j++){
//					server[server_offset + HEADER_SIZE + j] = 0;
//				}

				blocks_written++;
			}
		}
		//Write the bucket out to DRAM
		send_req(req_buf, resp_buf);
	}
}

__attribute__ ((reqd_work_group_size(1, 1, 1)))
__kernel void oram(__global unsigned int* dummy, int n_size)
{
	int status = 0;

	//unsigned char server[TREE_SIZE*Z*BLOCK_SIZE];
	__local unsigned short posmap[N];
	__local unsigned char stash[((L+1)*Z + C) * BLOCK_SIZE] __attribute__((xcl_array_partiion(cyclic,4,1))); //Partition to allow 4 accesses per cycle

	//Request/response buffer holds one chunk of data, plus header
	__local unsigned int resp_buf[BUCKET_WORD_SIZE];
	__local unsigned int req_buf[BUCKET_WORD_SIZE + RAM_HEADER_SIZE];
	__local unsigned char access_buf[B] __attribute__((xcl_array_partition(complete, 1)));
	__local unsigned char access_buf1[B] __attribute__((xcl_array_partition(complete, 1)));

	float    lx_rot   = 85.0f;
	float    ly_rot   = 85.0f;
	float    lx_expan = 1.2f;
	float    ly_expan = 1.2f;
	int      lx_move  = 0;
	int      ly_move  = 0;

	float affine[4] __attribute__((xcl_array_partition(complete, 1)));
	float i_affine[4] __attribute__((xcl_array_partition(complete, 1)));
	float    beta[2] __attribute__((xcl_array_partition(complete, 1)));
	float    i_beta[2] __attribute__((xcl_array_partition(complete, 1)));
	float    det;

	int      x, y;
	int i;
	int j;

	//unsigned int    output_buffer_img0[X_SIZE*X_SIZE];
//	unsigned int    output_buffer_img1[X_SIZE];
//	unsigned int    output_buffer_img2[X_SIZE];
//	unsigned int    output_buffer_img3[X_SIZE];

//	float address_x[X_SIZE] __attribute__((xcl_array_partition(cyclic, 2, 1)));
//	float address_y[X_SIZE] __attribute__((xcl_array_partition(cyclic, 2, 1)));
//	float frac_x[X_SIZE] __attribute__((xcl_array_partition(cyclic, 2, 1)));
//	float frac_y[X_SIZE] __attribute__((xcl_array_partition(cyclic, 2, 1)));

	unsigned int out_val0 = 0;
//	unsigned int out_val1 = 0;
//	unsigned int out_val2 = 0;
//	unsigned int out_val3 = 0;




//	//Set the IV for the output
//
//	write_pipe(o0, &out_val0);
//	write_pipe(o0, &out_val0);
//	write_pipe(o0, &out_val0);
//	write_pipe(o1, &out_val1);
//	write_pipe(o1, &out_val1);
//	write_pipe(o1, &out_val1);
//	write_pipe(o2, &out_val2);
//	write_pipe(o2, &out_val2);
//	write_pipe(o2, &out_val2);
//	write_pipe(o3, &out_val3);
//	write_pipe(o3, &out_val3);
//	write_pipe(o3, &out_val3);


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

	//Initialize the posmap in the main function... since we can't call p3 from multiple points
	for (i = 0; i < N; i++){
		unsigned int rng_init;
		read_pipe_block(p3, &rng_init);
		posmap[i] = (unsigned short)(rng_init % LEAF_SIZE);
	}

	init_oram(stash, req_buf, resp_buf);

	//Read in the image from the streaming input and write it into the ORAM
	for (i = 0; i < N; i++){
		//Read in pixel block
		for (j = 0; j < B_WORD_SIZE; j++){
			unsigned int img_block;
//			read_pipe_block(i0, &img_block);

			//Write it to the input_data buffer
//			access_buf[j*4] = (unsigned char) (img_block >> 24) & 0xff;
//			access_buf[j*4 + 1] = (img_block >> 16) & 0xff;
//			access_buf[j*4 + 2] = (img_block >> 8) & 0xff;
//			access_buf[j*4 + 3] = img_block & 0xff;
			access_buf[j*4] = i % 255;
			access_buf[j*4 + 1] = i % 255;
			access_buf[j*4 + 2] = i % 255;
			access_buf[j*4 + 3] = i % 255;

		}
		//Read in some random number
		unsigned int rng_load;
		read_pipe_block(p3, &rng_load);


		//Write the image block into ORAM at address i
		access(1, i, access_buf, posmap, stash, req_buf, resp_buf, (unsigned short)rng_load);
	}

	//Initialization is now finished. Ready for processing
	barrier(CLK_LOCAL_MEM_FENCE);
	//For each row
	row_loop: for(y = 0; y < n_size; y++)
	{
		//For each pixel in the row
		//__attribute__((xcl_pipeline_loop))
		col_loop: for (x = 0; x < n_size; x++){
			//Calculate which pixels in the original image to use
			float x_new    = i_beta[0] + i_affine[0]*(x-X_SIZE/2.0f) + i_affine[1]*(y-Y_SIZE/2.0f) + X_SIZE/2.0f;
			float y_new    = i_beta[1] + i_affine[2]*(x-X_SIZE/2.0f) + i_affine[3]*(y-Y_SIZE/2.0f) + Y_SIZE/2.0f;

			//Get the top left pixel
			int m        = (int)floor(x_new);
			int n        = (int)floor(y_new);

			//Get where in the 4x4 grid the fraction is
			float x_frac   = x_new - m;
			float y_frac   = y_new - n;

			unsigned int pixelt_index;
			unsigned int pixelb_index;

			//Random number generator
			unsigned int rng_read;

			unsigned int pixel_img0;
//			unsigned int pixel_img1;
//			unsigned int pixel_img2;
//			unsigned int pixel_img3;

			if ((m >= 0) && (m + 1 < X_SIZE) && (n >= 0) && (n+1 < Y_SIZE))
			{
				pixelt_index = ((n * X_SIZE) + m);
				pixelb_index = (((n+1) * X_SIZE) + m);
			}
	        else if (((m + 1 == X_SIZE) && (n >= 0) && (n < Y_SIZE)) || ((n + 1 == Y_SIZE) && (m >= 0) && (m < X_SIZE)))
	        {
	        	pixelt_index = ((n * X_SIZE) + m);
	        	pixelb_index = ((n * X_SIZE) + m);
	        }
	        else{ //just use the first block...
	        	pixelt_index = 0;
	        	pixelb_index = 0;
	        }


			unsigned int pixelt_addr = pixelt_index / 3; //The block address of the top left pixel
			unsigned int pixelb_addr = pixelb_index / 3; //The block address of the bottom left pixel
//			unsigned int pixelt_addr = x;
//			unsigned int pixelb_addr = y;



			read_pipe_block(p3, &rng_read);
			access(0, pixelt_addr, access_buf, posmap, stash, req_buf, resp_buf, (unsigned short)rng_read);
			barrier(CLK_LOCAL_MEM_FENCE);
			read_pipe_block(p3, &rng_read);
			access(0, pixelb_addr, access_buf1, posmap, stash, req_buf, resp_buf, (unsigned short)rng_read);
			barrier(CLK_LOCAL_MEM_FENCE);

			__attribute__((nounroll))
			for(i = 0; i < 4; i++){
				unsigned int pixeltl_offset_img0 = (pixelt_index % 3) * 4 + i*16; //The offset into the 64B block of the top left pixel
				unsigned int pixelbl_offset_img0 = (pixelb_index % 3) * 4 + i*16; //The offset into the 64B block of the bottom left pixel
				unsigned char pixel_tl_r_img0 = access_buf[pixeltl_offset_img0];
				unsigned char pixel_tl_g_img0 = access_buf[pixeltl_offset_img0 + 1];
				unsigned char pixel_tl_b_img0 = access_buf[pixeltl_offset_img0 + 2];
				unsigned char pixel_tl_a_img0 = access_buf[pixeltl_offset_img0 + 3];
				unsigned char pixel_tr_r_img0 = access_buf[pixeltl_offset_img0 + 4];
				unsigned char pixel_tr_g_img0 = access_buf[pixeltl_offset_img0 + 5];
				unsigned char pixel_tr_b_img0 = access_buf[pixeltl_offset_img0 + 6];
				unsigned char pixel_tr_a_img0 = access_buf[pixeltl_offset_img0 + 7];

				unsigned char pixel_bl_r_img0 = access_buf1[pixelbl_offset_img0];
				unsigned char pixel_bl_g_img0 = access_buf1[pixelbl_offset_img0 + 1];
				unsigned char pixel_bl_b_img0 = access_buf1[pixelbl_offset_img0 + 2];
				unsigned char pixel_bl_a_img0 = access_buf1[pixelbl_offset_img0 + 3];
				unsigned char pixel_br_r_img0 = access_buf1[pixelbl_offset_img0 + 4];
				unsigned char pixel_br_g_img0 = access_buf1[pixelbl_offset_img0 + 5];
				unsigned char pixel_br_b_img0 = access_buf1[pixelbl_offset_img0 + 6];
				unsigned char pixel_br_a_img0 = access_buf1[pixelbl_offset_img0 + 7];

				float r_new_img0 = (1.0f - y_frac) * ((1.0f - x_frac) * pixel_tl_r_img0 + x_frac * pixel_tr_r_img0) +
								y_frac * ((1.0f - x_frac) * pixel_bl_r_img0 + x_frac * pixel_br_r_img0);
				float g_new_img0 = (1.0f - y_frac) * ((1.0f - x_frac) * pixel_tl_g_img0 + x_frac * pixel_tr_g_img0) +
								y_frac * ((1.0f - x_frac) * pixel_bl_g_img0 + x_frac * pixel_br_g_img0);
				float b_new_img0 = (1.0f - y_frac) * ((1.0f - x_frac) * pixel_tl_b_img0 + x_frac * pixel_tr_b_img0) +
								y_frac * ((1.0f - x_frac) * pixel_bl_b_img0 + x_frac * pixel_br_b_img0);
				float a_new_img0 = (1.0f - y_frac) * ((1.0f - x_frac) * pixel_tl_a_img0 + x_frac * pixel_tr_a_img0) +
								y_frac * ((1.0f - x_frac) * pixel_bl_a_img0 + x_frac * pixel_br_a_img0);

				float r_sepia_img0 = (r_new_img0 * 0.393f) + (g_new_img0 * 0.769f) + (b_new_img0 * 0.189f);
				float g_sepia_img0 = (r_new_img0 * 0.349f) + (g_new_img0 * 0.686f) + (b_new_img0 * 0.168f);
				float b_sepia_img0 = (r_new_img0 * 0.272f) + (g_new_img0 * 0.534f) + (b_new_img0 * 0.131f);


				unsigned char pixel_r_new_img0 = (unsigned char) r_sepia_img0;
				unsigned char pixel_g_new_img0 = (unsigned char) g_sepia_img0;
				unsigned char pixel_b_new_img0 = (unsigned char) b_sepia_img0;
				unsigned char pixel_a_new_img0 = (unsigned char) a_new_img0;


				pixel_img0 = (pixel_r_new_img0 << 24) | (pixel_g_new_img0 << 16) |
					(pixel_b_new_img0 << 8) | (pixel_a_new_img0);
//				out_val0 = pixel_img0;
//				write_pipe(o0, &out_val0);

//				if(i == 0){
//					output_buffer_img0[x] = pixel_img0;
//				}
//				else if (i == 1){
//					output_buffer_img1[x] = pixel_img0;
//				}
//				else if (i ==2){
//					output_buffer_img2[x] = pixel_img0;
//				}
//				else{
//					output_buffer_img3[x] = pixel_img0;
//				}
				dummy[y*X_SIZE  + x + i] = pixel_img0;
			}


		}
//	  barrier(CLK_LOCAL_MEM_FENCE);
//	  //Write out the output buffer to DRAM
//	  out_loop: for(x = 0; x < n_size; x++){
//		  out_val0 = output_buffer_img0[x];
//		  write_pipe(o0, &out_val0);
//		  out_val0 = output_buffer_img1[x];
//		  write_pipe(o0, &out_val0);
//		  out_val0 = output_buffer_img2[x];
//		  write_pipe(o0, &out_val0);
//		  out_val0 = output_buffer_img3[x];
//		  write_pipe(o0, &out_val0);
//	  }
	}
	//dummy[0] = output_buffer_img0[0];
//
//		  barrier(CLK_LOCAL_MEM_FENCE);
//		  for( x = 0; x < n_size; x++){
//		  //		  out_val0 = output_buffer_img0[x];
//		  //		  write_pipe(o0, &out_val0);
//		  }


	//Close the shield modules
	req_buf[0] = 0xffffffff;
	req_buf[1] = 0xffffffff;
	send_req(req_buf, resp_buf); //Close the RAM
	unsigned int finish = 0xffffffff;
	write_pipe(p2, &finish); //close the RNG
	
}
