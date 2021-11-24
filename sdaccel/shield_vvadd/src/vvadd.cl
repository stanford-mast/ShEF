/*********
 * Mark Zhao
 * 6/4/2019
 *
 *
 *
 */

//This kernel computes the vector addition over two input kernels
pipe int i0 __attribute__((xcl_reqd_pipe_depth(32)));
pipe int i1 __attribute__((xcl_reqd_pipe_depth(32)));
pipe int i2 __attribute__((xcl_reqd_pipe_depth(32)));
pipe int i3 __attribute__((xcl_reqd_pipe_depth(32)));
pipe int i4 __attribute__((xcl_reqd_pipe_depth(32)));
pipe int i5 __attribute__((xcl_reqd_pipe_depth(32)));
pipe int i6 __attribute__((xcl_reqd_pipe_depth(32)));
pipe int i7 __attribute__((xcl_reqd_pipe_depth(32)));
pipe int o0 __attribute__((xcl_reqd_pipe_depth(32)));
pipe int o1 __attribute__((xcl_reqd_pipe_depth(32)));
pipe int o2 __attribute__((xcl_reqd_pipe_depth(32)));
pipe int o3 __attribute__((xcl_reqd_pipe_depth(32)));

kernel __attribute__((reqd_work_group_size(1,1,1)))
//kernel __attribute__((xcl_dataflow))
void vvadd(int size){
	int input_a0;
	int input_b0;
	int input_a1;
	int input_b1;
	int input_a2;
	int input_b2;
	int input_a3;
	int input_b3;
	int output_c0;
	int output_c1;
	int output_c2;
	int output_c3;


	for (int i = 0; i < size; i++){
		read_pipe_block(i0, &input_a0);
		read_pipe_block(i1, &input_b0);
		read_pipe_block(i2, &input_a1);
		read_pipe_block(i3, &input_b1);
		read_pipe_block(i4, &input_a2);
		read_pipe_block(i5, &input_b2);
		read_pipe_block(i6, &input_a3);
		read_pipe_block(i7, &input_b3);

		if (i < 3){
			output_c0 = input_a0;
			output_c1 = input_a1;
			output_c2 = input_a2;
			output_c3 = input_a3;
		}
		else{
			output_c0 = input_a0 + input_b0;
			output_c1 = input_a1 + input_b1;
			output_c2 = input_a2 + input_b2;
			output_c3 = input_a3 + input_b3;
		}
		write_pipe_block(o0, &output_c0);
		write_pipe_block(o1, &output_c1);
		write_pipe_block(o2, &output_c2);
		write_pipe_block(o3, &output_c3);
	}
}
