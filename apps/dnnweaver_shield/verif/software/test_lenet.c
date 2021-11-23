#include <stdio.h>
#include <fcntl.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <poll.h>
#include <malloc.h>


#include <utils/sh_dpi_tasks.h>
#ifdef SV_TEST
# include <fpga_pci_sv.h>
#else
# include <fpga_pci.h>
# include <fpga_mgmt.h>
# include "fpga_dma.h"
# include <utils/lcd.h>
#endif

void print_status();
void initialize_data();
void initialize_weights();
void trigger_start();
void wait_for_done();
static inline void print_write_data(uint8_t* buffer, size_t size);
void setup_send_rdbuf_to_c(uint8_t *read_buffer, size_t buffer_size);
int send_rdbuf_to_c(char* rd_buf);


static uint8_t *send_rdbuf_to_c_read_buffer = NULL;
static size_t send_rdbuf_to_c_buffer_size = 0;

void setup_send_rdbuf_to_c(uint8_t *read_buffer, size_t buffer_size)
{
    send_rdbuf_to_c_read_buffer = read_buffer;
    send_rdbuf_to_c_buffer_size = buffer_size;
}

int send_rdbuf_to_c(char* rd_buf)
{
#ifndef VIVADO_SIM
    /* Vivado does not support svGetScopeFromName */
    svScope scope;
    scope = svGetScopeFromName("tb");
    svSetScope(scope);
#endif
    int i;

    /* For Questa simulator the first 8 bytes are not transmitted correctly, so
     * the buffer is transferred with 8 extra bytes and those bytes are removed
     * here. Made this default for all the simulators. */
    for (i = 0; i < send_rdbuf_to_c_buffer_size; ++i) {
        send_rdbuf_to_c_read_buffer[i] = rd_buf[i+8];
    }

    /* end of line character is not transferered correctly. So assign that
     * here. */
    /*send_rdbuf_to_c_read_buffer[send_rdbuf_to_c_buffer_size - 1] = '\0';*/

    return 0;
}



void test_main(uint32_t *exit_code){
  int rc;
  int slot_id = 0;

  /* initialize the fpga_plat library */
  rc = fpga_mgmt_init();
  fail_on(rc, out, "Unable to initialize the fpga_mgmt library");

  print_status();


  size_t read_len = 160+16;
  uint8_t *read_buffer = malloc(read_len);

  
  setup_send_rdbuf_to_c(read_buffer, read_len);

  //Load the data
  printf("Initializing ddr\n");
  init_ddr();
  printf("Done ddr init\n");

  //initialize_data();
  //initialize_weights();

  //Trigger start
  trigger_start();

  //Wait for done
  wait_for_done();

  print_write_data(read_buffer, read_len);

  free(read_buffer);



out:
  *exit_code = 0;
}


void print_status(){
  uint32_t status_base_addr = 0x0600;
  uint32_t read_data;
  pci_bar_handle_t pci_bar_handle = PCI_BAR_HANDLE_INIT;


  for(int i = 0; i < 16; i++){
   fpga_pci_peek(pci_bar_handle, status_base_addr + (i*4), &read_data);
   printf("R%d: 0x%x; ", i, read_data);
  }
  printf("\n");
  return;
}

void initialize_data(){
  printf("Initializing read data\n");

  uint64_t base_addr = 16777216;
  size_t len = 593472;//593632+32; //don't include last layer write addr
  //size_t len = 64;
  uint8_t* write_buffer = malloc(4096);

  int i;

  //Layer 1
  printf("Writing read write\n");
  for(i = 0; i < 4096; i++){
    write_buffer[i] = 0;
  }

  int num_dma = len / 4096;
  size_t offset = 0;
  while(offset < len){
    size_t bytes_to_write;
    size_t bytes_remaining = len - offset;

    printf("offset: %d\n ",offset);

    if( bytes_remaining > 4096 ){
      bytes_to_write = 4096;
    }
    else{
      bytes_to_write = bytes_remaining % 4096;
    }
    sv_fpga_start_buffer_to_cl(0, 0, bytes_to_write, (uint64_t)write_buffer, base_addr + offset);

    offset += bytes_to_write;
  }

  //sv_fpga_start_buffer_to_cl(0, 0, len, (uint64_t)write_buffer, base_addr);

  free(write_buffer);

}

void initialize_weights(){
  printf("initializeing weights\n");

  uint64_t base_addr = 0;
  size_t len = 888720; //total size of weights
  uint8_t* write_buffer = malloc(4096);

  int i;

  printf("Writing weights\n");
  for(i = 0; i < 4096; i++){
    write_buffer[i] = 0;
  }

  int num_dma = len / 4096;
  size_t offset = 0;
  while(offset < len){
    size_t bytes_to_write;
    size_t bytes_remaining = len - offset;

    printf("offset: %d\n ",offset);

    if( bytes_remaining > 4096 ){
      bytes_to_write = 4096;
    }
    else{
      bytes_to_write = bytes_remaining % 4096;
    }
    sv_fpga_start_buffer_to_cl(0, 0, bytes_to_write, (uint64_t)write_buffer, base_addr + offset);

    offset += bytes_to_write;
  }

  //sv_fpga_start_buffer_to_cl(0, 0, len, (uint64_t)write_buffer, base_addr);
  
  free(write_buffer);

}


void trigger_start(){
  uint32_t control_base_addr = 0x0500;

  uint32_t write_data = 0x00000001;
  pci_bar_handle_t pci_bar_handle = PCI_BAR_HANDLE_INIT;

  fpga_pci_poke(pci_bar_handle, control_base_addr, write_data);

}

void wait_for_done(){
  uint32_t done_base_addr = 0x0604;
  uint32_t read_data;
  pci_bar_handle_t pci_bar_handle = PCI_BAR_HANDLE_INIT;

  printf("Waiting for done\n");

  int i = 0;
  fpga_pci_peek(pci_bar_handle, done_base_addr, &read_data);
  while( read_data == 0 ){
    if(i % 100 == 0){
      print_status();
    }
    fpga_pci_peek(pci_bar_handle, done_base_addr, &read_data);
    i++;
  }
  print_status();
  printf("DONE!");
  return;

}

static inline void print_write_data(uint8_t* buffer, size_t size){
  printf("Reading output\n");
  uint32_t base_addr = 17370688;
  
  sv_fpga_start_cl_to_buffer(0, 0, size, (uint64_t)buffer, base_addr);

  printf("0x");
  for(int i = 0; i < size; i++){
    printf("%d: %x \n", i, buffer[i]);
  }

  printf("DONE!:");

  return;
}
