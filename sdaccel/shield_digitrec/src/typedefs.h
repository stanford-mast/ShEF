/*===============================================================*/
/*                                                               */
/*                          typedefs.h                           */
/*                                                               */
/*           Constant definitions and typedefs for host.         */
/*                                                               */
/*===============================================================*/

#ifndef __TYPEDEFS_H__
#define __TYPEDEFS_H__

// dataset information
const int NUM_TRAINING  = 18000;
const int CLASS_SIZE    = 1800;
const int NUM_TEST      = 2000;
//const int NUM_TRAINING = 40;
//const int NUM_TEST = 4;
const int DIGIT_WIDTH   = 4;

// typedefs
typedef unsigned long long DigitType;
typedef unsigned char      LabelType;


// parameters
#define K_CONST 3
#define PAR_FACTOR 40

#endif
