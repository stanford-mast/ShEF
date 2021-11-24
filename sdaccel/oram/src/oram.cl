//
//#define L 6
//#define Z 4    //capacity of each bucket (in blocks)
//#define N 64 //total number of blocks outsourced
//#define B 64   //block size in bytes
//#define C 50 //Stash size in blocks, excluding transient storage (L+1)Z
//#define META_ADDR_SIZE 1 //size of address metadata in bytes
//#define META_LEAF_SIZE 1 //size of path metadata in bytes
#define L 9
#define Z 4
#define N 512
#define B 64
#define C 50

#define BLOCK_SIZE 66 //B + META_ADDR_SIZE + META_LEAF_SIZE
//#define TREE_SIZE 127 //pow(2, L+1) - 1
#define TREE_SIZE 1023
#define LEAF_SIZE 512
//#define LEAF_SIZE 64 //pow(2, L)
#define LEAF_MIN 511
#define LEAF_MAX 1022
//#define LEAF_MIN 63 //When stored as a contiguous array, offset of first leaf
//#define LEAF_MAX 126 //when stored as contiguous array, offset to last leaf

#define BOT 0xff
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

unsigned short __attribute__((always_inline)) pseudo_rand(unsigned short seed){
	unsigned short lfsr = seed;
	unsigned short rand_bit;

	rand_bit = ((lfsr >> 0) ^ (lfsr >> 2) ^ (lfsr >> 3) ^ (lfsr >> 5) ) & 1;
	return (lfsr >> 1) | (rand_bit << 15);
}

// top-level function
//__attribute__ ((reqd_work_group_size(1, 1, 1)))
//__kernel void oram(__global unsigned char* server)
void init_oram(__global unsigned char* server, __local short* posmap, __local unsigned char* stash)
{
	int i, j, k;

	//Initialize RNG
	unsigned short rand = 0xace1;


	//Initialize the server by writing dummy blocks everywhere
	//printf("Initializing server\n");
	//for each node in the tree
	for (i = 0; i < TREE_SIZE; i = i + 1){
		//for each block in the tree
		for(j = 0; j < Z; j++){
			//For each byte in the block
			for(k = 0; k < BLOCK_SIZE; k++){
				int idx = i * BLOCK_SIZE*Z + j*BLOCK_SIZE + k;
				//Set the address of the block to BOT to signal dummy
				if(k == 0 || k == 1){
					server[idx] = BOT;
				}
				else{
					server[idx] = 0;
				}
			}
		}
	}
	//Initialize the posmap
	//printf("Initializing posmap\n");
	__attribute__((xcl_pipeline_loop))
	for (i = 0; i < N; i++){
		posmap[i] = rand % LEAF_SIZE;
		//posmap[i] = 1;
		//rand = pseudo_rand(rand);
		rand = pseudo_rand(rand);
	}

//	//Initialize the stash
	//printf("Initializing stash\n");
	for (i = 0; i < (L+1)*Z + C; i++ ){
		//The stash should initially be empty
		int idx = i * BLOCK_SIZE;
		//TODO: SIZE
		stash[idx] = BOT;
		stash[idx + 1] = BOT;
	}
}
//
void access(int op, short a, __local unsigned char* data, __global unsigned char* server,
		__local short* posmap, __local unsigned char* stash, unsigned short* rng){
	//printf("=============================\n");
	//printf("Performing op %d on address %d\n", op, a);
	int x = posmap[a] + LEAF_MIN;
	//printf("Current leaf= %d (node %d)\n", posmap[a], posmap[a] + LEAF_MIN);
	//posmap[a] = rand() % LEAF_SIZE;
	posmap[a] = *rng % LEAF_SIZE;
	*rng = pseudo_rand(*rng);
	//printf("New leaf= %d (node %d)\n", posmap[a], posmap[a] + LEAF_MIN);

	int path[L+1] = {0};
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
		for(z_idx = 0; z_idx < Z; z_idx++){
			//printf("Reading block %d of bucket %d\n", z_idx, path[l]);
			for(s = 0; s < (L+1)*Z + C; s++){
				//Get the first open space in the stash
				if(stash[s*BLOCK_SIZE] == BOT && stash[s*BLOCK_SIZE+1] == BOT){
					break;
				}
			}
			int server_offset = path[l]*Z*BLOCK_SIZE + z_idx * BLOCK_SIZE;
			//TODO: SIZE
			//short block_addr = (server[server_offset] << 8) | server[server_offset+1];
			//printf("Server addr = %d\n", server_offset);
			//printf("Block addr = %d, block leaf = %d\n", block_addr, block_leaf);
			for(i = 0; i < BLOCK_SIZE; i++){
				stash[s*BLOCK_SIZE + i] = server[server_offset+i];
			}
			//TODO: SIZE
			//short short_bot = (BOT << 8) | BOT;
//			if(block_addr != short_bot){
//				printf("Read offset %d of bucket %d into stash position %d\n", z_idx, path[l], s);
//			}
		}
	}

	if (op == 1){
		//printf("Write command. Updating stash with data\n");
		//int open_idx = 0;
		for(s = 0; s < (L+1)*Z + C; s++){
			//TODO: SIZE
			short stash_addr = (stash[s*BLOCK_SIZE] << 8) | stash[s*BLOCK_SIZE + 1];
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
				if(stash[s*BLOCK_SIZE] == BOT && stash[s*BLOCK_SIZE + 1] == BOT){
					break;
				}
			}
		}
		//printf("Adding data for block %d to stash at position %d\n", a, s);
		//TODO: SIZE
		stash[s*BLOCK_SIZE] = (a >> 8) & 0xff;
		stash[s*BLOCK_SIZE+1] = a & 0xff;
		for(i = 0; i < B; i++){
			stash[s*BLOCK_SIZE+2+i] = data[i];
		}
	}
	else{
		//Set data to be block a from S
		for(s = 0; s < (L+1)*Z + C; s++){
			//TODO: SIZE
			short block_addr = (stash[s*BLOCK_SIZE] << 8) | stash[s*BLOCK_SIZE+1];
			if(block_addr == a){
				for(i = 0; i < B; i++){
					data[i] = stash[s*BLOCK_SIZE+2+i];
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
		//Scan through the stash
		for(s = 0; s < (L+1)*Z + C; s++){
			//If there are already Z blocks written out, don't write any more
			if(blocks_written == Z){
				break;
			}
			//Check if the address is valid
			//TODO: SIZE
			if(stash[s*BLOCK_SIZE] == BOT && stash[s*BLOCK_SIZE + 1] == BOT){
				continue;
			}
			short a_prime = (stash[s*BLOCK_SIZE] << 8) | stash[s*BLOCK_SIZE + 1];
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
				int server_offset = path[l]*Z*BLOCK_SIZE + blocks_written * BLOCK_SIZE;
				//TODO: SIZE
				server[server_offset] = (a_prime >> 8) & 0xff;
				server[server_offset + 1] = (a_prime & 0xff);
				for(i = 0; i < B; i++){
					server[server_offset + 2 + i] = stash[s*BLOCK_SIZE + 2 + i];
				}

				//Remove this block from the stash
				//printf("Clearing stash position %d\n", s);
				//TODO: SIZE
				stash[s*BLOCK_SIZE] = BOT;
				stash[s*BLOCK_SIZE+1] = BOT;
				blocks_written = blocks_written + 1;

				continue; //Go on to the next element in the stash
			}
		}

		if(blocks_written < Z){
			int dummies_to_write = Z-blocks_written;
			//printf("Only wrote %d real blocks. Filling bucket %d with %d dummies \n", blocks_written, path[l], dummies_to_write);
			for(i = 0; i < dummies_to_write; i++){
				int server_offset = path[l]*Z*BLOCK_SIZE + blocks_written*BLOCK_SIZE;
				//TODO:SIZE
				server[server_offset] = BOT;
				server[server_offset+1] = BOT;
				for(j = 0; j < B; j++){
					server[server_offset + 2 + j] = 0;
				}
				blocks_written++;
			}
		}
	}
}

__attribute__ ((reqd_work_group_size(1, 1, 1)))
__kernel void oram(__global unsigned char* server, int n_itr)
{
	int status = 0;

	//unsigned char server[TREE_SIZE*Z*BLOCK_SIZE];
	__local short posmap[N];
	__local unsigned char stash[((L+1)*Z + C) * BLOCK_SIZE];

	int i;
	int j;
	//printf("Hello world\r\n");
	//printf("n_itr: %d\n", n_itr);

	unsigned short rng = 0xa1bc;


	init_oram(server, posmap, stash);

	//Let's try writing to address 0
	__local unsigned char test_data[B];
	__local unsigned char read_data[B];
	
	//__attribute__((xcl_pipeline_loop))
	__attribute__((opencl_unroll_hint(1)))
	for(j = 0; j < n_itr; j++){
		for(i = 0; i < B; i++){
			test_data[i] = (i+j)%256;
			read_data[i] = 0;
		}
		access(1, j, test_data, server, posmap, stash, &rng);
		access(0, j, read_data, server, posmap, stash, &rng);

		//__attribute__((opencl_unroll_hint(1)))
		for(i = 0; i < B; i++){
			if(test_data[i] != read_data[i]){
				status = 1;
				break;
			}
		}
	}

//	for(i = 0; i < B; i++){
//		if(test_data[i] != read_data[i]){
//			status = 1;
//			break;
//		}
//		test_data[i] = read_data[i] + 1;
//	}
//	access(1, 0, test_data, server, posmap, stash, &rng);
//	access(0, 0, read_data, server, posmap, stash, &rng);


	if(status == 1){
		//printf("FAILURE\n");
		server[0] = 1;
	}
	else{
		//printf("SUCESS\n");
		server[0] = 0;
	}
	server[1] = 23;
	
}
