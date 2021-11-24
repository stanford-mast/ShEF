#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>

#include "ed25519.h"
#include "ge.h"
#include "sc.h"

/**
* Generate an ed25519 key pair
* @param public_key: 32 element unsigned char array to store pub key
* @param private_key: 64 element unsigned char array to store generated priv key
*/
void generate_keys(unsigned char* public_key, unsigned char* private_key){
	unsigned char seed[32];

	/* create a random seed and generate a key pair */
	ed25519_create_seed(seed);
	ed25519_create_keypair(public_key, private_key, seed);
	return;
}


int main(int argc, char *argv[]) {
	if (argc >= 3){
		/* The command should be in argv[1] */
		char* cmd = argv[1];

		if ((strcmp(cmd, "-c") == 0 ||
				strcmp(cmd, "-p") == 0 ) && argc == 3){
			/* Writes key pair to a file specified by param
			* file is simply a binary file consisting of
			* public_key followed by private_key
			* if -p, write only the public key.
			*/
			unsigned char public_key[32], private_key[64];
			unsigned char read_pk[32], read_sk[64];
			char* param = argv[2];

			generate_keys(public_key, private_key);
			int j;
			printf("Private key: 0x");
			for(j = 0; j < 64; j++){
				printf("%02x", private_key[j]);
			}
			printf("\r\n");
			printf("Creating keypair in file %s\n",param);
			FILE *key_file = fopen(param, "wb");
			fwrite(public_key, 1, 32, key_file);
			if(strcmp(cmd, "-c") == 0){
				fwrite(private_key, 1, 64, key_file);
			}
			if(fclose(key_file) != 0){
				printf("Error in closing file\n");
				return -1;
			}
			key_file = fopen(param, "rb");
			fread(read_pk, 1, 32, key_file);
			if(strcmp(cmd, "-c") == 0){
				fread(read_sk, 1, 64, key_file);
			}
			if(fclose(key_file) != 0){
				printf("Error in closing file\n");
				return -1;
			}

			if (memcmp(read_pk, public_key, 32) != 0 || 
					(strcmp(cmd, "-c") == 0 && 
					memcmp(read_sk, private_key, 64) != 0)){
				printf("ERROR: Keys Invalid!\n");
				return -1;
			}
		}
		else if (strcmp(cmd, "-x") == 0 && argc == 5){
			/*
			* Performs key exchange with a remote host.
			* Reads private key from argv[2]
			* The other public key from argv[3]
			* Writes the shared secret in argv[4]
			*/
			unsigned char my_public_key[32], my_private_key[64];
			unsigned char other_public_key[32];
			unsigned char shared_secret[32];
			
			char* my_key_file = argv[2];
			char* other_key_file = argv[3];
			char* shared_secret_key_file = argv[4];

			FILE* my_key_fp = fopen(my_key_file, "rb");
			FILE* other_key_fp = fopen(other_key_file, "rb");
			FILE* shared_secret_key_fp = fopen(shared_secret_key_file, "wb");

			if (my_key_fp == NULL || other_key_fp == NULL || 
					shared_secret_key_fp == NULL){
					printf("Unable to open key files\n");
					return -1;
			}

			//Read in my keys
			if(fread(my_public_key, 1, 32, my_key_fp) != 32){
				printf("Unable to read my pk\n");
				return -1;
			}
			if(fread(my_private_key, 1, 64, my_key_fp) != 64){
				printf("Unable to read my sk\n");
				return -1;
			}

			//read in the other public key
			if(fread(other_public_key, 1, 32, other_key_fp) != 32){
				printf("Unable to read in the other pk\n");
				return -1;
			}

			//Create a shared secret
			ed25519_key_exchange(shared_secret, other_public_key, my_private_key);

			//Write the shared secret to a binary file
			if(fwrite(shared_secret, 1, 32, shared_secret_key_fp) != 32){
				printf("Unable to write shared secret\n");
				return -1;
			}
			
			fclose(my_key_fp);
			fclose(other_key_fp);
			fclose(shared_secret_key_fp);
		}
		else if(strcmp(cmd, "-v") == 0 && argc == 6){
			/*
			 * Given a file containing an ed25519 public key, a file containing a 64 byte signature, and a file containing
			 * the message, return -1 on failure to verify or 0 on success.
			 */
			unsigned char fpga_public_key[32];
      unsigned char signature[64];
      unsigned char message[624];
      char* p;
      errno = 0;

			char* fpga_key_file = argv[2];
			char* signature_file = argv[3];
			char* message_file = argv[4];
      int message_len = strtol(argv[5], &p, 10);

      if(errno != 0 || *p != '\0'){
        printf("Unable to parse message length");
        return -1;
      }


			FILE* fpga_key_fp = fopen(fpga_key_file, "rb");
			FILE* signature_fp = fopen(signature_file, "rb");
			FILE* message_fp = fopen(message_file, "rb");
			
			if (fpga_key_fp == NULL || signature_fp == NULL || 
					message_fp == NULL){
					printf("Unable to open key files\n");
					return -1;
			}

			//Read in FPGA attestation key.
			if(fread(fpga_public_key, 1, 32, fpga_key_fp) != 32){
				printf("Unable to read FPGA attestation key\n");
				return -1;
			}
			if(fread(signature, 1, 64, signature_fp) != 64){
				printf("Unable to read signature\n");
				return -1;
			}
			if(fread(message, 1, message_len, message_fp) != (size_t)message_len){
				printf("Unable to read message\n");
				return -1;
			}

			//Verify the bitstream signature.
			int verify = ed25519_verify(signature, message, 
											message_len, fpga_public_key);

			//Close and return the result.
			fclose(fpga_key_fp);
			fclose(signature_fp);
			fclose(message_fp);

			if(verify == 1){
				return 0;
			}
			else{
				return -1;
			}
		}
		else{
			printf("Invalid command.\n");
			return -1;
		}
	}
	else{
		printf("Invalid command.\n");
		return -1;
	}

	return 0;

}