
#ifndef IMAGE_DATA_H
#define IMAGE_DATA_H


const unsigned int image_data[70539] = {
//const DigitType training_data[NUM_TRAINING * DIGIT_WIDTH] = {
  //#include "../196data/training_set_short_enc.dat"
//#include "../196data/training_set_short.dat"
	#include "../data/hw_image_enc.dat"
};

const unsigned int weight_data[619243] = {
	#include "../data/hw_weight_enc.dat"
};

#endif
