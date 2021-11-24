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
void initialize_data(uint32_t len, uint32_t addr, uint8_t start_count);
void setup_command(uint32_t cmd, uint32_t memory_addr, uint32_t storage_addr, uint32_t len);
void trigger_start();
void wait_for_done(uint32_t done_count);
static inline void print_write_data(uint8_t* buffer, size_t size, uint32_t base_addr);
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


  //uint32_t len = 20480;
  uint32_t len = 1048576;
  uint32_t burst_len = len / 8;
  uint8_t *read_buffer = malloc(128);

  
  setup_send_rdbuf_to_c(read_buffer, len);

  //Load the data
  printf("Initializing ddr\n");
  init_ddr();
  printf("Done ddr init\n");
  
  uint32_t memory_addr = 0x00000000;
  uint32_t storage_addr = 0x01000000;
  //initialize_data(len, memory_addr, 0); //64 bytes into memory addr
  
  uint32_t cmd_get = 0x00000000;
  uint32_t cmd_put = 0x00000001;
  setup_command(cmd_put, memory_addr, storage_addr, burst_len);


  //initialize_data();
  //initialize_weights();

  //Trigger start
  trigger_start();

  //Wait for done
  wait_for_done(1);
  
  // Print out write put data
  //print_write_data(read_buffer, len, storage_addr);

  // Test get command - copy data from 
  // initialize_data(256, 0x20000000, 9);
  // setup_command(cmd_get, 0x01000000, 0x20000010, 128/8);
  // trigger_start();
  // wait_for_done(2);
  // print_write_data(read_buffer, 128, 0x01000000);

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

void initialize_data(uint32_t len, uint32_t addr, uint8_t start_count){
  printf("Initializing put data\n");

  //size_t len = 64;
  uint8_t* write_buffer = malloc(4096);

  int i;

  printf("Writing read write\n");
  for(i = 0; i < 4096; i++){
    write_buffer[i] = i + start_count;
  }

  size_t offset = 0;
  while(offset < len){
    size_t bytes_to_write;
    size_t bytes_remaining = len - offset;

    printf("offset: %d\n ",offset);

    if( bytes_remaining >= 4096 ){
      bytes_to_write = 4096;
    }
    else{
      bytes_to_write = bytes_remaining % 4096;
    }
    sv_fpga_start_buffer_to_cl(0, 0, bytes_to_write, (uint64_t)write_buffer, (uint64_t)addr + offset);

    offset += bytes_to_write;
  }

  free(write_buffer);

}

void setup_command(uint32_t cmd, uint32_t memory_addr, uint32_t storage_addr, uint32_t len){
  uint32_t cmd_base_addr = 0x0504;
  uint32_t cmd_storage_base_addr = 0x0508;
  uint32_t cmd_memory_base_addr = 0x050c;
  uint32_t cmd_len_base_addr = 0x0510;
  
  pci_bar_handle_t pci_bar_handle = PCI_BAR_HANDLE_INIT;

  fpga_pci_poke(pci_bar_handle, cmd_base_addr, cmd);
  fpga_pci_poke(pci_bar_handle, cmd_storage_base_addr, storage_addr);
  fpga_pci_poke(pci_bar_handle, cmd_memory_base_addr, memory_addr);
  fpga_pci_poke(pci_bar_handle, cmd_len_base_addr, len);

}

void trigger_start(){
  uint32_t control_base_addr = 0x0500;

  uint32_t write_data = 0x00000001;
  pci_bar_handle_t pci_bar_handle = PCI_BAR_HANDLE_INIT;

  fpga_pci_poke(pci_bar_handle, control_base_addr, write_data);
  
  // turn off start
  write_data = 0x00000000;
  fpga_pci_poke(pci_bar_handle, control_base_addr, write_data);

}

void wait_for_done(uint32_t done_count){
  uint32_t done_base_addr = 0x0604;
  uint32_t read_data;
  pci_bar_handle_t pci_bar_handle = PCI_BAR_HANDLE_INIT;

  printf("Waiting for done\n");

  int i = 0;
  fpga_pci_peek(pci_bar_handle, done_base_addr, &read_data);
  while( read_data != done_count ){
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

static inline void print_write_data(uint8_t* buffer, size_t size, uint32_t base_addr){
  printf("Reading output\n");
  
  sv_fpga_start_cl_to_buffer(0, 0, size, (uint64_t)buffer, base_addr);

  for(int i = 0; i < size; i++){
    printf("%x", buffer[i]);
  }
  printf("\n");

  printf("DONE!:");

  return;
}
