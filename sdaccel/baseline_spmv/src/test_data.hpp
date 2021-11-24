#ifndef TEST_DATA_H
#define TEST_DATA_H

//#define NNZ 1666
//#define N 494
#define NNZ 8388673
#define N 4096

const unsigned int input_vals[NNZ] = {
	#include "../data/vals_4096.dat"
};
const int input_cols[NNZ] = {
	#include "../data/cols_4096.dat"
};
const int input_row_delimiters[N + 1] = {
	#include "../data/row_delimiters_4096.dat"
};
//const float input_vec[N] = {
//	#include "../data/vec.dat"
//};


#endif
