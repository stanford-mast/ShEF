#ifndef TEST_DATA_H
#define TEST_DATA_H

const unsigned int input_server[9438136] = {
	#include "../stash/oram_input_init_enc.dat"
};

const unsigned int input_image_enc[1409127] = {
	#include "../stash/affine_4x_oram.dat"
};


#endif
