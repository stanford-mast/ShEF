/*===============================================================*/
/*                                                               */
/*                       testing_data.h                          */
/*                                                               */
/*              Constant array for test instances.               */
/*                                                               */
/*===============================================================*/


#ifndef TESTING_DATA_H
#define TESTING_DATA_H

const unsigned int testing_data[16131] = {
  #include "../196data/test_set_enc.dat"
//#include "../196data/test_set_short_enc.dat"
};

const LabelType expected[2000] = {
  #include "../196data/expected.dat"
};

#endif
