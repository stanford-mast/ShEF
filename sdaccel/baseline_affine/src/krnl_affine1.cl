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



__kernel __attribute__ ((reqd_work_group_size(1, 1, 1)))
void affine_kernel1(__global unsigned int *image1,
                   __global unsigned int *image2
                  )
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

   float    affine[2][2];
   float    i_affine[2][2];
   float    beta[2];
   float    i_beta[2];
   float    det;
   float    x_new, y_new;
   float    x_frac, y_frac;
   //float    gray_new;
   int      x, y, m, n;

   __local unsigned int    output_buffer[X_SIZE];


   // forward affine transformation
   affine[0][0] = lx_expan * cos((float)(lx_rot*PI/180.0f));
   affine[0][1] = ly_expan * sin((float)(ly_rot*PI/180.0f));
   affine[1][0] = lx_expan * sin((float)(lx_rot*PI/180.0f));
   affine[1][1] = ly_expan * cos((float)(ly_rot*PI/180.0f));
   beta[0]      = lx_move;
   beta[1]      = ly_move;
  
   // determination of inverse affine transformation
   det = (affine[0][0] * affine[1][1]) - (affine[0][1] * affine[1][0]);
   if (det == 0.0f)
   {
      i_affine[0][0]   = 1.0f;
      i_affine[0][1]   = 0.0f;
      i_affine[1][0]   = 0.0f;
      i_affine[1][1]   = 1.0f;
      i_beta[0]        = -beta[0];
      i_beta[1]        = -beta[1];
   } 
   else 
   {
      i_affine[0][0]   =  affine[1][1]/det;
      i_affine[0][1]   = -affine[0][1]/det;
      i_affine[1][0]   = -affine[1][0]/det;
      i_affine[1][1]   =  affine[0][0]/det;
      i_beta[0]        = -i_affine[0][0]*beta[0]-i_affine[0][1]*beta[1];
      i_beta[1]        = -i_affine[1][0]*beta[0]-i_affine[1][1]*beta[1];
   }
  
   // Output image generation by inverse affine transformation and bilinear transformation
   for (y = 0; y < Y_SIZE; y++)
   {


		__attribute__((xcl_pipeline_loop))
      for (x = 0; x < X_SIZE; x++)
      {
         x_new    = i_beta[0] + i_affine[0][0]*(x-X_SIZE/2.0f) + i_affine[0][1]*(y-Y_SIZE/2.0f) + X_SIZE/2.0f;
         y_new    = i_beta[1] + i_affine[1][0]*(x-X_SIZE/2.0f) + i_affine[1][1]*(y-Y_SIZE/2.0f) + Y_SIZE/2.0f;

         m        = (int)floor(x_new);
         n        = (int)floor(y_new);

         x_frac   = x_new - m;
         y_frac   = y_new - n;
      
         if ((m >= 0) && (m + 1 < X_SIZE) && (n >= 0) && (n+1 < Y_SIZE))
         {

				 	float r_new;
					float g_new;
					float b_new;
					float a_new;

					unsigned int pixel_tl = image1[(n * X_SIZE) + m];
					unsigned int pixel_tr = image1[(n * X_SIZE) + m + 1];
					unsigned int pixel_bl = image1[((n + 1) * X_SIZE) + m];
					unsigned int pixel_br = image1[((n + 1) * X_SIZE) + m + 1];

					unsigned char pixel_tl_r = (pixel_tl >> 24) & 0xff;
					unsigned char pixel_tl_g = (pixel_tl >> 16) & 0xff;
					unsigned char pixel_tl_b = (pixel_tl >> 8) & 0xff;
					unsigned char pixel_tl_a = (pixel_tl & 0xff);

					unsigned char pixel_tr_r = (pixel_tr >> 24) & 0xff;
					unsigned char pixel_tr_g = (pixel_tr >> 16) & 0xff;
					unsigned char pixel_tr_b = (pixel_tr >> 8) & 0xff;
					unsigned char pixel_tr_a = (pixel_tr & 0xff);

					unsigned char pixel_bl_r = (pixel_bl >> 24) & 0xff;
					unsigned char pixel_bl_g = (pixel_bl >> 16) & 0xff;
					unsigned char pixel_bl_b = (pixel_bl >> 8) & 0xff;
					unsigned char pixel_bl_a = (pixel_bl & 0xff);

					unsigned char pixel_br_r = (pixel_br >> 24) & 0xff;
					unsigned char pixel_br_g = (pixel_br >> 16) & 0xff;
					unsigned char pixel_br_b = (pixel_br >> 8) & 0xff;
					unsigned char pixel_br_a = (pixel_br & 0xff);

					r_new = (1.0f - y_frac) * ((1.0f - x_frac) * pixel_tl_r + x_frac * pixel_tr_r) +
									y_frac * ((1.0f - x_frac) * pixel_bl_r + x_frac * pixel_br_r);
					g_new = (1.0f - y_frac) * ((1.0f - x_frac) * pixel_tl_g + x_frac * pixel_tr_g) +
									y_frac * ((1.0f - x_frac) * pixel_bl_g + x_frac * pixel_br_g);
					b_new = (1.0f - y_frac) * ((1.0f - x_frac) * pixel_tl_b + x_frac * pixel_tr_b) +
									y_frac * ((1.0f - x_frac) * pixel_bl_b + x_frac * pixel_br_b);
					a_new = (1.0f - y_frac) * ((1.0f - x_frac) * pixel_tl_a + x_frac * pixel_tr_a) +
									y_frac * ((1.0f - x_frac) * pixel_bl_a + x_frac * pixel_br_a);

					float r_sepia = (r_new * 0.393f) + (g_new * 0.769f) + (b_new * 0.189f);
					float g_sepia = (r_new * 0.349f) + (g_new * 0.686f) + (b_new * 0.168f);
					float b_sepia = (r_new * 0.272f) + (g_new * 0.534f) + (b_new * 0.131f);


					unsigned char pixel_r_new = (unsigned char) r_sepia;
					unsigned char pixel_g_new = (unsigned char) g_sepia;
					unsigned char pixel_b_new = (unsigned char) b_sepia;
					unsigned char pixel_a_new = (unsigned char) a_new;

					output_buffer[x] = (pixel_r_new << 24) | (pixel_g_new << 16) |
						(pixel_b_new << 8) | (pixel_a_new);
					//output_buffer[x] = ((y & 0xffff) << 16) | (x & 0xffff);

         } 
         else if (((m + 1 == X_SIZE) && (n >= 0) && (n < Y_SIZE)) || ((n + 1 == Y_SIZE) && (m >= 0) && (m < X_SIZE)))
         {
            output_buffer[x] = image1[(n * X_SIZE) + m];
         } 
         else 
         {
            output_buffer[x] = WHITE;
         }
      }

		//Copy the result out
	__attribute__((xcl_pipeline_loop))
	 for(int i = 0; i< X_SIZE; i++){
		 image2[y*X_SIZE + i] = output_buffer[i];
	 }

      //event_t copy_complete = async_work_group_copy(&image2[(y * X_SIZE)]), (&output_buffer), X_SIZE, copy_complete);

      //wait_group_events(1, &copy_complete);
   }
}
